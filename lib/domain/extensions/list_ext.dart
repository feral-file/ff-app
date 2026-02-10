//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

/// Extension methods for List
extension NullableListExtensions<T> on List<T>? {
  /// Get the element at the given index or null if the list is null or the index is out of bounds
  T? atIndexOrNull(int index) {
    if (this == null || index < 0 || index >= this!.length) {
      return null;
    }
    return this![index];
  }
}
