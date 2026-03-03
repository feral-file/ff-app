//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

// ignore_for_file: public_member_api_docs // Reason: copied from the legacy mobile app to keep the DP-1 dynamic query surface stable.

const indexerTokensPageSize = 50;

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
