import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/converters.dart';
import 'package:app/infra/database/token_transformer.dart';
import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:logging/logging.dart';

/// A single, always-on background isolate for token-write operations.
///
/// Keeps deserialization, model transformation, and SQL companion building
/// entirely off the UI isolate. Connects to the same [DriftIsolate] server
/// that backs the production [AppDatabase], so writes from this queue
/// correctly trigger stream-update notifications on the main connection.
///
/// Writes are processed **sequentially** — the next command is not started
/// until the previous one completes. This eliminates concurrent write
/// lock contention without requiring an additional SQLite connection.
///
/// Usage:
/// ```dart
/// final queue = await DatabaseWriteQueue.spawn(
///   driftConnectPort: AppDatabase.driftConnectPort!,
/// );
/// await queue.ingestTokensForAddressFromRaw(address: '0x…', rawTokensJson: [...]);
/// await queue.dispose();
/// ```
class DatabaseWriteQueue {
  DatabaseWriteQueue._(this._sendPort);

  final SendPort _sendPort;

  /// Spawns the write-queue isolate and returns a [DatabaseWriteQueue] ready
  /// to accept commands.
  ///
  /// [driftConnectPort] must be the [DriftIsolate.connectPort] of the already-
  /// running Drift server (obtained from [AppDatabase.driftConnectPort]).
  static Future<DatabaseWriteQueue> spawn({
    required SendPort driftConnectPort,
  }) async {
    final readyPort = ReceivePort();
    await Isolate.spawn(
      _entry,
      <Object?>[readyPort.sendPort, driftConnectPort],
      debugName: 'DatabaseWriteQueue',
    );
    final writeSendPort = await readyPort.first as SendPort;
    readyPort.close();
    return DatabaseWriteQueue._(writeSendPort);
  }

  // ── Public write commands ─────────────────────────────────────────────────

  /// Ingests raw token JSON for a blockchain address.
  ///
  /// [rawTokensJson] is the serialised payload forwarded directly from the
  /// worker isolate — no deserialization happens on the calling isolate.
  /// Filtering by owner, domain transformation, companion building, and
  /// the SQL write all happen in the write-queue isolate.
  Future<void> ingestTokensForAddressFromRaw({
    required String address,
    required List<Object?> rawTokensJson,
  }) {
    return _submit({
      'op': 'ingestTokensForAddress',
      'address': address,
      'tokens': rawTokensJson,
    });
  }

  /// Writes a batch of enrichment results to the database.
  ///
  /// [rawEnrichments] is the serialised payload from the worker isolate; each
  /// element is a map with 'itemId' and 'tokenJson' keys.
  Future<void> enrichBatchFromRaw({
    required List<Object?> rawEnrichments,
  }) {
    return _submit({
      'op': 'enrichBatch',
      'enrichments': rawEnrichments,
    });
  }

  /// Marks [itemIds] as enrichment-failed so the query worker skips them.
  Future<void> markEnrichmentFailed({required List<String> itemIds}) {
    if (itemIds.isEmpty) return Future.value();
    return _submit({'op': 'markEnrichmentFailed', 'itemIds': itemIds});
  }

  /// Shuts down the background isolate.
  Future<void> dispose() => _submit({'op': 'shutdown'});

  Future<void> _submit(Map<String, Object?> command) async {
    final replyPort = ReceivePort();
    _sendPort.send(<Object?>[command, replyPort.sendPort]);
    final result = await replyPort.first;
    replyPort.close();
    if (result is String) {
      throw StateError('DatabaseWriteQueue error: $result');
    }
    // null == success
  }

  // ── Background isolate ────────────────────────────────────────────────────

  static final Logger _log = Logger('DatabaseWriteQueue[Isolate]');

  // Enrichment status constants (mirrored from DatabaseService).
  static const int _enrichedStatus = 1;
  static const int _failedStatus = 2;

  static Future<void> _entry(List<Object?> args) async {
    final readySendPort = args[0]! as SendPort;
    final driftConnectPort = args[1]! as SendPort;

    late AppDatabase db;
    try {
      final connection =
          await DriftIsolate.fromConnectPort(driftConnectPort).connect();
      db = AppDatabase.fromConnection(connection);
    } on Object catch (e, st) {
      _log.severe('Failed to connect to Drift server', e, st);
      // Signal failure by never sending the ready port — caller will hang
      // then time out. Log is sufficient; no recovery possible here.
      return;
    }

    final receivePort = ReceivePort();
    readySendPort.send(receivePort.sendPort);

    // Sequential processing: await each command before accepting the next.
    await for (final rawMsg in receivePort) {
      if (rawMsg is! List || rawMsg.length < 2) continue;
      final command = Map<String, Object?>.from(rawMsg[0] as Map);
      final replyPort = rawMsg[1] as SendPort;

      final op = command['op'] as String?;
      if (op == 'shutdown') {
        replyPort.send(null);
        break;
      }

      try {
        await _dispatch(op, command, db);
        replyPort.send(null);
      } on Object catch (e, st) {
        _log.warning('Write op "$op" failed', e, st);
        replyPort.send(e.toString());
      }
    }

    await db.close();
  }

