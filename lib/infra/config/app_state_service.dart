import 'package:app/domain/extensions/extensions.dart';
import 'package:app/domain/models/indexer/sync_collection.dart';
import 'package:app/domain/models/wallet_address.dart';
import 'package:app/domain/utils/address_deduplication.dart';
import 'package:app/infra/database/objectbox_init.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/objectbox.g.dart'
    show AppStateAddressEntity_, AppStateEntity_, TrackedAddressEntity_;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:objectbox/objectbox.dart';
import 'package:synchronized/synchronized.dart';

/// Runtime/persisted state for per-address indexing process.
enum AddressIndexingProcessState {
  /// No active indexing process.
  idle,

  /// Indexing job has been submitted to indexer service.
  indexingTriggered,

  /// Waiting for indexer workflow completion.
  waitingForIndexStatus,

  /// Syncing token pages from indexer into local SQLite playlists.
  syncingTokens,

  /// Process paused by user/system.
  paused,

  /// Process explicitly stopped.
  stopped,

  /// Process finished successfully.
  completed,

  /// Process failed.
  failed,
}

/// Persistable status for per-address indexing process.
class AddressIndexingProcessStatus {
  factory AddressIndexingProcessStatus.idle() => AddressIndexingProcessStatus._(
    state: AddressIndexingProcessState.idle,
    updatedAt: DateTime.now().toUtc(),
  );

  factory AddressIndexingProcessStatus.indexingTriggered({
    required String workflowId,
  }) => AddressIndexingProcessStatus._(
    state: AddressIndexingProcessState.indexingTriggered,
    updatedAt: DateTime.now().toUtc(),
    workflowId: workflowId,
  );

  /// For recovery flows where workflowId is not yet known.
  factory AddressIndexingProcessStatus.indexingTriggeredPending() =>
      AddressIndexingProcessStatus._(
        state: AddressIndexingProcessState.indexingTriggered,
        updatedAt: DateTime.now().toUtc(),
      );

  factory AddressIndexingProcessStatus.waitingForIndexStatus() =>
      AddressIndexingProcessStatus._(
        state: AddressIndexingProcessState.waitingForIndexStatus,
        updatedAt: DateTime.now().toUtc(),
      );

  factory AddressIndexingProcessStatus.syncingTokens() =>
      AddressIndexingProcessStatus._(
        state: AddressIndexingProcessState.syncingTokens,
        updatedAt: DateTime.now().toUtc(),
      );

  factory AddressIndexingProcessStatus.paused() =>
      AddressIndexingProcessStatus._(
        state: AddressIndexingProcessState.paused,
        updatedAt: DateTime.now().toUtc(),
      );

  factory AddressIndexingProcessStatus.stopped() =>
      AddressIndexingProcessStatus._(
        state: AddressIndexingProcessState.stopped,
        updatedAt: DateTime.now().toUtc(),
      );

  factory AddressIndexingProcessStatus.completed() =>
      AddressIndexingProcessStatus._(
        state: AddressIndexingProcessState.completed,
        updatedAt: DateTime.now().toUtc(),
      );

  factory AddressIndexingProcessStatus.failed({String? errorMessage}) =>
      AddressIndexingProcessStatus._(
        state: AddressIndexingProcessState.failed,
        updatedAt: DateTime.now().toUtc(),
        errorMessage: errorMessage,
      );
  const AddressIndexingProcessStatus._({
    required this.state,
    required this.updatedAt,
    this.workflowId,
    this.errorMessage,
  });

  final AddressIndexingProcessState state;
  final DateTime updatedAt;
  final String? workflowId;
  final String? errorMessage;
}

