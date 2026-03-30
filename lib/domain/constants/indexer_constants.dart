//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

// ignore_for_file: public_member_api_docs // Reason: copied from the legacy mobile app to keep the DP-1 dynamic query surface stable.

/// Default `limit` for indexer **list-tokens** queries (owners / address pages).
///
/// The indexer schema uses `Uint8` for `limit`, so this must stay ≤ 255.
/// Used when `limit` is omitted on list-tokens fetches and by services that
/// page tokens by owner (indexer service, address sync ingest, personal token
/// sync).
///
/// Pagination contract: completion is indicated by `nextOffset == null` in the
/// response, not by comparing returned row count to this page size. Personal
/// token catch-up persists the next offset in app state so restarts resume from
/// the indexer cursor (which may differ from playlist `itemCount`). See
/// `.cursor/rules/50-indexing-address-flow.mdc` and `docs/app_flows.md`.
const indexerTokensPageSize = 255;

enum IndexerAssetTokenSortBy {
  lastActivityTime,
  createdTime
  ;

  String toJson() {
    switch (this) {
      case IndexerAssetTokenSortBy.lastActivityTime:
        return 'lastActivityTime';
      case IndexerAssetTokenSortBy.createdTime:
        return 'createdTime';
    }
  }
}
