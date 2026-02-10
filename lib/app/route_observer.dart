import 'package:flutter/material.dart';

/// Route observer for Navigator lifecycle (e.g. used by VideoNFTRenderingWidget
/// to pause/resume when leaving/returning to work detail screen).
/// Registered in GoRouter(observers: [routeObserver]).
final routeObserver = RouteObserver<ModalRoute<void>>();
