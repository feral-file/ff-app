import 'package:app/domain/constants/indexer_constants.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/dp1/dp1_playlist_signature.dart';

// ignore_for_file: public_member_api_docs, always_put_required_named_parameters_first, unnecessary_parenthesis, sort_constructors_first, avoid_equals_and_hash_code_on_mutable_classes, hash_and_equals, prefer_collection_literals // Reason: copied from the legacy mobile app; keep DP-1 playlist wire model stable.

/// Parses DP-1 v1.1.0 `signatures` plus legacy `signature` from wire JSON.
///
/// Only **object** elements in `signatures` are parsed (same rule as
/// `scripts/build_feed_indexer_sqlite.js`). String elements in the array are
/// ignored; use top-level `signature` for a single legacy string.
///
/// Non-empty structured `signatures` wins over `signature`.
({String? legacy, List<DP1PlaylistSignature> structured})
dp1PlaylistSignaturesFromWire(Map<String, dynamic> json) {
  final structured = <DP1PlaylistSignature>[];
  final raw = json['signatures'];
  if (raw is List && raw.isNotEmpty) {
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        structured.add(DP1PlaylistSignature.fromJson(e));
      } else if (e is Map) {
        structured.add(
          DP1PlaylistSignature.fromJson(Map<String, dynamic>.from(e)),
        );
      }
    }
  }

  String? legacy;
  final legacyRaw = json['signature'];
  if (legacyRaw is String && legacyRaw.trim().isNotEmpty) {
    legacy = legacyRaw.trim();
  }

  if (structured.isNotEmpty) {
    return (legacy: null, structured: structured);
  }
  if (legacy != null) {
    return (legacy: legacy, structured: const []);
  }
  return (legacy: null, structured: const []);
}

class DP1Playlist {
  DP1Playlist({
    required this.dpVersion,
    required this.id,
    required this.slug,
    required this.title,
    required this.created,
    this.defaults,
    required this.items,
    this.legacySignature,
    this.signatures = const [],
    this.dynamicQueries = const [],
  });

  // from JSON
  factory DP1Playlist.fromJson(Map<String, dynamic> json) {
    final sig = dp1PlaylistSignaturesFromWire(json);
    return DP1Playlist(
      dpVersion: json['dpVersion'] as String,
      id: json['id'] as String,
      slug: json['slug'] as String? ?? 'slug',
      title: json['title'] as String? ?? '',
      created: DateTime.parse(json['created'] as String),
      defaults: json['defaults'] as Map<String, dynamic>?,
      items: (json['items'] as List<dynamic>)
          .map((e) => DP1PlaylistItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      legacySignature: sig.legacy,
      signatures: sig.structured,
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

  final String dpVersion; // e.g., "1.0.0"
  final String id; // e.g., "refik-anadol-20250626T063826"
  final String slug; // e.g., "summer‑mix‑01"
  final String title;
  final DateTime created; // e.g., "2025-06-26T06:38:26.396Z"
  final Map<String, dynamic>? defaults; // e.g., {"display": {...}}
  final List<DP1PlaylistItem> items; // list of DP1PlaylistItem
  /// v1.0.x single string, or when `signatures` was empty on wire.
  final String? legacySignature;
  final List<DP1PlaylistSignature> signatures;
  final List<DynamicQuery> dynamicQueries;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'dpVersion': dpVersion,
      'id': id,
      'slug': slug,
      'title': title,
      'created': created.toIso8601String(),
      'defaults': defaults,
      'items': items.map((e) => e.toJson()).toList(),
      'signatures': signatures.map((e) => e.toJson()).toList(),
      'dynamicQueries': dynamicQueries.map((e) => e.toJson()).toList(),
    };
    if (legacySignature != null && legacySignature!.isNotEmpty) {
      map['signature'] = legacySignature;
    }
    return map;
  }

  DynamicQuery? get firstDynamicQuery =>
      dynamicQueries.isNotEmpty ? dynamicQueries.first : null;

  // copyWith method
  DP1Playlist copyWith({
    String? dpVersion,
    String? id,
    String? slug,
    String? title,
    DateTime? created,
    Map<String, dynamic>? defaults,
    List<DP1PlaylistItem>? items,
    String? legacySignature,
    List<DP1PlaylistSignature>? signatures,
    List<DynamicQuery>? dynamicQueries,
  }) {
    return DP1Playlist(
      dpVersion: dpVersion ?? this.dpVersion,
      id: id ?? this.id,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      created: created ?? this.created,
      defaults: defaults ?? this.defaults,
      items: items ?? this.items,
      legacySignature: legacySignature ?? this.legacySignature,
      signatures: signatures ?? this.signatures,
      dynamicQueries: dynamicQueries ?? this.dynamicQueries,
    );
  }

  // == operator
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DP1Playlist &&
        other.dpVersion == dpVersion &&
        other.id == id;
  }

