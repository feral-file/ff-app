import 'dart:async';

import 'package:app/app/providers/bootstrap_provider.dart';
import 'package:app/app/providers/remote_config_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/routing/router_provider.dart';
import 'package:app/domain/models/wallet_address.dart';
import 'package:app/infra/config/feed_config_store.dart';
import 'package:app/infra/config/indexer_config_store.dart';
import 'package:app/infra/database/app_database.dart';
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
    await _recoverFromDatabaseResetIfNeeded();

    final bootstrap = ref.read(bootstrapProvider.notifier);
    await bootstrap.bootstrap();

    final changed = await ref
        .read(remoteAppConfigProvider.notifier)
        .refreshInBackground();
    if (changed) {
      await bootstrap.bootstrap();
    }
  }

  Future<void> _recoverFromDatabaseResetIfNeeded() async {
    final requiresReindex = await consumeDatabaseResetReindexMarker();
    if (!requiresReindex) {
      return;
    }

    final feedConfigStore = ref.read(feedConfigStoreProvider);
    final indexerConfigStore = ref.read(indexerConfigStoreProvider);

    // Force feed side to reload from scratch.
    await feedConfigStore.clearSyncStages();
    await feedConfigStore.setLastTimeRefreshFeeds(DateTime(1970));

    // Read known addresses from local state stores.
    final statusMap = await feedConfigStore.getAllAddressIndexingStatuses();
    final trackedAddresses = await indexerConfigStore.getTrackedAddresses();
    final addresses = <String>{
      ...statusMap.keys.map((a) => a.toUpperCase()),
      ...trackedAddresses,
    }.toList(growable: false);

    if (addresses.isEmpty) {
      return;
    }

    final addressService = ref.read(addressServiceProvider);

    for (final address in addresses) {
      // Reset indexer progress so sync starts from the beginning.
      await indexerConfigStore.removeAnchor(address);
      await indexerConfigStore.removeIndexingInfo(address);
      await indexerConfigStore.removeLastFetchTokenTime(address);

      await feedConfigStore.setAddressIndexingStatus(
        address: address,
        status: AddressIndexingProcessStatus(
          state: AddressIndexingProcessState.indexingTriggered,
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      await addressService.addAddress(
        walletAddress: WalletAddress(
          address: address,
          createdAt: DateTime.now(),
          name: _shortAddress(address),
        ),
      );
    }
  }

  String _shortAddress(String address) {
    if (address.length <= 10) {
      return address;
    }
    return '${address.substring(0, 6)}...'
        '${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
