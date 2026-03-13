// ignore_for_file: public_member_api_docs // Reason: provider orchestration state.

import 'dart:async';

import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

class TokensSyncState {
  const TokensSyncState({
    this.syncingAddresses = const <String>{},
    this.lastSyncCompleted,
    this.errorMessage,
  });

  final Set<String> syncingAddresses;
  final DateTime? lastSyncCompleted;
  final String? errorMessage;

  TokensSyncState copyWith({
    Set<String>? syncingAddresses,
    DateTime? lastSyncCompleted,
    String? errorMessage,
  }) {
    return TokensSyncState(
      syncingAddresses: syncingAddresses ?? this.syncingAddresses,
      lastSyncCompleted: lastSyncCompleted ?? this.lastSyncCompleted,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class TokensSyncCoordinatorNotifier extends Notifier<TokensSyncState> {
  final Logger _log = Logger('TokensSyncCoordinator');
  Timer? _pollTimer;
  bool _isStoppingForReset = false;
  Completer<void>? _currentSyncCompleter;

  @override
  TokensSyncState build() {
    _isStoppingForReset = false;
    ref.onDispose(() {
      _pollTimer?.cancel();
    });
    return const TokensSyncState();
  }

  void startPolling({Duration interval = const Duration(minutes: 5)}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) {
      unawaited(syncAllTrackedAddresses());
    });
    _log.info('Started polling at interval=$interval');
  }

  void pausePolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void resumePolling() {
    if (_pollTimer != null) return;
    startPolling();
  }

  Future<void> pollAllAddressesOnce() => syncAllTrackedAddresses();

  Future<void> syncAllTrackedAddresses() async {
    if (_isStoppingForReset) return;
    if (!ref.read(isSeedDatabaseReadyProvider)) return;
    final appState = ref.read(appStateServiceProvider);
    final addresses = await appState.getTrackedPersonalAddresses();
    if (addresses.isEmpty) return;
    await syncAddresses(addresses);
  }

  Future<void> syncAddresses(List<String> addresses) async {
    if (_isStoppingForReset || addresses.isEmpty) return;
    if (!ref.read(isSeedDatabaseReadyProvider)) return;

    final completer = Completer<void>();
    _currentSyncCompleter = completer;
    try {
      await _syncAddressesImpl(addresses);
    } finally {
      if (!completer.isCompleted) completer.complete();
      if (_currentSyncCompleter == completer) _currentSyncCompleter = null;
    }
  }

  Future<void> _syncAddressesImpl(List<String> addresses) async {
    if (_isStoppingForReset || addresses.isEmpty) return;

    final byKey = <String, String>{};
    for (final address in addresses) {
      final trimmed = address.trim();
      if (trimmed.isEmpty) continue;
      byKey.putIfAbsent(trimmed.toUpperCase(), () => trimmed);
    }
    final normalized = byKey.values.toList(growable: false);
    if (normalized.isEmpty) return;

    state = state.copyWith(
      syncingAddresses: {...state.syncingAddresses, ...normalized},
    );

    try {
      final service = ref.read(personalTokensSyncServiceProvider);
      await service.syncAddresses(addresses: normalized);
      final remaining = {...state.syncingAddresses}..removeAll(normalized);
      if (ref.mounted) {
        state = state.copyWith(
          syncingAddresses: remaining,
          lastSyncCompleted: DateTime.now(),
        );
      }
    } on Object catch (e) {
      final remaining = {...state.syncingAddresses}..removeAll(normalized);
      if (ref.mounted) {
        state = state.copyWith(
          syncingAddresses: remaining,
          errorMessage: e.toString(),
        );
      }
      rethrow;
    }
  }

  Future<void> reindexAddresses(List<String> addresses) async {
    if (_isStoppingForReset || addresses.isEmpty) return;
    final appState = ref.read(appStateServiceProvider);
    for (final address in addresses) {
      await appState.trackPersonalAddress(address);
    }
    await syncAddresses(addresses);
  }

  Future<void> notifyChannelIngested() async {
    return;
  }

  /// Stops polling and waits for any in-flight sync to complete.
  /// Must complete before database is closed (e.g. rebuildMetadata, forgetIExist).
  Future<void> stopAndDrainForReset() async {
    _isStoppingForReset = true;
    pausePolling();
    if (ref.mounted) {
      state = const TokensSyncState();
    }
    // Await in-flight sync so it releases DB connections before close.
    final completer = _currentSyncCompleter;
    if (completer != null) {
      _log.info('stopAndDrainForReset: waiting for in-flight sync');
      await completer.future;
      _log.info('stopAndDrainForReset: in-flight sync completed');
    }
  }
}

final tokensSyncCoordinatorProvider =
    NotifierProvider<TokensSyncCoordinatorNotifier, TokensSyncState>(
      TokensSyncCoordinatorNotifier.new,
    );
