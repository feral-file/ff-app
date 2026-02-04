import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/channel.dart';
import '../../domain/models/dp1/dp1_manifest.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/playlist_item.dart';
import 'app_database.dart';

/// Converts between domain models and database models.
class DatabaseConverters {
  /// Convert ChannelData to Channel domain model.
  static Channel channelDataToDomain(ChannelData data) {
    return Channel(
      id: data.id,
      name: data.title,
      type: ChannelType.values[data.type],
      description: data.summary,
      isPinned: false, // TODO: Add isPinned field to database
      baseUrl: data.baseUrl,
      slug: data.slug,
      curator: data.curator,
      coverImageUrl: data.coverImageUri,
      createdAt: DateTime.fromMicrosecondsSinceEpoch(data.createdAtUs.toInt()),
      updatedAt: DateTime.fromMicrosecondsSinceEpoch(data.updatedAtUs.toInt()),
      sortOrder: data.sortOrder,
    );
  }

  /// Convert Channel domain model to ChannelsCompanion.
  static ChannelsCompanion channelToCompanion(Channel channel) {
    final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
    return ChannelsCompanion.insert(
      id: channel.id,
      type: channel.type.index,
      title: channel.name,
      createdAtUs: BigInt.from(
        channel.createdAt?.microsecondsSinceEpoch ?? nowUs.toInt(),
      ),
      updatedAtUs: BigInt.from(
        channel.updatedAt?.microsecondsSinceEpoch ?? nowUs.toInt(),
      ),
      baseUrl: Value(channel.baseUrl),
      slug: Value(channel.slug),
      curator: Value(channel.curator),
      summary: Value(channel.description),
      coverImageUri: Value(channel.coverImageUrl),
      sortOrder: Value(channel.sortOrder),
    );
  }

  /// Convert PlaylistData to Playlist domain model.
  static Playlist playlistDataToDomain(PlaylistData data) {
    List<String>? signatures;
    if (data.signaturesJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(data.signaturesJson);
        signatures = (decoded as List).map((e) => e.toString()).toList();
      } catch (_) {
        // Ignore parsing errors
      }
    }

    Map<String, dynamic>? defaults;
    if (data.defaultsJson != null && data.defaultsJson!.isNotEmpty) {
      try {
        defaults = jsonDecode(data.defaultsJson!) as Map<String, dynamic>;
      } catch (_) {
        // Ignore parsing errors
      }
    }

    Map<String, dynamic>? dynamicQueries;
    if (data.dynamicQueriesJson != null &&
        data.dynamicQueriesJson!.isNotEmpty) {
      try {
        dynamicQueries =
            jsonDecode(data.dynamicQueriesJson!) as Map<String, dynamic>;
      } catch (_) {
        // Ignore parsing errors
      }
    }

