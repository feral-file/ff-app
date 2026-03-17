//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:app/domain/models/indexer/sync_collection.dart';
import 'package:app/domain/utils/address_deduplication.dart';

/// Result of grouping token events into removal vs updated.
class TokenEventGroupingResult {
  const TokenEventGroupingResult({
    required this.removalTokenIds,
    required this.updatedTokenIds,
  });

  final Set<int> removalTokenIds;
  final Set<int> updatedTokenIds;
}

/// Extension on [TokenEvent] for event type checks.
extension TokenEventExtension on TokenEvent {
  /// True if event is a transfer (released or acquired).
  /// Excludes metadata_updated, enrichment_updated, viewability_changed.
  bool get isTransferEvent =>
      eventType == 'released' || eventType == 'acquired';

  /// True if event is viewability_changed.
  bool get isTokenViewabilityEvent => eventType == 'viewability_changed';

  /// True if event is released (transfer out).
  bool get isRelease => eventType == 'released';

  /// True if viewability_changed metadata has is_viewable == false.
  bool get isViewableFalse =>
      eventType == 'viewability_changed' &&
      metadata?['is_viewable'] == false;
}

/// Extension on [List<TokenEvent]> for extracting last transfer and viewability events.
extension _TokenEventsListExtension on List<TokenEvent> {
  /// Last transfer event (released or acquired), or null if none.
  TokenEvent? get lastTransferEvent {
    for (var i = length - 1; i >= 0; i--) {
      final e = this[i];
      if (e.isTransferEvent) return e;
    }
    return null;
  }

  /// Last viewability_changed event, or null if none.
  TokenEvent? get lastTokenViewabilityEvent {
    for (var i = length - 1; i >= 0; i--) {
      final e = this[i];
      if (e.isTokenViewabilityEvent) return e;
    }
    return null;
  }
}

/// Groups [TokenEvent]s into removal (transferred out or hidden) vs updated (kept/refreshed).
///
/// For each tokenId:
/// - If last transfer is `released` AND `owner_address == address`: removal.
/// - Else if last viewability event has `metadata.is_viewable == false`: removal.
/// - Else: updated.
///
/// Each token belongs to at most one group (removal xor updated).
TokenEventGroupingResult groupTokenEvents({
  required List<TokenEvent> events,
  required String address,
}) {
  final normalizedAddress = address.toNormalizedAddress();
  final removalTokenIds = <int>{};
  final updatedTokenIds = <int>{};

  if (events.isEmpty) {
    return TokenEventGroupingResult(
      removalTokenIds: removalTokenIds,
      updatedTokenIds: updatedTokenIds,
    );
  }

  // Group by tokenId, keep events in order (already chronological from indexer).
  final byTokenId = <int, List<TokenEvent>>{};
  for (final e in events) {
    byTokenId.putIfAbsent(e.tokenId, () => []).add(e);
  }

  for (final entry in byTokenId.entries) {
    final tokenId = entry.key;
    final tokenEvents = entry.value;
    if (tokenEvents.isEmpty) continue;

    final lastTransfer = tokenEvents.lastTransferEvent;
    if (lastTransfer != null) {
      final ownerMatches =
          lastTransfer.ownerAddress?.toNormalizedAddress() == normalizedAddress;
      if (lastTransfer.isRelease && ownerMatches) {
        removalTokenIds.add(tokenId);
        continue;
      }
    }

    final lastViewability = tokenEvents.lastTokenViewabilityEvent;
    if (lastViewability != null && lastViewability.isViewableFalse) {
      removalTokenIds.add(tokenId);
      continue;
    }

    updatedTokenIds.add(tokenId);
  }

  return TokenEventGroupingResult(
    removalTokenIds: removalTokenIds,
    updatedTokenIds: updatedTokenIds,
  );
}