/// Abstract contract for app-level and per-address state services.
///
/// Declares the public API only; implementations live in [AppStateService].
abstract class AppStateServiceBase {
  Future<bool> hasSeenOnboarding();
  Future<void> setHasSeenOnboarding({required bool hasSeen});
  Future<bool> hasSeenPlayToFf1Tooltip();
  Future<void> setHasSeenPlayToFf1Tooltip({required bool hasSeen});
  Future<bool> hasCompletedSeedDownload();
  Future<void> setHasCompletedSeedDownload({required bool completed});
  Future<SyncCheckpoint?> getAddressCheckpoint(String address);
  Future<void> setAddressCheckpoint({
    required String address,
    required SyncCheckpoint checkpoint,
  });
  Future<void> clearAddressCheckpoint(String address);
  Future<List<String>> getAddressesWithCompletedIndexing();
  Stream<AddressIndexingProcessStatus?> watchAddressIndexingStatus(
    String address,
  );
  Future<void> setAddressIndexingStatus({
    required String address,
    required AddressIndexingProcessStatus status,
  });

  /// Adds address to tracked list (with optional alias) and ensures
  /// [AppStateAddressEntity] exists. Call before setAddressIndexingStatus.
  Future<void> addTrackedAddress(String address, {String alias = ''});
  Future<void> clearAddressState(String address);
  Future<Map<String, AddressIndexingProcessStatus>>
  getAllAddressIndexingStatuses();
  Future<void> trackPersonalAddress(String address);
  Future<List<String>> getTrackedPersonalAddresses();
  Future<List<WalletAddress>> getTrackedWalletAddresses();
}

/// Single typed state service for app-level + per-address local state.
///
/// This service intentionally stores only non-SQLite state. Address ownership
/// and token/playlist content remain source-of-truth in SQLite.
class AppStateService extends AppStateServiceBase {
  AppStateService({
    required Store store,
    required Box<AppStateEntity> appStateBox,
    required Box<AppStateAddressEntity> appStateAddressBox,
    required Box<TrackedAddressEntity> trackedAddressBox,
    Logger? logger,
  }) : _store = store,
       _appStateBox = appStateBox,
       _appStateAddressBox = appStateAddressBox,
       _trackedAddressBox = trackedAddressBox,
       _log = logger ?? Logger('AppStateService');

  static const _scope = 'app';

  final Store _store;
  final Box<AppStateEntity> _appStateBox;
  final Box<AppStateAddressEntity> _appStateAddressBox;
  final Box<TrackedAddressEntity> _trackedAddressBox;
  final Logger _log;
  final Lock _lock = Lock();

  AppStateEntity _getOrCreateSingleton() {
    final query = _appStateBox
        .query(AppStateEntity_.scope.equals(_scope))
        .build();
    final existing = query.findFirst();
    query.close();
    if (existing != null) {
      return existing;
    }
    final created = AppStateEntity(
      updatedAtUs: DateTime.now().toUtc().microsecondsSinceEpoch,
    );
    created.id = _appStateBox.put(created);
    return created;
  }

  /// Row key: normalized address.
  AppStateAddressEntity? _findAddressState(String rowKey) {
    final query = _appStateAddressBox
        .query(AppStateAddressEntity_.normalizedAddress.equals(rowKey))
        .build();
    final existing = query.findFirst();
    query.close();
    return existing;
  }

  /// Creates a new [AppStateAddressEntity]. Use when we know it does not exist
  /// yet (e.g. when adding a tracked address).
  AppStateAddressEntity _createAddressState(String rowKey) {
    final nowUs = DateTime.now().toUtc().microsecondsSinceEpoch;
    final created = AppStateAddressEntity(
      normalizedAddress: rowKey,
      updatedAtUs: nowUs,
    );
    created.id = _appStateAddressBox.put(created);
    return created;
  }

  TrackedAddressEntity? _findTrackedAddress(String normalizedAddress) {
    final query = _trackedAddressBox
        .query(
          TrackedAddressEntity_.normalizedAddress.equals(normalizedAddress),
        )
        .build();
    final existing = query.findFirst();
    query.close();
    return existing;
  }

  String _normalizeAddressKey(String address) => address.toNormalizedAddress();

