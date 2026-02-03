// ignore_for_file: public_member_api_docs, sort_constructors_first // Reason: protocol-shaped indexer models; keep stable + auditable.

import 'package:app/domain/models/indexer/changes/change_meta.dart';

/// Subject type for change journal entries.
///
/// Based on indexer change journal: token, owner, balance, metadata,
/// enrichment_source, token_viewability.
enum SubjectType {
  token,
  owner,
  balance,
  metadata,
  enrichmentSource,
  tokenViewability;

  /// Serialize to the indexer API string.
  String toJson() {
    switch (this) {
      case SubjectType.token:
        return 'token';
      case SubjectType.owner:
        return 'owner';
      case SubjectType.balance:
        return 'balance';
      case SubjectType.metadata:
        return 'metadata';
      case SubjectType.enrichmentSource:
        return 'enrich_source';
      case SubjectType.tokenViewability:
        return 'token_viewability';
    }
  }

  /// Parse from the indexer API string.
  static SubjectType? fromJson(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'token':
        return SubjectType.token;
      case 'owner':
        return SubjectType.owner;
      case 'balance':
        return SubjectType.balance;
      case 'metadata':
        return SubjectType.metadata;
      case 'enrich_source':
        return SubjectType.enrichmentSource;
      case 'token_viewability':
        return SubjectType.tokenViewability;
      default:
        return null;
    }
  }
}

/// One change journal entry from the indexer.
class Change {
  /// Creates a Change.
  const Change({
    required this.id,
    required this.subjectType,
    required this.subjectId,
    required this.changedAt,
    required this.createdAt,
    required this.updatedAt,
    Map<String, dynamic>? meta,
  }) : _metaRaw = meta;

  /// Change ID.
  final int id;

  /// What kind of subject changed.
  final SubjectType subjectType;

  /// Subject identifier (indexer-specific).
  final String subjectId;

  /// Timestamp when the change occurred.
  final DateTime changedAt;

  final Map<String, dynamic>? _metaRaw;

  /// Timestamp when the journal entry was created.
  final DateTime createdAt;

  /// Timestamp when the journal entry was last updated.
  final DateTime updatedAt;

  /// Raw `meta` map (nullable).
  Map<String, dynamic>? get meta => _metaRaw;

  /// Parsed meta based on [subjectType].
  ChangeMeta? get metaParsed {
    final meta = _metaRaw;
    if (meta == null) return null;
    try {
      switch (subjectType) {
        case SubjectType.token:
        case SubjectType.owner:
        case SubjectType.balance:
          return ProvenanceChangeMeta.fromJson(meta);
        case SubjectType.metadata:
          return MetadataChangeMeta.fromJson(meta);
        case SubjectType.enrichmentSource:
          return EnrichmentSourceChangeMeta.fromJson(meta);
        case SubjectType.tokenViewability:
          return TokenViewabilityChangeMeta.fromJson(meta);
      }
    } on Object catch (_) {
      return null;
    }
  }

  /// Token numeric ID, if available in meta.
  int? get tokenId {
    final parsed = metaParsed;
    if (parsed is ProvenanceChangeMeta) return parsed.tokenId;
    if (parsed is MetadataChangeMeta) return parsed.tokenId;
    if (parsed is EnrichmentSourceChangeMeta) return parsed.tokenId;
    if (parsed is TokenViewabilityChangeMeta) return parsed.tokenId;
    return null;
  }

  /// Token CID string, if derivable.
  ///
  /// For provenance-like changes we can derive a stable token CID.
  String? get tokenCid {
    final parsed = metaParsed;
    if (parsed is ProvenanceChangeMeta) return parsed.tokenCid;
    if (parsed is TokenViewabilityChangeMeta) return parsed.tokenCid;
    return null;
  }

  /// True when this change represents a mint.
  bool isMint() =>
      metaParsed is ProvenanceChangeMeta &&
      (metaParsed! as ProvenanceChangeMeta).isMint();

  /// True when this change represents a burn.
  bool isBurn() =>
      metaParsed is ProvenanceChangeMeta &&
      (metaParsed! as ProvenanceChangeMeta).isBurn();

  /// True when this change represents a transfer.
  bool isTransfer() =>
      metaParsed is ProvenanceChangeMeta &&
      (metaParsed! as ProvenanceChangeMeta).isTransfer();

  /// True when this change is a metadata update.
  bool isMetadataUpdate() => metaParsed is MetadataChangeMeta;

  /// True when this change is an enrichment source update.
  bool isEnrichmentSourceUpdate() => metaParsed is EnrichmentSourceChangeMeta;

  /// Create from JSON returned by the indexer.
  factory Change.fromJson(Map<String, dynamic> json) => Change(
        id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
        subjectType: SubjectType.fromJson(json['subject_type'] as String?) ??
            SubjectType.token,
        subjectId: json['subject_id'] as String? ?? '',
        changedAt: DateTime.tryParse(json['changed_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        meta: (json['meta'] as Map?)?.cast<String, dynamic>(),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'subject_type': subjectType.toJson(),
        'subject_id': subjectId,
        'changed_at': changedAt.toIso8601String(),
        'meta': _metaRaw,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// A paginated list of changes.
class ChangeList {
  /// Creates a ChangeList.
  const ChangeList({
    required this.items,
    required this.total,
    this.offset,
    this.nextAnchor,
  });

  /// Change items.
  final List<Change> items;

  /// Optional offset.
  final int? offset;

  /// Total count (if provided by the indexer).
  final int total;

  /// Anchor for the next page.
  final int? nextAnchor;

  /// Create from JSON returned by the indexer.
  factory ChangeList.fromJson(Map<String, dynamic> json) => ChangeList(
        items: (json['items'] as List?)
                ?.whereType<Map<Object?, Object?>>()
                .map((e) => Change.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const <Change>[],
        total: int.tryParse(json['total']?.toString() ?? '') ?? 0,
        offset: int.tryParse(json['offset']?.toString() ?? ''),
        nextAnchor: int.tryParse(json['next_anchor']?.toString() ?? ''),
      );

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'items': items.map((c) => c.toJson()).toList(),
        'offset': offset,
        'total': total,
        if (nextAnchor != null) 'next_anchor': nextAnchor,
      };
}

/// Request model for querying changes.
class QueryChangesRequest {
  /// Creates a QueryChangesRequest.
  const QueryChangesRequest({
    this.tokenCids = const [],
    this.addresses = const [],
    this.limit = 20,
    this.anchor,
  });

  /// Filter by token CIDs.
  final List<String> tokenCids;

  /// Filter by owner addresses.
  final List<String> addresses;

  /// Page size.
  final int limit;

  /// Anchor (cursor) for pagination.
  final int? anchor;

  /// Serialize to GraphQL variables.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'limit': limit,
    };

    if (tokenCids.isNotEmpty) {
      json['token_cids'] = tokenCids;
    }

    if (addresses.isNotEmpty) {
      json['addresses'] = addresses;
    }

    if (anchor != null) {
      json['anchor'] = anchor;
    }

    return json;
  }
}

// End of file.
