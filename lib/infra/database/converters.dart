import 'dart:convert';

import 'package:app/domain/extensions/asset_token_ext.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/dp1/dp1_manifest.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/dp1/dp1_playlist_signature.dart';
import 'package:app/domain/models/dp1/dp1_provenance.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:drift/drift.dart';

/// Converts between domain models and database models.
///
/// **Performance note:**
/// - `*ToDomain()` methods perform full deserialization of all JSON fields.
/// - `*ToDomainPreview()` methods skip heavy JSON fields for list UI
///   performance.
class DatabaseConverters {
  /// Convert ChannelData to Channel domain model.
  static Channel channelDataToDomain(ChannelData data) {
    return Channel(
      id: data.id,
      name: data.title,
      type: ChannelType.values[data.type],
      description: data.summary,
      baseUrl: data.baseUrl,
      slug: data.slug,
      publisherId: data.publisherId,
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
      publisherId: Value(channel.publisherId),
      curator: Value(channel.curator),
      summary: Value(channel.description),
      coverImageUri: Value(channel.coverImageUrl),
      sortOrder: Value(channel.sortOrder),
    );
  }

  /// Convert PlaylistData to Playlist domain model (full deserialization).
  ///
  /// Performs JSON parsing for signatures, defaults, and dynamicQueries.
  /// Use [playlistDataToDomainPreview] for list UI to skip expensive JSON work.
  static Playlist playlistDataToDomain(PlaylistData data) {
    final legacySignature = data.signature;

    List<DP1PlaylistSignature>? structuredSignatures;
    if (data.signatures.isNotEmpty) {
      try {
        final decoded = jsonDecode(data.signatures) as List;
        final parsed = <DP1PlaylistSignature>[];
        for (final e in decoded) {
          if (e is Map) {
            parsed.add(
              DP1PlaylistSignature.fromJson(
                Map<String, dynamic>.from(e),
              ),
            );
          }
        }
        structuredSignatures = parsed.isEmpty ? null : parsed;
      } on Object {
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

    List<DynamicQuery>? dynamicQueries;
    if (data.dynamicQueriesJson != null &&
        data.dynamicQueriesJson!.isNotEmpty) {
      try {
        dynamicQueries = (jsonDecode(data.dynamicQueriesJson!) as List)
            .map((e) => DynamicQuery.fromJson(e as Map<String, dynamic>))
            .toList();
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
      legacySignature: legacySignature,
      signatures: structuredSignatures,
      defaults: defaults,
      dynamicQueries: dynamicQueries,
      ownerAddress: data.ownerAddress,
      ownerChain: data.ownerChain,
      sortMode: PlaylistSortMode.values[data.sortMode],
      itemCount: data.itemCount,
    );
  }

  /// Convert PlaylistData to Playlist (light projection for list UI).
  ///
  /// Skips JSON deserialization of signatures, defaults, and dynamicQueries.
  /// Use for list queries where only basic fields (id, name, itemCount) are needed.
  static Playlist playlistDataToDomainPreview(PlaylistData data) {
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
      ownerAddress: data.ownerAddress,
      ownerChain: data.ownerChain,
      sortMode: PlaylistSortMode.values[data.sortMode],
      itemCount: data.itemCount,
    );
  }

  /// Convert Playlist domain model to PlaylistsCompanion.
  static PlaylistsCompanion playlistToCompanion(Playlist playlist) {
    final signaturesJson = jsonEncode(
      (playlist.signatures ?? const <DP1PlaylistSignature>[])
          .map((e) => e.toJson())
          .toList(),
    );

    final defaultsJson = playlist.defaults != null
        ? jsonEncode(playlist.defaults)
        : null;

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
      signature: Value(playlist.legacySignature),
      signatures: Value(signaturesJson),
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

  /// Convert ItemData to PlaylistItem domain model (full deserialization).
  ///
  /// Performs JSON parsing for provenance, reproduction, override, display, and artists.
  /// Use [itemDataToDomainPreview] for list UI to skip expensive JSON work.
  static PlaylistItem itemDataToDomain(ItemData data) {
    DP1Provenance? provenance;
    if (data.provenanceJson != null && data.provenanceJson!.isNotEmpty) {
      try {
        final map = jsonDecode(data.provenanceJson!) as Map<String, dynamic>;
        provenance = DP1Provenance.fromJson(map);
      } catch (_) {
        // Ignore parsing errors
      }
    }

    ReproBlock? reproduction;
    if (data.reproJson != null && data.reproJson!.isNotEmpty) {
      try {
        final map = jsonDecode(data.reproJson!) as Map<String, dynamic>;
        reproduction = ReproBlock.fromJson(map);
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

    DP1PlaylistDisplay? display;
    if (data.displayJson != null && data.displayJson!.isNotEmpty) {
      try {
        final map = jsonDecode(data.displayJson!) as Map<String, dynamic>;
        display = DP1PlaylistDisplay.fromJson(map);
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
      thumbnailUrl: data.thumbnailUri,
      duration: data.durationSec ?? 0,
      provenance: provenance,
      source: data.sourceUri,
      ref: data.refUri,
      license: data.license != null
          ? ArtworkDisplayLicense.fromString(data.license!)
          : null,
      repro: reproduction,
      overrideData: override,
      display: display,
      artists: artists,
      updatedAt: DateTime.fromMicrosecondsSinceEpoch(data.updatedAtUs.toInt()),
    );
  }

  /// Convert ItemData to PlaylistItem (light projection for list UI).
  ///
  /// Skips JSON deserialization of provenance, reproduction, override, and display.
  /// Keeps artists and basic fields for display, avoiding heavy JSON parsing.
  /// Use for list queries where only title, thumbnail, and basic metadata are needed.
  static PlaylistItem itemDataToDomainPreview(ItemData data) {
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
      thumbnailUrl: data.thumbnailUri,
      duration: data.durationSec ?? 0,
      source: data.sourceUri,
      ref: data.refUri,
      license: data.license != null
          ? ArtworkDisplayLicense.fromString(data.license!)
          : null,
      artists: artists,
      updatedAt: DateTime.fromMicrosecondsSinceEpoch(data.updatedAtUs.toInt()),
    );
  }

  /// Convert PlaylistItem domain model to ItemsCompanion.
  static ItemsCompanion playlistItemToCompanion(PlaylistItem item) {
    final provenanceJson = item.provenance != null
        ? jsonEncode(item.provenance!.toJson())
        : null;

    final reproJson = item.repro != null
        ? jsonEncode(item.repro!.toJson())
        : null;

    final overrideJson = item.overrideData != null
        ? jsonEncode(item.overrideData)
        : null;

    final displayJson = item.display != null
        ? jsonEncode(item.display!.toJson())
        : null;

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
      thumbnailUri: Value(item.thumbnailUrl),
      durationSec: Value(item.duration),
      provenanceJson: Value(provenanceJson),
      sourceUri: Value(item.source),
      refUri: Value(item.ref),
      license: Value(item.license?.value),
      reproJson: Value(reproJson),
      overrideJson: Value(overrideJson),
      displayJson: Value(displayJson),
      listArtistJson: Value(listArtistJson),
    );
  }

  /// Create PlaylistEntriesCompanion.
  static PlaylistEntriesCompanion createPlaylistEntry({
    required String playlistId,
    required String itemId,
    required int sortKeyUs,
    int? position,
  }) {
    return PlaylistEntriesCompanion.insert(
      playlistId: playlistId,
      itemId: itemId,
      sortKeyUs: BigInt.from(sortKeyUs),
      updatedAtUs: BigInt.from(DateTime.now().microsecondsSinceEpoch),
      position: Value(position),
    );
  }

  /// Convert PlaylistItem (domain) to DP1PlaylistItem (wire).
  /// PlaylistItem extends DP1PlaylistItem so the item is returned as-is.
  static DP1PlaylistItem playlistItemToDP1PlaylistItem(PlaylistItem item) {
    return item;
  }

  /// Convert Playlist + items (domain) to DP1Playlist (wire).
  /// Used when feed service returns cached domain and caller needs DP1.
  static DP1Playlist playlistAndItemsToDP1Playlist(
    Playlist playlist,
    List<PlaylistItem> items,
  ) {
    final isAddressPlaylist = playlist.ownerAddress != null;
    final dp1Items = isAddressPlaylist
        ? <DP1PlaylistItem>[]
        : items.map(playlistItemToDP1PlaylistItem).toList();

    return DP1Playlist(
      dpVersion: playlist.dpVersion ?? '1.0.0',
      id: playlist.id,
      slug: playlist.slug ?? 'slug',
      title: playlist.name,
      created: playlist.createdAt ?? DateTime.now(),
      defaults: playlist.defaults,
      items: dp1Items,
      legacySignature: playlist.legacySignature,
      signatures: playlist.signatures ?? const [],
      dynamicQueries: playlist.dynamicQueries ?? const [],
    );
  }

  /// Convert DP1Playlist (wire) to Playlist domain model.
  /// Used when creating PlaylistReference from API response.
  /// [channelId] must be set when playlist is ingested in channel context so
  /// channel-scoped queries can resolve items (`playlists.channel_id` in DB).
  static Playlist dp1PlaylistToDomain(
    DP1Playlist dp1, {
    String? baseUrl,
    String? channelId,
  }) {
    final dynamicQueries = dp1.dynamicQueries;
    final sortMode = dynamicQueries.isNotEmpty
        ? PlaylistSortMode.provenance
        : PlaylistSortMode.position;
    final structuredSigs = dp1.signatures.isEmpty
        ? null
        : List<DP1PlaylistSignature>.from(dp1.signatures);
    return Playlist(
      id: dp1.id,
      name: dp1.title,
      type: PlaylistType.dp1,
      playlistSource: PlaylistSource.curated,
      channelId: channelId,
      baseUrl: baseUrl,
      dpVersion: dp1.dpVersion,
      slug: dp1.slug,
      createdAt: dp1.created,
      updatedAt: dp1.created,
      legacySignature: dp1.legacySignature,
      signatures: structuredSigs,
      defaults: dp1.defaults,
      dynamicQueries: dynamicQueries,
      sortMode: sortMode,
      itemCount: dp1.items.length,
    );
  }

  /// Convert DP1PlaylistItem (wire) to PlaylistItem domain model.
  /// When [token] is provided, any null/empty fields from [item] fall back to
  /// token data (title, thumbnailUrl, artists, source).
  static PlaylistItem dp1PlaylistItemToPlaylistItem(
    DP1PlaylistItem item, {
    AssetToken? token,
  }) {
    // Use item value when non-empty; otherwise fall back to token.
    final title =
        _nonEmptyString(item.title) ?? token?.displayTitle ?? 'Unknown';
    final source = _nonEmptyString(item.source) ?? token?.getPreviewUrl();
    final ref = _nonEmptyString(item.ref);
    final thumbnailUrl = token?.getGalleryThumbnailUrl();
    final artists = (token?.getArtists ?? <Artist>[])
        .map((a) => DP1Artist(name: a.name, id: a.did))
        .toList();
    final artistsOrNull = artists.isEmpty ? null : artists;

    return PlaylistItem(
      id: item.id,
      kind: PlaylistItemKind.dp1Item,
      title: title,
      source: source,
      ref: ref,
      license: item.license,
      duration: item.duration,
      provenance: item.provenance,
      repro: item.repro,
      display: item.display,
      thumbnailUrl: thumbnailUrl,
      artists: artistsOrNull,
      updatedAt: DateTime.now(),
    );
  }

  /// Returns [s] if non-null and non-empty; otherwise null.
  static String? _nonEmptyString(String? s) =>
      (s != null && s.isNotEmpty) ? s : null;
}