  DateTime _fromUs(int us, {required DateTime fallback}) {
    if (us <= 0) {
      return fallback;
    }
    return DateTime.fromMicrosecondsSinceEpoch(us, isUtc: true);
  }

  AddressIndexingProcessStatus _toProcessStatus(AppStateAddressEntity entity) {
    final state =
        entity.indexingProcessStateIndex >= 0 &&
            entity.indexingProcessStateIndex <
                AddressIndexingProcessState.values.length
        ? AddressIndexingProcessState.values[entity.indexingProcessStateIndex]
        : AddressIndexingProcessState.idle;
    final updatedAt = _fromUs(
      entity.indexingProcessUpdatedAtUs,
      fallback: DateTime.now().toUtc(),
    );
    final errorMessage = entity.indexingProcessErrorMessage.trim().isEmpty
        ? null
        : entity.indexingProcessErrorMessage;
    final workflowId = entity.indexingProcessWorkflowId.trim().isEmpty
        ? null
        : entity.indexingProcessWorkflowId;
    return AddressIndexingProcessStatus._(
      state: state,
      updatedAt: updatedAt,
      errorMessage: errorMessage,
      workflowId: workflowId,
    );
  }

  /// Whether user completed onboarding.
  @override
  Future<bool> hasSeenOnboarding() async {
    return _lock.synchronized(() {
      return false;
      return _getOrCreateSingleton().hasSeenOnboarding;
    });
  }

  /// Persist onboarding completion.
  @override
  Future<void> setHasSeenOnboarding({required bool hasSeen}) async {
    await _lock.synchronized(() async {
      final app = _getOrCreateSingleton()
        ..hasSeenOnboarding = hasSeen
        ..updatedAtUs = DateTime.now().toUtc().microsecondsSinceEpoch;
      _appStateBox.put(app);
    });
  }

  /// Whether user already saw the Play-to-FF1 tooltip.
  @override
  Future<bool> hasSeenPlayToFf1Tooltip() async {
    return _lock.synchronized(() {
      return _getOrCreateSingleton().hasSeenPlayToFf1Tooltip;
    });
  }

  /// Persist Play-to-FF1 tooltip seen state.
  @override
  Future<void> setHasSeenPlayToFf1Tooltip({required bool hasSeen}) async {
    await _lock.synchronized(() async {
      final app = _getOrCreateSingleton()
        ..hasSeenPlayToFf1Tooltip = hasSeen
        ..updatedAtUs = DateTime.now().toUtc().microsecondsSinceEpoch;
      _appStateBox.put(app);
    });
  }

  /// Whether user has completed at least one seed database download.
  @override
  Future<bool> hasCompletedSeedDownload() async {
    return _lock.synchronized(() {
      return _getOrCreateSingleton().hasCompletedSeedDownload;
    });
  }

  /// Persist seed download completion. When true, subsequent syncs run in background.
  @override
  Future<void> setHasCompletedSeedDownload({required bool completed}) async {
    await _lock.synchronized(() async {
      final app = _getOrCreateSingleton()
        ..hasCompletedSeedDownload = completed
        ..updatedAtUs = DateTime.now().toUtc().microsecondsSinceEpoch;
      _appStateBox.put(app);
    });
  }

  /// Get syncCollection checkpoint for an address.
  @override
  Future<SyncCheckpoint?> getAddressCheckpoint(String address) async {
    return _lock.synchronized(() {
      final row = _findAddressState(_normalizeAddressKey(address));
      if (row == null || !row.hasCheckpoint) {
        final fallbackTimestamp = DateTime.fromMicrosecondsSinceEpoch(
          row?.updatedAtUs ?? 0,
          isUtc: true,
        );
        return SyncCheckpoint(eventId: 0, timestamp: fallbackTimestamp);
      }
      return SyncCheckpoint(
        timestamp: _fromUs(
          row.checkpointTimestampUs,
          fallback: DateTime.now().toUtc(),
        ),
        eventId: row.checkpointEventId,
      );
    });
  }

