// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars, cascade_invocations, avoid_redundant_argument_values, unawaited_futures, omit_local_variable_types // Reason: orchestration glue; keep compact + stable.

import 'dart:async';

import 'package:app/app/providers/app_lifecycle_provider.dart';
import 'package:app/app/providers/background_workers_provider.dart';
import 'package:app/app/providers/indexer_provider.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/indexer/isolate/indexer_tokens_worker.dart';
import 'package:app/infra/indexer/isolate/worker_messages.dart';
import 'package:app/infra/indexer/isolate/worker_tasks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// State for the tokens sync coordinator.
class TokensSyncState {
  const TokensSyncState({
    this.syncingAddresses = const <String>{},
    this.lastSyncCompleted,
    this.errorMessage,
  });

  final Set<String> syncingAddresses;
  final DateTime? lastSyncCompleted;
  final String? errorMessage;

  TokensSyncState copyWith({
    Set<String>? syncingAddresses,
    DateTime? lastSyncCompleted,
    String? errorMessage,
  }) {
    return TokensSyncState(
      syncingAddresses: syncingAddresses ?? this.syncingAddresses,
      lastSyncCompleted: lastSyncCompleted ?? this.lastSyncCompleted,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider for the isolate-backed indexer tokens worker.
///
/// This is kept alive by [tokensSyncCoordinatorProvider] to ensure the isolate
/// persists across screens.
final indexerTokensWorkerProvider = Provider<IndexerTokensWorker>((ref) {
  final worker = IndexerTokensWorker(
    endpoint: AppConfig.indexerApiUrl,
    apiKey: AppConfig.indexerApiKey,
    logger: Logger('IndexerTokensWorker'),
  );

  // Fire-and-forget start; coordinator will await readiness when needed.
  unawaited(worker.start());

  ref.onDispose(() {
    unawaited(worker.stop());
  });

  return worker;
});

/// Coordinates isolate worker + indexer service + DB + persistence.
///
/// Mirrors the old repo semantics:
/// - Isolate streams change pages for UPDATE_TOKENS_IN_ISOLATE
/// - Main isolate extracts tokenIds/tokenCids, fetches tokens, ingests, deletes missing
/// - Anchor persisted per address after each page
class TokensSyncCoordinatorNotifier extends Notifier<TokensSyncState> {
  late final Logger _log;
  late final IndexerTokensWorker _worker;
  late final AppStateService _appStateService;

  StreamSubscription<TokensWorkerMessage>? _sub;
  Timer? _pollTimer;

  // Track per-sync request state so callers can await completion (old repo style).
  final Map<String, Completer<void>> _syncCompleters = {};
  final Map<String, List<String>> _syncAddressesByUuid = {};
  final Map<String, Future<void>> _inFlightByUuid = {};

  @override
  TokensSyncState build() {
    _log = Logger('TokensSyncCoordinator');
    _worker = ref.read(indexerTokensWorkerProvider);
    _appStateService = ref.read(appStateServiceProvider);

    _sub = _worker.messages.listen(_handleWorkerMessage);

    // Pause/resume polling when the app goes background/foreground.
    ref.listen<AppLifecycleState>(appLifecycleProvider, (_, next) {
      if (next == AppLifecycleState.paused ||
          next == AppLifecycleState.inactive ||
          next == AppLifecycleState.detached) {
        pausePolling();
      } else if (next == AppLifecycleState.resumed) {
        resumePolling();
      }
    });

    ref.onDispose(() {
      unawaited(_sub?.cancel());
      _pollTimer?.cancel();
    });

    return const TokensSyncState();
  }

  /// Start polling all address playlists periodically.
  ///
  /// Note: Caller decides the interval; this matches old repo style timers.
  void startPolling({Duration interval = const Duration(minutes: 5)}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) {
      unawaited(pollAllAddressesOnce());
    });
    _log.info('Started polling at interval=$interval');
  }

  void pausePolling() {
    if (_pollTimer == null) return;
    _pollTimer?.cancel();
    _pollTimer = null;
    _log.info('Paused polling');
  }

  void resumePolling() {
    if (_pollTimer != null) return;
    startPolling();
    _log.info('Resumed polling');
  }

  /// Poll all known addresses once (no timer).
  Future<void> pollAllAddressesOnce() async {
    final database = ref.read(databaseServiceProvider);
    final playlists = await database.getAddressPlaylists();
    final addresses = playlists
        .map((p) => p.ownerAddress)
        .whereType<String>()
        .toList();
    if (addresses.isEmpty) return;
    await syncAddresses(addresses);
  }

  /// Sync a list of addresses.
  Future<void> syncAddresses(List<String> addresses) async {
    if (addresses.isEmpty) return;

    // Ensure isolate is ready.
    await _worker.ready;

    // Resolve persisted anchors (default to 0 if missing).
    final anchors = <AddressAnchor>[];
    for (final address in addresses) {
      final anchor = await _appStateService.getAddressAnchor(address) ?? 0;
      anchors.add(AddressAnchor(address: address, anchor: anchor));
    }

    state = state.copyWith(
      syncingAddresses: {...state.syncingAddresses, ...addresses},
      errorMessage: null,
    );

    final uuid = DateTime.now().microsecondsSinceEpoch.toString();
    _syncAddressesByUuid[uuid] = [...addresses];
    final completer = Completer<void>();
    _syncCompleters[uuid] = completer;
    _worker.updateTokensInIsolate(uuid: uuid, addressAnchors: anchors);

    // Await completion signal from isolate (success/failure).
    await completer.future;
  }

  /// Trigger indexing for a list of addresses.
  Future<void> reindexAddresses(List<String> addresses) async {
    if (addresses.isEmpty) return;
    await _worker.ready;
    final uuid = DateTime.now().microsecondsSinceEpoch.toString();
    _worker.reindexAddressesList(uuid: uuid, addresses: addresses);
  }

  /// Notify isolate when a new channel was ingested.
  Future<void> notifyChannelIngested() async {
    await _worker.ready;
    final uuid = DateTime.now().microsecondsSinceEpoch.toString();
    _worker.notifyChannelIngested(uuid: uuid);
  }

  void _handleWorkerMessage(TokensWorkerMessage message) {
    if (message is UpdateTokensData) {
      // Serialize per-uuid work so UpdateTokensSuccess can await completion.
      final prev = _inFlightByUuid[message.uuid] ?? Future<void>.value();
      _inFlightByUuid[message.uuid] = prev.then(
        (_) => _handleUpdateTokensData(message),
      );
      return;
    }

    if (message is UpdateTokensSuccess) {
      unawaited(_handleUpdateTokensSuccess(message));
      return;
    }

    if (message is UpdateTokensFailure) {
      unawaited(_handleUpdateTokensFailure(message));
      return;
    }

    if (message is ReindexAddressesListDone) {
      unawaited(_handleReindexAddressesDone(message));
      return;
    }

    if (message is ReindexAddressesFailure) {
      state = state.copyWith(errorMessage: message.exception.toString());
      return;
    }

    if (message is ChannelIngestedAck) {
      // Route through scheduler so enrichment runs in the worker fleet,
      // not on the main isolate.
      unawaited(ref.read(workerSchedulerProvider).onFeedIngested());
      return;
    }
  }

  Future<void> _handleUpdateTokensSuccess(UpdateTokensSuccess msg) async {
    // Ensure all pending UpdateTokensData work is finished for this uuid.
    await (_inFlightByUuid[msg.uuid] ?? Future<void>.value());
    _inFlightByUuid.remove(msg.uuid);

    final addresses = _syncAddressesByUuid.remove(msg.uuid) ?? const <String>[];
    final remaining = {...state.syncingAddresses}..removeAll(addresses);
    state = state.copyWith(
      syncingAddresses: remaining,
      lastSyncCompleted: DateTime.now(),
    );

    final completer = _syncCompleters.remove(msg.uuid);
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _handleUpdateTokensFailure(UpdateTokensFailure msg) async {
    await (_inFlightByUuid[msg.uuid] ?? Future<void>.value());
    _inFlightByUuid.remove(msg.uuid);

    state = state.copyWith(errorMessage: msg.exception.toString());

    final addresses = _syncAddressesByUuid.remove(msg.uuid) ?? msg.addresses;
    final remaining = {...state.syncingAddresses}..removeAll(addresses);
    state = state.copyWith(syncingAddresses: remaining);

    final completer = _syncCompleters.remove(msg.uuid);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(msg.exception);
    }
  }

  Future<void> _handleReindexAddressesDone(ReindexAddressesListDone msg) async {
    for (final result in msg.results) {
      if (result.address.isEmpty) continue;
      await _appStateService.setAddressIndexingStatus(
        address: result.address,
        status: AddressIndexingProcessStatus(
          state: AddressIndexingProcessState.waitingForIndexStatus,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  Future<void> _handleUpdateTokensData(UpdateTokensData msg) async {
    final indexer = ref.read(indexerServiceProvider);
    final database = ref.read(databaseServiceProvider);

    // Extract tokenIds + tokenCids from changes.
    final tokenIds = <int>{};
    final tokenCids = <String>{};
    for (final change in msg.changesList.items) {
      final tokenId = change.tokenId;
      final tokenCid = change.tokenCid;
      if (tokenId != null) tokenIds.add(tokenId);
      if (tokenCid != null && tokenCid.isNotEmpty) tokenCids.add(tokenCid);
    }

    // Old semantics: fetch by tokenIds + owners, then delete missing CIDs.
    final List<AssetToken> tokens = tokenIds.isEmpty
        ? const <AssetToken>[]
        : await indexer.fetchTokensByTokenIds(
            tokenIds: tokenIds.toList(),
            owners: msg.addresses,
          );

    final returnedCids = tokens.map((t) => t.cid).toSet();
    final missingCids = tokenCids
        .where((cid) => !returnedCids.contains(cid))
        .toList();

    for (final address in msg.addresses) {
      if (tokens.isNotEmpty) {
        await database.ingestTokensForAddress(
          address: address,
          tokens: tokens,
        );
      }

      if (missingCids.isNotEmpty) {
        await database.deleteTokensByCids(address: address, cids: missingCids);
      }

      // Persist anchor after each page (old semantics).
      final nextAnchor = msg.changesList.nextAnchor;
      if (nextAnchor != null) {
        await _appStateService.setAddressAnchor(
          address: address,
          anchor: nextAnchor,
        );
      }
    }
  }
}

final tokensSyncCoordinatorProvider =
    NotifierProvider<TokensSyncCoordinatorNotifier, TokensSyncState>(
      TokensSyncCoordinatorNotifier.new,
    );
