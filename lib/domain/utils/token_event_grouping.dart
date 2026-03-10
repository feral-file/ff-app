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

/// Transfer event types: ownership changes only.
/// Excludes metadata_updated, enrichment_updated, viewability_changed.
bool _isTransferEvent(TokenEvent e) =>
    e.eventType == 'released' || e.eventType == 'acquired';

/// Groups [TokenEvent]s into removal (transferred out) vs updated (kept/refreshed).
///
/// For each tokenId, takes the **last transfer event** (released or acquired),
/// not the last event of any type. Attribute-only events (metadata_updated,
/// enrichment_updated, viewability_changed) do not affect ownership.
///
/// - If last transfer is `released` AND `owner_address == address`: token was
///   transferred out from this address -> removal.
/// - Else (last transfer is `acquired`, or `released` to someone else):
///   token is still owned or was re-acquired -> updated.
///
/// Each token belongs to at most one group (removal xor updated).
///
/// Example: A transfers to B, B back to A. For address A, the last transfer
/// is `acquired` (A received it back), so the token is in updated, not removal.
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

    // Last transfer event (released or acquired) - ignore attribute-only events.
    final transferEvents =
        tokenEvents.where(_isTransferEvent).toList(growable: false);
    if (transferEvents.isEmpty) {
      // No transfer events: treat as updated (e.g. metadata-only changes).
      updatedTokenIds.add(tokenId);
      continue;
    }

    final lastTransfer = transferEvents.last;

    final isReleased = lastTransfer.eventType == 'released';
    final ownerMatches = lastTransfer.ownerAddress?.toNormalizedAddress() ==
        normalizedAddress;

    if (isReleased && ownerMatches) {
      removalTokenIds.add(tokenId);
    } else {
      updatedTokenIds.add(tokenId);
    }
  }

  return TokenEventGroupingResult(
    removalTokenIds: removalTokenIds,
    updatedTokenIds: updatedTokenIds,
  );
}