  /// Persist syncCollection checkpoint for an address.
  @override
  Future<void> setAddressCheckpoint({
    required String address,
    required SyncCheckpoint checkpoint,
  }) async {
    await _lock.synchronized(() async {
      final normalized = _normalizeAddressKey(address);
      var row = _findAddressState(normalized);
      row ??= _createAddressState(normalized);
      row
        ..hasCheckpoint = true
        ..checkpointTimestampUs = checkpoint.timestamp
            .toUtc()
            .microsecondsSinceEpoch
        ..checkpointEventId = checkpoint.eventId
        ..updatedAtUs = DateTime.now().toUtc().microsecondsSinceEpoch;
      _appStateAddressBox.put(row);
    });
  }

  /// Remove syncCollection checkpoint for an address.
  @override
  Future<void> clearAddressCheckpoint(String address) async {
    await _lock.synchronized(() async {
      final row = _findAddressState(_normalizeAddressKey(address));
      if (row == null) {
        return;
      }
      row
        ..hasCheckpoint = false
        ..checkpointTimestampUs = 0
        ..checkpointEventId = 0;
      _appStateAddressBox.put(row);
    });
  }

  /// Returns addresses with indexing status completed (ready for syncCollection).
  @override
  Future<List<String>> getAddressesWithCompletedIndexing() async {
    return _lock.synchronized(() {
      final result = <String>[];
      for (final row in _appStateAddressBox.getAll()) {
        if (row.normalizedAddress.startsWith('FEED::')) {
          continue;
        }
        if (row.indexingProcessUpdatedAtUs <= 0) {
          continue;
        }
        final status = _toProcessStatus(row);
        if (status.state == AddressIndexingProcessState.completed) {
          result.add(row.normalizedAddress);
        }
      }
      return result;
    });
  }

  Future<AddressIndexingProcessStatus?> _getAddressIndexingStatus(
    String address,
  ) async {
    return _lock.synchronized(() async {
      final row = _findAddressState(_normalizeAddressKey(address));
      if (row == null || row.indexingProcessUpdatedAtUs <= 0) {
        return null;
      }
      return _toProcessStatus(row);
    });
  }

  /// Stream of per-address indexing process status; emits when ObjectBox changes.
  ///
  /// Use instead of [getAddressIndexingStatus] when you need reactive updates
  /// without manual invalidation. Any [setAddressIndexingStatus] triggers emit.
  @override
  Stream<AddressIndexingProcessStatus?> watchAddressIndexingStatus(
    String address,
  ) async* {
    yield await _getAddressIndexingStatus(address);
    await for (final _ in _store.watch<AppStateAddressEntity>()) {
      yield await _getAddressIndexingStatus(address);
    }
  }

  /// Persist per-address indexing process status.
  @override
  Future<void> setAddressIndexingStatus({
    required String address,
    required AddressIndexingProcessStatus status,
  }) async {
    final normalizedAddress = _normalizeAddressKey(address);
    await _lock.synchronized(() async {
      var row = _findAddressState(normalizedAddress);
      row ??= _createAddressState(normalizedAddress);
      row
        ..indexingProcessStateIndex = status.state.index
        ..indexingProcessUpdatedAtUs = status.updatedAt
            .toUtc()
            .microsecondsSinceEpoch
        ..indexingProcessErrorMessage = status.errorMessage ?? ''
        ..indexingProcessWorkflowId = status.workflowId ?? ''
        ..updatedAtUs = DateTime.now().toUtc().microsecondsSinceEpoch;
      _appStateAddressBox.put(row);
    });
    _log.info('Set address indexing status for $address: ${status.state}');
  }

