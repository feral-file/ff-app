//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:app/domain/extensions/list_ext.dart';
import 'package:app/domain/models/models.dart';

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

  /// Convert the string to title case.
  String toTitleCase() {
    return split(' ')
        .map(
          (word) => word.isNotEmpty
              ? word[0].toUpperCase() + word.substring(1).toLowerCase()
              : '',
        )
        .join(' ');
  }
}

/// Extension methods for String
extension FF1DeviceExtension on String {
  /// Convert the string to a FF1DeviceInfo
  FF1DeviceInfo get toFF1DeviceInfo {
    final encodedPath = Uri.decodeFull(this);
    final data = encodedPath.split('|');
    if (data.length <= 1) {
      return FF1DeviceInfo(
        deviceId: 'FF1',
        topicId: data.atIndexOrNull(0) ?? '',
        isConnectedToInternet: false,
        branchName: 'release',
        version: '1.0.0', // default version
      );
    }

    return FF1DeviceInfo(
      deviceId: data.atIndexOrNull(0) ?? 'FF1',
      topicId: data.atIndexOrNull(1) ?? '',
      isConnectedToInternet: data.atIndexOrNull(2) == 'true',
      branchName: data.atIndexOrNull(3) ?? 'release',
      version: data.atIndexOrNull(4) ?? '',
    );
  }
}
