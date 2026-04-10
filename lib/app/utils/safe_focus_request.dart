//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Upper bound on deferred focus attempts to avoid unbounded frame callbacks if
/// layout never settles (e.g. widget removed).
const _kMaxFocusLayoutAttempts = 16;

/// Requests [focusNode] focus only when the owning route is current and the
/// focus target has a laid-out [RenderBox].
///
/// A single post-frame [FocusNode.requestFocus] can run during route or app
/// lifecycle churn before [RenderEditable] finishes layout, which crashes
/// when the IME reads size/transform (see issue #357 / FF-APP-6J).
void scheduleRequestFocusWhenLaidOut({
  required FocusNode focusNode,
  required BuildContext ownerContext,
}) {
  var attempts = 0;

  void tryFocus() {
    attempts++;
    if (attempts > _kMaxFocusLayoutAttempts) {
      return;
    }
    if (!ownerContext.mounted) {
      return;
    }
    if (!focusNode.canRequestFocus) {
      return;
    }

    final route = ModalRoute.of(ownerContext);
    if (route != null && !route.isCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) => tryFocus());
      return;
    }

    final focusContext = focusNode.context;
    if (focusContext == null || !focusContext.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => tryFocus());
      return;
    }

    final renderObject = focusContext.findRenderObject();
    if (renderObject is RenderBox &&
        renderObject.attached &&
        renderObject.hasSize) {
      focusNode.requestFocus();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => tryFocus());
  }

  // Call from a post-frame callback after [State.context] is valid (e.g.
  // `addPostFrameCallback` from `initState`).
  tryFocus();
}

/// Runs [action] on the next frame if [context] is still mounted.
///
/// Defers `go_router` navigation triggered from Riverpod listeners so it does
/// not interleave with focus or route transition work in the same frame.
void schedulePostFrameIfMounted(
  BuildContext context,
  VoidCallback action,
) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) {
      action();
    }
  });
}
