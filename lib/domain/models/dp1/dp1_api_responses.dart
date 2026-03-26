import 'package:app/domain/models/dp1/dp1_channel.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';

// ignore_for_file: public_member_api_docs, unnecessary_parenthesis, lines_longer_than_80_chars
//
// Reason: copied from the legacy mobile app response shapes; keep DP-1 wire
// response models stable and portable.

/// Response shape for `/api/v1/playlists`.
///
/// Matches the legacy app's `DP1PlaylistResponse` (items/hasMore/cursor).
class DP1PlaylistResponse {
  DP1PlaylistResponse(
    this.items,
    this.hasMore,
    this.cursor,
  );

  factory DP1PlaylistResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(DP1PlaylistResponse._playlistFromJsonCompat)
        .toList();
    return DP1PlaylistResponse(
      items,
      (json['hasMore'] as bool?) ?? false,
      json['cursor'] as String?,
    );
  }

  final List<DP1Playlist> items;
  final bool hasMore;
  final String? cursor;

  Map<String, dynamic> toJson() => {
    'items': items.map((e) => e.toJson()).toList(),
    'hasMore': hasMore,
    'cursor': cursor,
  };

  /// Best-effort parser to keep compatibility with DP1 servers that differ
  /// slightly from the legacy JSON shape.
  ///
  /// Legacy expects:
  /// - `created` (ISO8601)
  /// - `signature` (string)
  ///
  /// Some servers provide:
  /// - `createdAt` or `created_at`
  /// - `signatures` (list)
  ///
  /// Signature fields are normalized via [dp1PlaylistSignaturesFromWire].
  static DP1Playlist _playlistFromJsonCompat(Map<String, dynamic> json) {
    try {
      return DP1Playlist.fromJson(json);
    } catch (_) {
      final createdRaw =
          json['created'] ?? json['createdAt'] ?? json['created_at'];
      DateTime created;
      if (createdRaw is String) {
        created = DateTime.tryParse(createdRaw) ?? DateTime.now();
      } else {
        created = DateTime.now();
      }

      final itemsRaw = (json['items'] as List?) ?? const [];
      final items = itemsRaw
          .whereType<Map<String, dynamic>>()
          .map(DP1PlaylistItem.fromJson)
          .toList();

      return DP1Playlist(
        dpVersion: (json['dpVersion'] as String?) ?? '',
        id: (json['id'] as String?) ?? '',
        slug: (json['slug'] as String?) ?? 'slug',
        title: (json['title'] as String?) ?? '',
        created: created,
        defaults: json['defaults'] as Map<String, dynamic>?,
        items: items,
        signatures: dp1PlaylistSignaturesFromWire(json),
        dynamicQueries: (json['dynamicQueries'] == null)
            ? []
            : (List<dynamic>.from(json['dynamicQueries'] as List))
                  .map(
                    (e) => DynamicQuery.fromJson(
                      Map<String, dynamic>.from(e as Map),
                    ),
                  )
                  .toList(),
      );
    }
  }
}

/// Response shape for `/api/v1/channels`.
///
/// Matches the legacy app's `DP1ChannelsResponse` (items/hasMore/cursor).
class DP1ChannelsResponse {
  DP1ChannelsResponse(
    this.items,
    this.hasMore,
    this.cursor,
  );

  factory DP1ChannelsResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(DP1ChannelsResponse._channelFromJsonCompat)
        .toList();
    return DP1ChannelsResponse(
      items,
      (json['hasMore'] as bool?) ?? false,
      json['cursor'] as String?,
    );
  }

  final List<DP1Channel> items;
  final bool hasMore;
  final String? cursor;

  Map<String, dynamic> toJson() => {
    'items': items.map((e) => e.toJson()).toList(),
    'hasMore': hasMore,
    'cursor': cursor,
  };

  static DP1Channel _channelFromJsonCompat(Map<String, dynamic> json) {
    try {
      return DP1Channel.fromJson(json);
    } catch (_) {
      final createdRaw =
          json['created'] ?? json['createdAt'] ?? json['created_at'];
      DateTime created;
      if (createdRaw is String) {
        created = DateTime.tryParse(createdRaw) ?? DateTime.now();
      } else {
        created = DateTime.now();
      }

      return DP1Channel(
        id: (json['id'] as String?) ?? '',
        slug: (json['slug'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        curator: json['curator'] as String?,
        summary: json['summary'] as String?,
        playlists: ((json['playlists'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        created: created,
        coverImage:
            (json['coverImage'] as String?) ??
            (json['coverImageUri'] as String?),
      );
    }
  }
}

/// Response shape for `/api/v1/items` (or channel items endpoints).
///
/// Matches the legacy app's `DP1PlaylistItemsResponse` (items/hasMore/cursor).
class DP1PlaylistItemsResponse {
  DP1PlaylistItemsResponse(this.items, this.hasMore, this.cursor);

  factory DP1PlaylistItemsResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    return DP1PlaylistItemsResponse(
      rawItems
          .whereType<Map<String, dynamic>>()
          .map(DP1PlaylistItem.fromJson)
          .toList(),
      (json['hasMore'] as bool?) ?? false,
      json['cursor'] as String?,
    );
  }

  final List<DP1PlaylistItem> items;
  final bool hasMore;
  final String? cursor;

  Map<String, dynamic> toJson() => {
    'items': items.map((e) => e.toJson()).toList(),
    'hasMore': hasMore,
    'cursor': cursor,
  };
}
