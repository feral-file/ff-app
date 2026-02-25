//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:flutter/material.dart';

/// Top right rectangle clipper
class TopRightRectangleClipper extends CustomClipper<Path> {
  /// Constructor
  TopRightRectangleClipper({this.customRadius});

  /// Custom radius
  final double? customRadius;

  @override
  Path getClip(Size size) {
    final radius = customRadius == null ? 14 : customRadius!;

    final path = Path()
      ..lineTo(0, 0)
      ..lineTo(size.width - radius, 0)
      ..lineTo(size.width, radius.toDouble())
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, 0)
      ..close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
