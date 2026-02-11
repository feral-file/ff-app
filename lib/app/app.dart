import 'dart:async';

import 'package:app/app/providers/bootstrap_provider.dart';
import 'package:app/app/providers/remote_config_provider.dart';
import 'package:app/app/routing/router_provider.dart';
import 'package:app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root application widget.
/// Consumes the router provider to configure navigation.
class App extends ConsumerWidget {
  /// Creates the root App widget.
  const App({
    required this.initialLocation,
    super.key,
  });

  /// Initial location for the app router.
  final String initialLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(
      routerProvider(initialLocation),
    );

    return MaterialApp.router(
      title: 'Feral File',
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      builder: (context, child) {
        return _AppStartupBootstrap(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _AppStartupBootstrap extends ConsumerStatefulWidget {
  const _AppStartupBootstrap({
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<_AppStartupBootstrap> createState() =>
      _AppStartupBootstrapState();
}

class _AppStartupBootstrapState extends ConsumerState<_AppStartupBootstrap> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_started) {
        return;
      }
      _started = true;
      unawaited(_bootstrapAtAppStart());
    });
  }

  Future<void> _bootstrapAtAppStart() async {
    final bootstrap = ref.read(bootstrapProvider.notifier);
    await bootstrap.bootstrap();

    final changed = await ref
        .read(remoteAppConfigProvider.notifier)
        .refreshInBackground();
    if (changed) {
      await bootstrap.bootstrap();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