  static Future<void> _dispatch(
    String? op,
    Map<String, Object?> cmd,
    AppDatabase db,
  ) async {
    switch (op) {
      case 'ingestTokensForAddress':
        await _ingestTokensForAddress(cmd, db);
      case 'enrichBatch':
        await _enrichBatch(cmd, db);
      case 'markEnrichmentFailed':
        await _markEnrichmentFailed(cmd, db);
      default:
        throw ArgumentError('Unknown write op: $op');
    }
  }

  // ── Write implementations ─────────────────────────────────────────────────

  static Future<void> _ingestTokensForAddress(
    Map<String, Object?> cmd,
    AppDatabase db,
  ) async {
    final address = cmd['address']! as String;
    final rawTokens = cmd['tokens'] as List? ?? const [];
    final normalizedAddress = address.toUpperCase();

    final tokens =
        rawTokens
            .cast<Map<Object?, Object?>>()
            .map((e) => AssetToken.fromRest(Map<String, dynamic>.from(e)))
            .toList(growable: false);

    // Find the address-based playlist.
    final playlists = await db.getAddressPlaylists();
    String? addressPlaylistId;
    for (final row in playlists) {
      if (row.ownerAddress?.toUpperCase() == normalizedAddress) {
        addressPlaylistId = row.id;
        break;
      }
    }
    if (addressPlaylistId == null) {
      _log.info(
        'Address playlist not found for $address; skipping batch.',
      );
      return;
    }

    final ownedTokens = TokenTransformer.filterTokensByOwner(
      tokens: tokens,
      ownerAddress: normalizedAddress,
    );
    if (ownedTokens.isEmpty) return;

    final items =
        ownedTokens
            .map(
              (t) => TokenTransformer.assetTokenToPlaylistItem(
                token: t,
                ownerAddress: normalizedAddress,
              ),
            )
            .toList(growable: false);

    final entries =
        items
            .map(
              (item) => DatabaseConverters.createPlaylistEntry(
                playlistId: addressPlaylistId!,
                itemId: item.id,
                sortKeyUs: item.sortKeyUs ?? 0,
              ),
            )
            .toList(growable: false);

    final itemCompanions =
        items
            .map(DatabaseConverters.playlistItemToCompanion)
            .toList(growable: false);

    await db.transaction(() async {
      await db.upsertItems(itemCompanions);
      await db.upsertPlaylistEntries(entries);
      await db.updatePlaylistItemCount(addressPlaylistId!);
    });
    await db.checkpoint();

    _log.info('Ingested ${items.length} tokens for address $address');
  }

  static Future<void> _enrichBatch(
    Map<String, Object?> cmd,
    AppDatabase db,
  ) async {
    final rawEnrichments = cmd['enrichments'] as List? ?? const [];
    if (rawEnrichments.isEmpty) return;

    final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
    final companions =
        rawEnrichments
            .cast<Map<Object?, Object?>>()
            .map((raw) {
              final e = Map<String, dynamic>.from(raw);
              final itemId = e['itemId'] as String;
              final tokenJson =
                  Map<String, dynamic>.from(e['tokenJson'] as Map);
              final token = AssetToken.fromRest(tokenJson);
              final enriched =
                  TokenTransformer.assetTokenToPlaylistItem(token: token);

              return ItemsCompanion(
                id: Value(itemId),
                kind: const Value(1), // indexer token
                title: Value(enriched.title),
                subtitle: Value(enriched.subtitle),
                thumbnailUri: Value(enriched.thumbnailUrl),
                listArtistJson:
                    enriched.artists != null && enriched.artists!.isNotEmpty
                        ? Value(
                            jsonEncode(
                              enriched.artists!.map((a) => a.toJson()).toList(),
                            ),
                          )
                        : const Value(null),
                tokenDataJson: Value(jsonEncode(token.toRestJson())),
                enrichmentStatus: const Value(_enrichedStatus),
                updatedAtUs: Value(nowUs),
              );
            })
            .toList(growable: false);

    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.items, companions);
    });

    _log.fine('Enriched ${companions.length} items');
  }

  static Future<void> _markEnrichmentFailed(
    Map<String, Object?> cmd,
    AppDatabase db,
  ) async {
    final itemIds =
        (cmd['itemIds'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(growable: false);
    if (itemIds.isEmpty) return;

    final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
    await db.transaction(() async {
      for (final itemId in itemIds) {
        await (db.update(db.items)..where((t) => t.id.equals(itemId))).write(
          ItemsCompanion(
            enrichmentStatus: const Value(_failedStatus),
            updatedAtUs: Value(nowUs),
          ),
        );
      }
    });

    _log.info('Marked ${itemIds.length} items as enrichment-failed');
  }
}