  bool isItemsEqual(Object other) {
    if (identical(this, other)) return true;
    return other is DP1Playlist && other.items == items;
  }
}

class DynamicQuery {
  DynamicQuery({
    required this.endpoint,
    required this.params,
  });

  final String endpoint;
  final DynamicQueryParams params;

  Map<String, dynamic> toJson() {
    return {
      'endpoint': endpoint,
      'params': params.toJson(),
    };
  }

  factory DynamicQuery.fromJson(Map<String, dynamic> json) {
    return DynamicQuery(
      endpoint: json['endpoint'] as String,
      params: DynamicQueryParams.fromJson(
        json['params'] as Map<String, dynamic>,
      ),
    );
  }

  // copyWith method
  DynamicQuery copyWith({
    String? endpoint,
    DynamicQueryParams? params,
  }) {
    return DynamicQuery(
      endpoint: endpoint ?? this.endpoint,
      params: params ?? this.params,
    );
  }

  DynamicQuery insertAddresses(List<String> addresses) {
    return copyWith(params: params.insertAddresses(addresses));
  }

  DynamicQuery removeAddresses(List<String> addresses) {
    return copyWith(params: params.removeAddresses(addresses));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DynamicQuery) return false;
    return endpoint == other.endpoint && params == other.params;
  }

  @override
  int get hashCode => Object.hash(endpoint, params);
}

class DynamicQueryParams {
  DynamicQueryParams({
    required this.owners,
    this.sortBy = IndexerAssetTokenSortBy.lastActivityTime,
  });

  final List<String> owners;
  IndexerAssetTokenSortBy sortBy;

  Map<String, dynamic> toJson() {
    return {
      'owners': owners.join(','),
    };
  }

  factory DynamicQueryParams.fromJson(Map<String, dynamic> json) {
    final ownersData = json['owners'];
    List<String> owners;
    if (ownersData is String) {
      owners = ownersData.split(',').where((s) => s.isNotEmpty).toList();
    } else if (ownersData is List) {
      owners = ownersData.cast<String>();
    } else {
      owners = [];
    }
    return DynamicQueryParams(owners: owners);
  }

  // copyWith method
  DynamicQueryParams copyWith({
    List<String>? owners,
  }) {
    return DynamicQueryParams(owners: owners ?? this.owners);
  }

  DynamicQueryParams insertAddresses(List<String> addresses) {
    return copyWith(owners: [...owners, ...addresses].toSet().toList());
  }

  DynamicQueryParams removeAddresses(List<String> addresses) {
    return copyWith(
      owners: owners.where((e) => !addresses.contains(e)).toList(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DynamicQueryParams) return false;
    // Compare owners order-insensitively
    final a = List<String>.from(owners)..sort();
    final b = List<String>.from(other.owners)..sort();
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final sorted = List<String>.from(owners)..sort();
    return Object.hashAll(sorted);
  }
}
