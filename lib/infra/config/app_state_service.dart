import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/objectbox_init.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/objectbox.g.dart'
    show AppStateAddressEntity_, AppStateEntity_;
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
  const AddressIndexingProcessStatus({
    required this.state,
    required this.updatedAt,
    this.errorMessage,
  });

  final AddressIndexingProcessState state;
  final DateTime updatedAt;
  final String? errorMessage;

  AddressIndexingProcessStatus copyWith({
    AddressIndexingProcessState? state,
    DateTime? updatedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AddressIndexingProcessStatus(
      state: state ?? this.state,
      updatedAt: updatedAt ?? this.updatedAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Single typed state service for app-level + per-address local state.
///
/// This service intentionally stores only non-SQLite state. Address ownership
/// and token/playlist content remain source-of-truth in SQLite.
class AppStateService {
  AppStateService({
    required Box<AppStateEntity> appStateBox,
    required Box<AppStateAddressEntity> appStateAddressBox,
    Logger? logger,
  }) : _appStateBox = appStateBox,
       _appStateAddressBox = appStateAddressBox,
       _log = logger ?? Logger('AppStateService');

  static const _scope = 'app';
  static const _defaultCacheDurationSeconds = 86400;
  static final _defaultLastFeedUpdatedAt = DateTime(2023).toUtc();

  final Box<AppStateEntity> _appStateBox;
  final Box<AppStateAddressEntity> _appStateAddressBox;
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

  AppStateAddressEntity? _findAddressState(String normalizedAddress) {
    final query = _appStateAddressBox
        .query(
          AppStateAddressEntity_.normalizedAddress.equals(normalizedAddress),
        )
        .build();
    final existing = query.findFirst();
    query.close();
    return existing;
  }

  AppStateAddressEntity _getOrCreateAddressState(String normalizedAddress) {
    final existing = _findAddressState(normalizedAddress);
    if (existing != null) {
      return existing;
    }

    final created = AppStateAddressEntity(
      normalizedAddress: normalizedAddress,
      updatedAtUs: DateTime.now().toUtc().microsecondsSinceEpoch,
    );
    created.id = _appStateAddressBox.put(created);
    return created;
  }

  String _normalizeAddressKey(String address) => address.trim().toUpperCase();

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

    return AddressIndexingProcessStatus(
      state: state,
      updatedAt: _fromUs(
        entity.indexingProcessUpdatedAtUs,
        fallback: DateTime.now().toUtc(),
      ),
      errorMessage: entity.indexingProcessErrorMessage.trim().isEmpty
          ? null
          : entity.indexingProcessErrorMessage,
    );
  }

  /// Feed cache refresh timestamp for one feed base URL.
  Future<DateTime> getLastRefreshTime(String baseUrl) async {
    return _lock.synchronized(() {
      final app = _getOrCreateSingleton();
      if (app.globalLastRefreshEpochUs > 0) {
        return DateTime.fromMicrosecondsSinceEpoch(
          app.globalLastRefreshEpochUs,
          isUtc: true,
        );
      }

      final query = _appStateAddressBox
          .query(AppStateAddressEntity_.feedBaseUrl.equals(baseUrl))
          .build();
      final rows = query.find();
      query.close();

      if (rows.isEmpty) {
        return DateTime(1970);
      }

      final latestUs = rows
          .map((e) => e.feedLastRefreshAtUs)
          .fold<int>(0, (a, b) => b > a ? b : a);
      if (latestUs <= 0) {
        return DateTime(1970);
      }

      return DateTime.fromMicrosecondsSinceEpoch(latestUs, isUtc: true);
    });
  }

  /// Mark all feed URLs stale by setting one global epoch.
  Future<void> setLastTimeRefreshFeeds(DateTime time) async {
    await _lock.synchronized(() async {
      final app = _getOrCreateSingleton()
        ..globalLastRefreshEpochUs = time.toUtc().microsecondsSinceEpoch
        ..updatedAtUs = DateTime.now().toUtc().microsecondsSinceEpoch;
      _appStateBox.put(app);
    });
  }

  /// Update refresh timestamp for one feed base URL.
  Future<void> setLastRefreshTime(String baseUrl, DateTime time) async {
    await _lock.synchronized(() async {
      final app = _getOrCreateSingleton()
        ..globalLastRefreshEpochUs = 0
        ..updatedAtUs = DateTime.now().toUtc().microsecondsSinceEpoch;
      _appStateBox.put(app);

      final key = 'FEED::$baseUrl';
      final row = _getOrCreateAddressState(key)
        ..feedBaseUrl = baseUrl
        ..feedLastRefreshAtUs = time.toUtc().microsecondsSinceEpoch
        ..updatedAtUs = DateTime.now().toUtc().microsecondsSinceEpoch;
      _appStateAddressBox.put(row);
    });
  }

  /// Remove feed refresh timestamp for one base URL.
  Future<void> deleteLastRefreshTime(String baseUrl) async {
    await _lock.synchronized(() async {
      final query = _appStateAddressBox
          .query(AppStateAddressEntity_.feedBaseUrl.equals(baseUrl))
          .build();
      final rows = query.find();
      query.close();
      for (final row in rows) {
        _appStateAddressBox.remove(row.id);
      }
    });
  }

  /// Global feed cache TTL.
  Future<Duration> getCacheDuration() async {
    return _lock.synchronized(() {
      final app = _getOrCreateSingleton();
      final seconds = app.feedCacheDurationSeconds > 0
          ? app.feedCacheDurationSeconds
          : _defaultCacheDurationSeconds;
      return Duration(seconds: seconds);
    });
  }

  /// Set global feed cache TTL.
  Future<void> setCacheDuration(Duration duration) async {
    await _lock.synchronized(() async {
      final app = _getOrCreateSingleton()
        ..feedCacheDurationSeconds = duration.inSeconds
        ..updatedAtUs = DateTime.now().toUtc().microsecondsSinceEpoch;
      _appStateBox.put(app);
    });
  }

  /// Global feed last-updated timestamp from remote config.
  Future<DateTime> getLastFeedUpdatedAt() async {
    return _lock.synchronized(() {
      final app = _getOrCreateSingleton();
      return _fromUs(
        app.feedLastUpdatedAtUs,
        fallback: _defaultLastFeedUpdatedAt,
      );
    });
  }

  /// Set global feed last-updated timestamp from remote config.
  Future<void> setLastFeedUpdatedAt(DateTime time) async {
    await _lock.synchronized(() async {
      final app = _getOrCreateSingleton()
        ..feedLastUpdatedAtUs = time.toUtc().microsecondsSinceEpoch
        ..updatedAtUs = DateTime.now().toUtc().microsecondsSinceEpoch;
      _appStateBox.put(app);
    });
  }

  /// Whether user completed onboarding.
  Future<bool> hasSeenOnboarding() async {
    return _lock.synchronized(() {
      return _getOrCreateSingleton().hasSeenOnboarding;
    });
  }

  /// Persist onboarding completion.
  Future<void> setHasSeenOnboarding({required bool hasSeen}) async {
    await _lock.synchronized(() async {
      final app = _getOrCreateSingleton()
        ..hasSeenOnboarding = hasSeen
        ..updatedAtUs = DateTime.now().toUtc().microsecondsSinceEpoch;
      _appStateBox.put(app);
    });
  }

  /// Whether user already saw the Play-to-FF1 tooltip.
  Future<bool> hasSeenPlayToFf1Tooltip() async {
    return _lock.synchronized(() {
      return _getOrCreateSingleton().hasSeenPlayToFf1Tooltip;
    });
  }

  /// Persist Play-to-FF1 tooltip seen state.
  Future<void> setHasSeenPlayToFf1Tooltip({required bool hasSeen}) async {
    await _lock.synchronized(() async {
      final app = _getOrCreateSingleton()
        ..hasSeenPlayToFf1Tooltip = hasSeen
        ..updatedAtUs = DateTime.now().toUtc().microsecondsSinceEpoch;
      _appStateBox.put(app);
    });
  }

  /// Get incremental indexer anchor for an address.
  Future<int?> getAddressAnchor(String address) async {
    return _lock.synchronized(() {
      final row = _findAddressState(_normalizeAddressKey(address));
      if (row == null || !row.hasIndexerAnchor) {
        return null;
      }
      return row.indexerAnchor;
    });
  }

  /// Persist incremental indexer anchor for an address.
  Future<void> setAddressAnchor({
    required String address,
    required int anchor,
  }) async {
    await _lock.synchronized(() async {
      final row = _getOrCreateAddressState(_normalizeAddressKey(address))
        ..hasIndexerAnchor = true
        ..indexerAnchor = anchor
        ..updatedAtUs = DateTime.now().toUtc().microsecondsSinceEpoch;
      _appStateAddressBox.put(row);
    });
  }

  /// Remove incremental indexer anchor for an address.
  Future<void> clearAddressAnchor(String address) async {
    await _lock.synchronized(() async {
      final row = _findAddressState(_normalizeAddressKey(address));
      if (row == null) {
        return;
      }
      row
        ..hasIndexerAnchor = false
        ..indexerAnchor = 0
        ..updatedAtUs = DateTime.now().toUtc().microsecondsSinceEpoch;
      _appStateAddressBox.put(row);
    });
  }

  /// Get per-address indexing process status.
  Future<AddressIndexingProcessStatus?> getAddressIndexingStatus(
    String address,
  ) async {
    return _lock.synchronized(() {
      final row = _findAddressState(_normalizeAddressKey(address));
      if (row == null || row.indexingProcessUpdatedAtUs <= 0) {
        return null;
      }
      return _toProcessStatus(row);
    });
  }

  /// Persist per-address indexing process status.
  Future<void> setAddressIndexingStatus({
    required String address,
    required AddressIndexingProcessStatus status,
  }) async {
    await _lock.synchronized(() async {
      final row = _getOrCreateAddressState(_normalizeAddressKey(address))
        ..indexingProcessStateIndex = status.state.index
        ..indexingProcessUpdatedAtUs = status.updatedAt
            .toUtc()
            .microsecondsSinceEpoch
        ..indexingProcessErrorMessage = status.errorMessage ?? ''
        ..updatedAtUs = DateTime.now().toUtc().microsecondsSinceEpoch;
      _appStateAddressBox.put(row);
    });
  }

  /// Remove per-address indexing process status.
  Future<void> clearAddressIndexingStatus(String address) async {
    await _lock.synchronized(() async {
      final row = _findAddressState(_normalizeAddressKey(address));
      if (row == null) {
        return;
      }
      row
        ..indexingProcessStateIndex = AddressIndexingProcessState.idle.index
        ..indexingProcessUpdatedAtUs = 0
        ..indexingProcessErrorMessage = ''
        ..updatedAtUs = DateTime.now().toUtc().microsecondsSinceEpoch;
      _appStateAddressBox.put(row);
    });
  }

  /// Remove all app-state row data for a specific address key.
  Future<void> clearAddressState(String address) async {
    await _lock.synchronized(() async {
      final row = _findAddressState(_normalizeAddressKey(address));
      if (row != null) {
        _appStateAddressBox.remove(row.id);
      }
    });
  }

  /// Returns all persisted indexing statuses keyed by normalized address.
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

  void debugLogSummary() {
    _log.fine(
      'AppState summary: app=${_appStateBox.count()}, address=${_appStateAddressBox.count()}',
    );
  }
}

/// Single provider for typed local app state.
final appStateServiceProvider = Provider<AppStateService>((ref) {
  final store = getInitializedObjectBoxStore();
  return AppStateService(
    appStateBox: store.box<AppStateEntity>(),
    appStateAddressBox: store.box<AppStateAddressEntity>(),
    logger: Logger('AppStateService'),
  );
});

/// Provider that reads added addresses from SQLite source of truth.
final addedAddressesProvider = FutureProvider<List<String>>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  final playlists = await databaseService.getAddressPlaylists();
  return playlists
      .map((playlist) => playlist.ownerAddress)
      .whereType<String>()
      .map((address) => address.toUpperCase())
      .toSet()
      .toList();
});
