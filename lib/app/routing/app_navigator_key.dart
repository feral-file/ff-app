import 'package:flutter/material.dart';

/// App-wide [GlobalKey] for the root [Navigator].
///
/// Assigned to `GoRouter.navigatorKey` so that services in the infra layer
/// can resolve the current [BuildContext] without receiving it as a parameter.
/// Always guard `appNavigatorKey.currentContext` with a `null` and `mounted`
/// check before any widget interaction.
final appNavigatorKey = GlobalKey<NavigatorState>();
