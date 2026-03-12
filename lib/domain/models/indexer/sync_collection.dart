//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

// ignore_for_file: public_member_api_docs // Reason: protocol-shaped indexer models; comment_references adds invalid self-import.

/// A single token event from the indexer syncCollection API.
///
/// Event types: acquired, released, metadata_updated, enrichment_updated,
/// viewability_changed.
class TokenEvent {
  const TokenEvent({
    required this.id,
    required this.tokenId,
    required this.eventType,
    required this.occurredAt,
    this.ownerAddress,
    this.metadata,
  });

  factory TokenEvent.fromJson(Map<String, dynamic> json) => TokenEvent(
    id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
    tokenId: int.tryParse(json['token_id']?.toString() ?? '') ?? 0,
    eventType: json['event_type'] as String? ?? '',
    ownerAddress: json['owner_address'] as String?,
    occurredAt:
        DateTime.tryParse(json['occurred_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
  );

  final int id;
  final int tokenId;
  final String eventType;
  final String? ownerAddress;
  final DateTime occurredAt;
  final Map<String, dynamic>? metadata;
}

/// Checkpoint for syncCollection pagination.
///
/// Returned as next_checkpoint; used as input for the next request.
class SyncCheckpoint {
  const SyncCheckpoint({
    required this.timestamp,
    required this.eventId,
  });

  factory SyncCheckpoint.fromJson(Map<String, dynamic> json) => SyncCheckpoint(
    timestamp:
        DateTime.tryParse(json['timestamp'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    eventId: int.tryParse(json['event_id']?.toString() ?? '') ?? 0,
  );

  final DateTime timestamp;
  final int eventId;

  /// Serialize for GraphQL vars. timestamp as ISO 8601 string.
  Map<String, dynamic> toGraphQLVars() => {
    'checkpoint_timestamp': timestamp.toUtc().toIso8601String(),
    'checkpoint_event_id': eventId,
  };
}

/// Result of syncCollection query.
class SyncCollectionResult {
  const SyncCollectionResult({
    required this.events,
    required this.serverTime,
    this.nextCheckpoint,
  });

  factory SyncCollectionResult.fromJson(Map<String, dynamic> json) {
    final items =
        (json['events'] as List?)
            ?.whereType<Map<Object?, Object?>>()
            .map((e) => TokenEvent.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const <TokenEvent>[];
    final next = json['next_checkpoint'] as Map<String, dynamic>?;
    return SyncCollectionResult(
      events: items,
      nextCheckpoint: next != null ? SyncCheckpoint.fromJson(next) : null,
      serverTime:
          DateTime.tryParse(json['server_time'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final List<TokenEvent> events;
  final SyncCheckpoint? nextCheckpoint;
  final DateTime serverTime;
}

/// Request for syncCollection query.
/// [checkpoint] is required; construct a default when none saved.
class QuerySyncCollectionRequest {
  const QuerySyncCollectionRequest({
    required this.address,
    required this.checkpoint,
    this.limit = 255,
  });

  final String address;
  final SyncCheckpoint checkpoint;
  final int limit;

  /// Serialize to GraphQL variables.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'address': address,
      'limit': limit.clamp(1, 255),
      ...checkpoint.toGraphQLVars(),
    };
  }
}
