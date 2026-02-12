import 'dart:async';

import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/config/remote_config_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/database/ff1_bluetooth_device_service.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/indexer/isolate/indexer_tokens_worker.dart';
import 'package:app/infra/indexer/isolate/worker_messages.dart';
import 'package:app/infra/indexer/isolate/worker_tasks.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

Future<void> ensureDotEnvLoaded() async {
  if (!dotenv.isInitialized) {
    await dotenv.load(fileName: '.env');
  }
}

class CounterNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() {
    state++;
  }
}

class FakeIndexerClient extends IndexerClient {
  FakeIndexerClient() : super(endpoint: 'https://example.invalid');
}

class FakeIndexerService extends IndexerService {
  FakeIndexerService({
    this.tokensByCid = const <AssetToken>[],
  }) : super(client: FakeIndexerClient());

  final List<AssetToken> tokensByCid;
  List<String>? lastTokenCids;

  @override
  Future<List<AssetToken>> fetchTokensByCIDs({
    required List<String> tokenCids,
  }) async {
    lastTokenCids = tokenCids;
    return tokensByCid;
  }

  @override
  Future<List<AddressIndexingResult>> indexAddressesList(
    List<String> addresses,
  ) async {
    return const <AddressIndexingResult>[];
  }

  @override
  Future<AddressIndexingJobResponse> getAddressIndexingJobStatus({
    required String workflowId,
  }) async {
    return AddressIndexingJobResponse(
      workflowId: workflowId,
      address: '',
      status: IndexingJobStatus.completed,
      totalTokensIndexed: 0,
      totalTokensViewable: 0,
    );
  }
}

class FakeIndexerSyncService extends IndexerSyncService {
  FakeIndexerSyncService({
    this.nextCount = 0,
  }) : super(
         indexerService: FakeIndexerService(),
         databaseService: DatabaseService(
           AppDatabase.forTesting(NativeDatabase.memory()),
         ),
       );

  final int nextCount;
  List<String>? lastAddresses;

  @override
  Future<int> syncTokensForAddresses({
    required List<String> addresses,
    int? limit,
    int? offset,
  }) async {
    lastAddresses = addresses;
    return nextCount;
  }
}

class MockFF1BluetoothDeviceService implements FF1BluetoothDeviceService {
  List<FF1Device> devices = <FF1Device>[];
  String? activeId;

  @override
  List<FF1Device> getAllDevices() => List<FF1Device>.from(devices);

  @override
  FF1Device? getDeviceById(String deviceId) {
    for (final device in devices) {
      if (device.deviceId == deviceId) return device;
    }
    return null;
  }

  @override
  FF1Device? getActiveDevice() {
    final id = activeId;
    if (id == null) return null;
    return getDeviceById(id);
  }

  @override
  FF1Device? getDeviceByRemoteId(String remoteId) {
    for (final device in devices) {
      if (device.remoteId == remoteId) return device;
    }
    return null;
  }

  @override
  Future<void> putDevice(FF1Device device) async {
    devices = [
      for (final current in devices)
        if (current.deviceId != device.deviceId) current,
      device,
    ];
  }

  @override
  Future<void> removeDevice(String deviceId) async {
    devices = devices.where((d) => d.deviceId != deviceId).toList();
    if (activeId == deviceId) {
      activeId = null;
    }
  }

  @override
  Future<void> setActiveDevice(String deviceId) async {
    activeId = deviceId;
  }

  @override
  Future<void> updateConnectionState(String deviceId, int state) async {}

  @override
  Future<void> recordFailedConnection(String deviceId) async {}

  @override
  Future<void> updateTopicId(String deviceId, String topicId) async {
    devices = devices
        .map((d) => d.deviceId == deviceId ? d.copyWith(topicId: topicId) : d)
        .toList();
  }

  @override
  Future<void> updateMetadata(
    String deviceId,
    Map<String, dynamic> metadata,
  ) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class MockRemoteConfigService implements RemoteConfigService {
  @override
  Future<CachedRemoteConfig?> refreshIfChanged() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class MockAppStateService implements AppStateService {
  bool hasSeen = false;

  @override
  Future<bool> hasSeenOnboarding() async => hasSeen;

  @override
  Future<void> setHasSeenOnboarding({required bool hasSeen}) async {
    this.hasSeen = hasSeen;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeIndexerTokensWorker extends IndexerTokensWorker {
  FakeIndexerTokensWorker()
    : super(endpoint: 'https://example.invalid', apiKey: '');

  final StreamController<TokensWorkerMessage> _controller =
      StreamController<TokensWorkerMessage>.broadcast();

  @override
  Stream<TokensWorkerMessage> get messages => _controller.stream;

  @override
  Future<void> get ready async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {
    await _controller.close();
  }

  @override
  void updateTokensInIsolate({
    required String uuid,
    required List<AddressAnchor> addressAnchors,
  }) {
    _controller.add(UpdateTokensSuccess(uuid));
  }

  @override
  void reindexAddressesList({
    required String uuid,
    required List<String> addresses,
  }) {
    _controller.add(
      ReindexAddressesListDone(uuid, const <AddressIndexingResult>[]),
    );
  }

  @override
  void notifyChannelIngested({required String uuid}) {
    _controller.add(ChannelIngestedAck(uuid));
  }
}

class FakeWifiTransport implements FF1WifiTransport {
  final _notifications = StreamController<FF1NotificationMessage>.broadcast();
  final _connections = StreamController<bool>.broadcast();
  final _errors = StreamController<FF1WifiTransportError>.broadcast();

  @override
  Stream<bool> get connectionStateStream => _connections.stream;

  @override
  Stream<FF1NotificationMessage> get notificationStream =>
      _notifications.stream;

  @override
  Stream<FF1WifiTransportError> get errorStream => _errors.stream;

  @override
  bool get isConnected => false;

  @override
  Future<void> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
  }) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> sendCommand(Map<String, dynamic> command) async {}

  @override
  void dispose() {
    unawaited(_notifications.close());
    unawaited(_connections.close());
    unawaited(_errors.close());
  }
}

class FakeWifiControl extends FF1WifiControl {
  FakeWifiControl()
    : super(
        transport: FakeWifiTransport(),
        logger: Logger('FakeWifiControl'),
      );
}