  @override
  Future<void> addTrackedAddress(String address, {String alias = ''}) async {
    final normalized = _normalizeAddressKey(address);
    if (normalized.isEmpty || normalized.startsWith('FEED::')) {
      return;
    }
    await _lock.synchronized(() async {
      final existing = _findTrackedAddress(normalized);
      if (existing != null) {
        return;
      }
      final nowUs = DateTime.now().toUtc().microsecondsSinceEpoch;
      final entity = TrackedAddressEntity(
        normalizedAddress: normalized,
        alias: alias,
        createdAtUs: nowUs,
      );
      entity.id = _trackedAddressBox.put(entity);
      // Create AppStateAddressEntity (1:1 with tracked address). New address,
      // so state does not exist yet.
      _createAddressState(normalized);
    });
  }

  /// Remove all app-state row data for a specific address key.
  @override
  Future<void> clearAddressState(String address) async {
    await _lock.synchronized(() async {
      final normalized = _normalizeAddressKey(address);
      final tracked = _findTrackedAddress(normalized);
      if (tracked != null) {
        _trackedAddressBox.remove(tracked.id);
      }
      final row = _findAddressState(normalized);
      if (row != null) {
        _appStateAddressBox.remove(row.id);
      }
    });
  }

  /// Returns all persisted indexing statuses keyed by normalized address.
  @override
  Future<Map<String, AddressIndexingProcessStatus>>
  getAllAddressIndexingStatuses() async {
    return _lock.synchronized(() {
      final result = <String, AddressIndexingProcessStatus>{};
      for (final row in _appStateAddressBox.getAll()) {
        if (row.normalizedAddress.startsWith('FEED::')) {
          continue;
        }
        if (row.indexingProcessUpdatedAtUs <= 0) {
          continue;
        }
        result[row.normalizedAddress] = _toProcessStatus(row);
      }
      return result;
    });
  }

  @override
  Future<void> trackPersonalAddress(String address) async {
    await addTrackedAddress(address);
  }

  @override
  Future<List<String>> getTrackedPersonalAddresses() async {
    return _lock.synchronized(() {
      final addresses = _trackedAddressBox
          .getAll()
          .map((row) => row.normalizedAddress)
          .toSet()
          .toList();
      addresses.sort();
      return addresses;
    });
  }

  @override
  Future<List<WalletAddress>> getTrackedWalletAddresses() async {
    return _lock.synchronized(() {
      return _trackedEntitiesToWalletAddresses(_trackedAddressBox.getAll());
    });
  }

  /// Stream of tracked addresses as [WalletAddress] for UI (e.g. onboarding).
  ///
  /// Watches [TrackedAddressEntity]; emits when the tracked-address list
  /// changes.
  Stream<List<WalletAddress>> watchTrackedAddressesAsWalletAddresses() async* {
    yield _trackedEntitiesToWalletAddresses(_trackedAddressBox.getAll());
    await for (final _ in _store.watch<TrackedAddressEntity>()) {
      yield _trackedEntitiesToWalletAddresses(_trackedAddressBox.getAll());
    }
  }

  List<WalletAddress> _trackedEntitiesToWalletAddresses(
    List<TrackedAddressEntity> entities,
  ) {
    final list = <WalletAddress>[];
    for (final row in entities) {
      final name = row.alias.trim().isNotEmpty
          ? row.alias
          : row.normalizedAddress.shortenAddress();
      list.add(
        WalletAddress(
          address: row.normalizedAddress,
          name: name,
          createdAt: DateTime.fromMicrosecondsSinceEpoch(
            row.createdAtUs,
            isUtc: true,
          ),
        ),
      );
    }
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }
}

/// Single provider for typed local app state.
final appStateServiceProvider = Provider<AppStateService>((ref) {
  final store = getInitializedObjectBoxStore();
  return AppStateService(
    store: store,
    appStateBox: store.box<AppStateEntity>(),
    appStateAddressBox: store.box<AppStateAddressEntity>(),
    trackedAddressBox: store.box<TrackedAddressEntity>(),
    logger: Logger('AppStateService'),
  );
});

/// Provider that reads added addresses from SQLite source of truth.
final addedAddressesProvider = FutureProvider<List<String>>((ref) async {
  final appStateService = ref.watch(appStateServiceProvider);
  return appStateService.getTrackedPersonalAddresses();
});