    return Playlist(
      id: data.id,
      name: data.title,
      type: PlaylistType.values[data.type],
      channelId: data.channelId,
      baseUrl: data.baseUrl,
      dpVersion: data.dpVersion,
      slug: data.slug,
      createdAt: DateTime.fromMicrosecondsSinceEpoch(data.createdAtUs.toInt()),
      updatedAt: DateTime.fromMicrosecondsSinceEpoch(data.updatedAtUs.toInt()),
      signatures: signatures,
      defaults: defaults,
      dynamicQueries: dynamicQueries,
      ownerAddress: data.ownerAddress,
      ownerChain: data.ownerChain,
      sortMode: PlaylistSortMode.values[data.sortMode],
      itemCount: data.itemCount,
    );
  }

  /// Convert Playlist domain model to PlaylistsCompanion.
  static PlaylistsCompanion playlistToCompanion(Playlist playlist) {
    final signaturesJson = playlist.signatures != null
        ? jsonEncode(playlist.signatures)
        : jsonEncode([]);

    final defaultsJson =
        playlist.defaults != null ? jsonEncode(playlist.defaults) : null;

    final dynamicQueriesJson = playlist.dynamicQueries != null
        ? jsonEncode(playlist.dynamicQueries)
        : null;

    final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
    return PlaylistsCompanion.insert(
      id: playlist.id,
      type: playlist.type.index,
      title: playlist.name,
      createdAtUs: BigInt.from(
        playlist.createdAt?.microsecondsSinceEpoch ?? nowUs.toInt(),
      ),
      updatedAtUs: BigInt.from(
        playlist.updatedAt?.microsecondsSinceEpoch ?? nowUs.toInt(),
      ),
      signaturesJson: signaturesJson,
      sortMode: playlist.sortMode.index,
      itemCount: Value(playlist.itemCount),
      channelId: Value(playlist.channelId),
      baseUrl: Value(playlist.baseUrl),
      dpVersion: Value(playlist.dpVersion),
      slug: Value(playlist.slug),
      defaultsJson: Value(defaultsJson),
      dynamicQueriesJson: Value(dynamicQueriesJson),
      ownerAddress: Value(playlist.ownerAddress),
      ownerChain: Value(playlist.ownerChain),
    );
  }

  /// Convert ItemData to PlaylistItem domain model.
  static PlaylistItem itemDataToDomain(ItemData data) {
    Map<String, dynamic>? provenance;
    if (data.provenanceJson != null && data.provenanceJson!.isNotEmpty) {
      try {
        provenance = jsonDecode(data.provenanceJson!) as Map<String, dynamic>;
      } catch (_) {
        // Ignore parsing errors
      }
    }

    Map<String, dynamic>? reproduction;
    if (data.reproJson != null && data.reproJson!.isNotEmpty) {
      try {
        reproduction = jsonDecode(data.reproJson!) as Map<String, dynamic>;
      } catch (_) {
        // Ignore parsing errors
      }
    }

    Map<String, dynamic>? override;
    if (data.overrideJson != null && data.overrideJson!.isNotEmpty) {
      try {
        override = jsonDecode(data.overrideJson!) as Map<String, dynamic>;
      } catch (_) {
        // Ignore parsing errors
      }
    }

    Map<String, dynamic>? display;
    if (data.displayJson != null && data.displayJson!.isNotEmpty) {
      try {
        display = jsonDecode(data.displayJson!) as Map<String, dynamic>;
      } catch (_) {
        // Ignore parsing errors
      }
    }

    Map<String, dynamic>? tokenData;
    if (data.tokenDataJson != null && data.tokenDataJson!.isNotEmpty) {
      try {
        tokenData = jsonDecode(data.tokenDataJson!) as Map<String, dynamic>;
      } catch (_) {
        // Ignore parsing errors
      }
    }

    List<DP1Artist>? artists;
    if (data.listArtistJson != null && data.listArtistJson!.isNotEmpty) {
      try {
        final list = jsonDecode(data.listArtistJson!) as List;
        artists = list
            .map((e) => DP1Artist.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        // Ignore parsing errors
      }
    }

    return PlaylistItem(
      id: data.id,
      kind: PlaylistItemKind.values[data.kind],
      title: data.title ?? '',
      subtitle: data.subtitle,
      thumbnailUrl: data.thumbnailUri,
      durationSec: data.durationSec,
      provenance: provenance,
      sourceUri: data.sourceUri,
      refUri: data.refUri,
      license: data.license,
      reproduction: reproduction,
      override: override,
      display: display,
      tokenData: tokenData,
      artists: artists,
      updatedAt: DateTime.fromMicrosecondsSinceEpoch(data.updatedAtUs.toInt()),
    );
  }

  /// Convert PlaylistItem domain model to ItemsCompanion.
  static ItemsCompanion playlistItemToCompanion(PlaylistItem item) {
    final provenanceJson =
        item.provenance != null ? jsonEncode(item.provenance) : null;

    final reproJson =
        item.reproduction != null ? jsonEncode(item.reproduction) : null;

    final overrideJson =
        item.override != null ? jsonEncode(item.override) : null;

    final displayJson =
        item.display != null ? jsonEncode(item.display) : null;

    final tokenDataJson =
        item.tokenData != null ? jsonEncode(item.tokenData) : null;

    final listArtistJson = item.artists != null && item.artists!.isNotEmpty
        ? jsonEncode(item.artists!.map((e) => e.toJson()).toList())
        : null;

    final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
    return ItemsCompanion.insert(
      id: item.id,
      kind: item.kind.index,
      updatedAtUs: BigInt.from(
        item.updatedAt?.microsecondsSinceEpoch ?? nowUs.toInt(),
      ),
      title: Value(item.title),
      subtitle: Value(item.subtitle),
      thumbnailUri: Value(item.thumbnailUrl),
      durationSec: Value(item.durationSec),
      provenanceJson: Value(provenanceJson),
      sourceUri: Value(item.sourceUri),
      refUri: Value(item.refUri),
      license: Value(item.license),
      reproJson: Value(reproJson),
      overrideJson: Value(overrideJson),
      displayJson: Value(displayJson),
      tokenDataJson: Value(tokenDataJson),
      listArtistJson: Value(listArtistJson),
    );
  }

  /// Create PlaylistEntriesCompanion.
  static PlaylistEntriesCompanion createPlaylistEntry({
    required String playlistId,
    required String itemId,
    int? position,
    required int sortKeyUs,
  }) {
    return PlaylistEntriesCompanion.insert(
      playlistId: playlistId,
      itemId: itemId,
      sortKeyUs: BigInt.from(sortKeyUs),
      updatedAtUs: BigInt.from(DateTime.now().microsecondsSinceEpoch),
      position: Value(position),
    );
  }
}
