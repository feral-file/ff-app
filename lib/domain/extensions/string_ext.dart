//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

/// Extension methods for String
extension StringExtension on String {
  /// Mask the string with the given number of characters
  String mask(int number) {
    if (isEmpty) {
      return '[]';
    } else if (length <= number) {
      return this;
    }
    return maskOnly(number);
  }

  /// Mask the string with the given number of characters only
  String maskOnly(int number) {
    if (isEmpty) {
      return '';
    } else if (length <= number) {
      return this;
    }
    return '${substring(0, number)}...${substring(length - number, length)}';
  }

  /// Mask the string if it contains a space or is longer than 36 characters
  String maskIfNeeded() {
    if (contains(' ')) {
      return this;
    }
    return (length >= 36) ? mask(4) : this;
  }

  /// Shorten address for display (0x1234...5678).
  String shortenAddress() {
    if (length <= 10) {
      return this;
    }
    return '${substring(0, 6)}...${substring(length - 4, length)}';
  }
}
