import 'dart:async';

import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/database/ff1_bluetooth_device_service.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

Future<void> ensureDotEnvLoaded() async {
  if (!dotenv.isInitialized) {
    await dotenv.load();
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
  Future<List<AssetToken>> getManualTokens({
    List<int>? tokenIds,
    List<String>? owners,
    List<String>? tokenCids,
    int? limit,
    int? offset,
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
  String? activeDeviceId;

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
    final id = activeDeviceId ?? activeId;
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
    activeDeviceId = deviceId;
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
  Stream<List<FF1Device>> watchAllDevices() async* {
    yield getAllDevices();
  }

  @override
  Stream<FF1Device?> watchActiveDevice() async* {
    yield getActiveDevice();
  }

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
  Stream<AddressIndexingProcessStatus?> watchAddressIndexingStatus(
    String address,
  ) => Stream.value(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeWifiTransport implements FF1WifiTransport {
  final _notifications = StreamController<FF1NotificationMessage>.broadcast();
  final _connections = StreamController<bool>.broadcast();
  final _errors = StreamController<FF1WifiTransportError>.broadcast();
  bool _isConnected = false;
  bool _isConnecting = false;

  @override
  Stream<bool> get connectionStateStream => _connections.stream;

  @override
  Stream<FF1NotificationMessage> get notificationStream =>
      _notifications.stream;

  @override
  Stream<FF1WifiTransportError> get errorStream => _errors.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isConnecting => _isConnecting;

  @override
  Future<void> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
    bool forceReconnect = false,
  }) async {
    _isConnecting = true;
    _isConnected = true;
    _isConnecting = false;
    _connections.add(true);
  }

  @override
  void pauseConnection() {
    _isConnected = false;
    _isConnecting = false;
    _connections.add(false);
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    _isConnecting = false;
    _connections.add(false);
  }

  void emitTransportConnection({required bool isConnected}) {
    _isConnected = isConnected;
    _isConnecting = false;
    _connections.add(isConnected);
  }

  void emitPlayerStatus(FF1PlayerStatus status) {
    _notifications.add(
      FF1NotificationMessage(
        type: FF1WifiMessageType.notification,
        message: status.toJson(),
        notificationType: FF1NotificationType.playerStatus,
        timestamp: DateTime.now(),
      ),
    );
  }

  void emitDeviceStatus(FF1DeviceStatus status) {
    _notifications.add(
      FF1NotificationMessage(
        type: FF1WifiMessageType.notification,
        message: status.toJson(),
        notificationType: FF1NotificationType.deviceStatus,
        timestamp: DateTime.now(),
      ),
    );
  }

  void emitConnectionStatus({required bool isConnected}) {
    _notifications.add(
      FF1NotificationMessage(
        type: FF1WifiMessageType.notification,
        message: {'isConnected': isConnected},
        notificationType: FF1NotificationType.connection,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> sendCommand(Map<String, dynamic> command) async {}

  @override
  void dispose() {
    unawaited(_notifications.close());
    unawaited(_connections.close());
    unawaited(_errors.close());
  }

  @override
  Future<void> disposeFuture() async {
    dispose();
  }
}

class FakeWifiControl extends FF1WifiControl {
  FakeWifiControl({
    FakeWifiTransport? transport,
  }) : this._(transport ?? FakeWifiTransport());

  FakeWifiControl._(this._transport)
    : super(
        transport: _transport,
        logger: Logger('FakeWifiControl'),
      );

  final FakeWifiTransport _transport;

  bool connectCalled = false;
  bool disconnectCalled = false;
  bool disconnectShouldThrow = false;
  FF1Device? lastConnectedDevice;

  /// When true, [connect] returns without opening a transport socket (mirrors
  /// [FF1WifiControl] swallowing [FF1WifiConnectionCancelledError]).
  bool connectEndsWithoutTransportSocket = false;

  /// When true, [reconnect] returns without opening a transport socket.
  bool reconnectEndsWithoutTransportSocket = false;

  @override
  Future<void> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
  }) async {
    connectCalled = true;
    lastConnectedDevice = device;
    if (connectEndsWithoutTransportSocket) {
      return;
    }
    await super.connect(device: device, userId: userId, apiKey: apiKey);
  }

  @override
  Future<void> reconnect() async {
    if (reconnectEndsWithoutTransportSocket) {
      return;
    }
    await super.reconnect();
  }

  @override
  Future<void> disconnect() async {
    disconnectCalled = true;
    if (disconnectShouldThrow) {
      throw Exception('disconnect failed');
    }
    await super.disconnect();
  }

  void emitPlayerStatus(FF1PlayerStatus status) {
    _transport.emitPlayerStatus(status);
  }

  void emitDeviceStatus(FF1DeviceStatus status) {
    _transport.emitDeviceStatus(status);
  }

  void emitConnectionStatus({required bool isConnected}) {
    _transport.emitConnectionStatus(isConnected: isConnected);
  }

  void emitTransportConnection({required bool isConnected}) {
    _transport.emitTransportConnection(isConnected: isConnected);
  }
}
