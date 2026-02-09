import 'dart:convert';

import 'package:app/domain/extensions/asset_token_ext.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/dp1/dp1_channel.dart';
import 'package:app/domain/models/dp1/dp1_manifest.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
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
/// - `*ToDomainPreview()` methods skip heavy JSON fields for list UI performance.
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

  /// Convert PlaylistData to Playlist domain model (full deserialization).
  ///
  /// Performs JSON parsing for signatures, defaults, and dynamicQueries.
  /// Use [playlistDataToDomainPreview] for list UI to skip expensive JSON work.
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
      signatures: signatures,
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
      signatures: null, // Skipped: heavy JSON decode
      defaults: null, // Skipped: heavy JSON decode
      dynamicQueries: null, // Skipped: heavy JSON decode
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

  /// Convert ItemData to PlaylistItem domain model (full deserialization).
  ///
  /// Performs JSON parsing for provenance, reproduction, override, display, tokenData, and artists.
  /// Use [itemDataToDomainPreview] for list UI to skip expensive JSON work.
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

  /// Convert ItemData to PlaylistItem (light projection for list UI).
  ///
  /// Skips JSON deserialization of provenance, reproduction, override, display, and tokenData.
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
      subtitle: data.subtitle,
      thumbnailUrl: data.thumbnailUri,
      durationSec: data.durationSec,
      provenance: null, // Skipped: heavy JSON decode
      sourceUri: data.sourceUri,
      refUri: data.refUri,
      license: data.license,
      reproduction: null, // Skipped: heavy JSON decode
      override: null, // Skipped: heavy JSON decode
      display: null, // Skipped: heavy JSON decode
      tokenData: null, // Skipped: heavy JSON decode
      artists: artists,
      updatedAt: DateTime.fromMicrosecondsSinceEpoch(data.updatedAtUs.toInt()),
    );
  }

  /// Convert PlaylistItem domain model to ItemsCompanion.
  static ItemsCompanion playlistItemToCompanion(PlaylistItem item) {
    final provenanceJson = item.provenance != null
        ? jsonEncode(item.provenance)
        : null;

    final reproJson = item.reproduction != null
        ? jsonEncode(item.reproduction)
        : null;

    final overrideJson = item.override != null
        ? jsonEncode(item.override)
        : null;

    final displayJson = item.display != null ? jsonEncode(item.display) : null;

    final tokenDataJson = item.tokenData != null
        ? jsonEncode(item.tokenData)
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

  /// Convert ItemData to DP1PlaylistItem (wire model).
  /// Matches old repo's DP1ItemExtension.fromItemRow / DP1 playlist item shape.
  static DP1PlaylistItem itemDataToDP1PlaylistItem(ItemData data) {
    final playlistItem = itemDataToDomain(data);
    return playlistItemToDP1PlaylistItem(playlistItem);
  }

  /// Convert PlaylistItem (domain) to DP1PlaylistItem (wire).
  static DP1PlaylistItem playlistItemToDP1PlaylistItem(PlaylistItem item) {
    return DP1PlaylistItem(
      id: item.id,
      title: item.title,
      source: item.sourceUri,
      duration: item.durationSec ?? 0,
      license: item.license != null
          ? ArtworkDisplayLicense.fromString(item.license!)
          : null,
      ref: item.refUri,
      provenance: item.provenance != null
          ? DP1Provenance.fromJson(item.provenance!)
          : null,
      repro: item.reproduction != null
          ? ReproBlock.fromJson(item.reproduction!)
          : null,
      display: item.display != null
          ? DP1PlaylistDisplay.fromJson(item.display!)
          : null,
    );
  }

  /// Convert Playlist + items (domain) to DP1Playlist (wire).
  /// Used when feed service returns cached domain and caller needs DP1.
  static DP1Playlist playlistAndItemsToDP1Playlist(
    Playlist playlist,
    List<PlaylistItem> items,
  ) {
    final dp1Items = items.map(playlistItemToDP1PlaylistItem).toList();
    return DP1Playlist(
      dpVersion: playlist.dpVersion ?? '1.0.0',
      id: playlist.id,
      slug: playlist.slug ?? 'slug',
      title: playlist.name,
      created: playlist.createdAt ?? DateTime.now(),
      defaults: playlist.defaults,
      items: dp1Items,
      signature: playlist.signatures?.isNotEmpty == true
          ? playlist.signatures!.first
          : '',
      dynamicQueries: const [],
    );
  }

  /// Convert PlaylistData + items to DP1Playlist (wire model).
  /// Matches old repo's _addressPlaylistRowToModel for DP1 playlists.
  static DP1Playlist playlistDataAndItemsToDP1Playlist(
    PlaylistData data,
    List<ItemData> items,
  ) {
    final playlistItems = items.map(itemDataToDomain).toList();
    final playlist = playlistDataToDomain(data);
    return playlistAndItemsToDP1Playlist(playlist, playlistItems);
  }

  /// Convert DP1Playlist (wire) to Playlist domain model.
  /// Used when creating PlaylistReference from API response.
  /// [channelId] must be set when playlist is ingested in channel context so
  /// [getPlaylistItemsByChannel] can return items (playlists.channel_id in DB).
  static Playlist dp1PlaylistToDomain(
    DP1Playlist dp1, {
    String? baseUrl,
    String? channelId,
  }) {
    final dynamicQueries = dp1.dynamicQueries;
    final sortMode = dynamicQueries.isNotEmpty
        ? PlaylistSortMode.provenance
        : PlaylistSortMode.position;
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
      signatures: dp1.signature.isNotEmpty ? <String>[dp1.signature] : null,
      defaults: dp1.defaults,
      dynamicQueries: dynamicQueries,
      sortMode: sortMode,
      itemCount: dp1.items.length,
    );
  }

  /// Convert DP1PlaylistItem (wire) to PlaylistItem domain model.
  /// When [token] is provided, thumbnail and artists are taken from the token;
  /// otherwise they are null.
  static PlaylistItem dp1PlaylistItemToPlaylistItem(
    DP1PlaylistItem item, {
    AssetToken? token,
  }) {
    final thumbnailUrl = token?.getGalleryThumbnailUrl();
    final artists = token?.metadata?.artists
        ?.map((a) => DP1Artist(name: a.name, id: a.did))
        .toList();

    return PlaylistItem(
      id: item.id,
      kind: PlaylistItemKind.dp1Item,
      title: item.title ?? token?.displayTitle ?? 'Unknown',
      sourceUri: item.source,
      refUri: item.ref,
      license: item.license?.value,
      durationSec: item.duration,
      provenance: item.provenance?.toJson(),
      reproduction: item.repro?.toJson(),
      display: item.display?.toJson(),
      thumbnailUrl: thumbnailUrl,
      artists: artists,
      updatedAt: DateTime.now(),
    );
  }

  /// Convert ChannelData + playlist full URLs to DP1Channel (wire model).
  /// Matches old repo's Channel in ChannelReference.
  static DP1Channel channelDataToDP1Channel(
    ChannelData data,
    List<String> playlistUrls,
  ) {
    final channel = channelDataToDomain(data);
    return channelToDP1Channel(channel, playlistUrls);
  }

  /// Convert Channel (domain) to DP1Channel (wire).
  static DP1Channel channelToDP1Channel(
    Channel channel,
    List<String> playlistUrls,
  ) {
    return DP1Channel(
      id: channel.id,
      slug: channel.slug ?? '',
      title: channel.name,
      curator: channel.curator,
      summary: channel.description,
      playlists: playlistUrls,
      created: channel.createdAt ?? DateTime.now(),
      coverImage: channel.coverImageUrl,
    );
  }
}
