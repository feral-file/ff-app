import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/app/routing/router_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root application widget.
/// Consumes the router provider to configure navigation.
class App extends ConsumerWidget {
  /// Creates the root App widget.
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDoneOnboarding = ref.read(hasDoneOnboardingProvider);

    return hasDoneOnboarding.maybeWhen(
      data: (hasDone) {
        final router = ref.watch(
          routerProvider(
              hasDone ? Routes.home : Routes.onboardingIntroducePage),
        );

        return MaterialApp.router(
          title: 'Feral File',
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
        );
      },
      orElse: Container.new,
    );
  }
}
