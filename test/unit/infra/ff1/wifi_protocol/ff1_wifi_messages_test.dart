import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/ff1/screen_orientation.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FF1WifiMessageType', () {
    test('fromString parses notification correctly', () {
      expect(
        FF1WifiMessageType.fromString('notification'),
        FF1WifiMessageType.notification,
      );
    });

    test('fromString parses RPC correctly', () {
      expect(
        FF1WifiMessageType.fromString('RPC'),
        FF1WifiMessageType.rpc,
      );
    });

    test('fromString throws on unknown type', () {
      expect(
        () => FF1WifiMessageType.fromString('unknown'),
        throwsArgumentError,
      );
    });

    test('value returns correct string', () {
      expect(FF1WifiMessageType.notification.value, 'notification');
      expect(FF1WifiMessageType.rpc.value, 'RPC');
    });
  });

  group('FF1NotificationType', () {
    test('fromString parses player_status correctly', () {
      expect(
        FF1NotificationType.fromString('player_status'),
        FF1NotificationType.playerStatus,
      );
    });

    test('fromString parses device_status correctly', () {
      expect(
        FF1NotificationType.fromString('device_status'),
        FF1NotificationType.deviceStatus,
      );
    });

    test('fromString parses connection correctly', () {
      expect(
        FF1NotificationType.fromString('connection'),
        FF1NotificationType.connection,
      );
    });

    test('fromString throws on unknown type', () {
      expect(
        () => FF1NotificationType.fromString('unknown'),
        throwsArgumentError,
      );
    });

    test('value returns correct string', () {
      expect(FF1NotificationType.playerStatus.value, 'player_status');
      expect(FF1NotificationType.deviceStatus.value, 'device_status');
      expect(FF1NotificationType.connection.value, 'connection');
    });
  });

  group('FF1NotificationMessage', () {
    test('fromJson parses player status message correctly', () {
      final json = {
        'type': 'notification',
        'notification_type': 'player_status',
        'message': {
          'playlistId': 'pl_123',
          'index': 5,
          'isPaused': false,
        },
        'timestamp': 1704067200000,
      };

      final message = FF1NotificationMessage.fromJson(json);

      expect(message.type, FF1WifiMessageType.notification);
      expect(message.notificationType, FF1NotificationType.playerStatus);
      expect(message.message['playlistId'], 'pl_123');
      expect(message.message['index'], 5);
      expect(message.message['isPaused'], false);
      expect(
        message.timestamp,
        DateTime.fromMillisecondsSinceEpoch(1704067200000),
      );
    });

    test('toJson serializes correctly', () {
      final message = FF1NotificationMessage(
        type: FF1WifiMessageType.notification,
        notificationType: FF1NotificationType.playerStatus,
        message: {
          'playlistId': 'pl_123',
          'index': 5,
          'isPaused': false,
        },
        timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200000),
      );

      final json = message.toJson();

      expect(json['type'], 'notification');
      expect(json['notification_type'], 'player_status');
      expect(json['message']['playlistId'], 'pl_123');
      expect(json['timestamp'], 1704067200000);
    });

    test('roundtrip serialization preserves data', () {
      final original = FF1NotificationMessage(
        type: FF1WifiMessageType.notification,
        notificationType: FF1NotificationType.deviceStatus,
        message: {
          'connectedWifi': 'MyNetwork',
          'internetConnected': true,
        },
        timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200000),
      );

      final json = original.toJson();
      final deserialized = FF1NotificationMessage.fromJson(json);

      expect(deserialized.type, original.type);
      expect(deserialized.notificationType, original.notificationType);
      expect(deserialized.message, original.message);
      expect(deserialized.timestamp, original.timestamp);
    });
  });

  group('FF1PlayerStatus', () {
    test('fromJson parses complete player status', () {
      final json = {
        'playlistId': 'pl_abc123',
        'index': 3,
        'isPaused': true,
        'connectedDevice': {'device_id': 'device_xyz'},
        'items': [
          {
            'id': 'wk_1',
            'duration': 0,
            'title': 'Work Title',
          },
        ],
      };

      final status = FF1PlayerStatus.fromJson(json);

      expect(status.playlistId, 'pl_abc123');
      expect(status.currentWorkIndex, 3);
      expect(status.isPaused, true);
      expect(status.connectedDeviceId, 'device_xyz');
      expect(status.items, isNotNull);
      expect(status.items!.length, 1);
      expect(status.items![0].id, 'wk_1');
      expect(status.items![0].title, 'Work Title');
    });

    test('fromJson handles minimal player status', () {
      final json = {
        'playlistId': null,
        'index': null,
        'isPaused': null,
      };

      final status = FF1PlayerStatus.fromJson(json);

      expect(status.playlistId, isNull);
      expect(status.currentWorkIndex, isNull);
      expect(status.isPaused, false); // defaults to false
      expect(status.connectedDeviceId, isNull);
      expect(status.items, isNull);
    });

    test('toJson serializes correctly', () {
      const status = FF1PlayerStatus(
        playlistId: 'pl_test',
        currentWorkIndex: 2,
        connectedDeviceId: 'dev_123',
      );

      final json = status.toJson();

      expect(json['playlistId'], 'pl_test');
      expect(json['index'], 2);
      expect(json['isPaused'], false);
      expect(json['connectedDevice']['device_id'], 'dev_123');
    });
  });

  group('FF1PlayerStatus items via fromJson', () {
    test('parses items with FF1 call structure', () {
      final json = {
        'playlistId': 'pl_abc',
        'index': 0,
        'items': [
          {
            'id': 'wk_abc',
            'duration': 0,
            'title': 'Artwork Title',
            'thumbnail_url': 'https://example.com/thumb.jpg',
          },
        ],
      };

      final status = FF1PlayerStatus.fromJson(json);

      expect(status.items, isNotNull);
      expect(status.items!.length, 1);
      expect(status.items![0].id, 'wk_abc');
      expect(status.items![0].title, 'Artwork Title');
      expect(status.items![0].duration, 0);
    });
  });

  group('FF1PlayerStatus toJson with items', () {
    test('serializes items in FF1 wire format', () {
      final status = FF1PlayerStatus(
        playlistId: 'pl_test',
        currentWorkIndex: 0,
        connectedDeviceId: 'dev_123',
        items: [
          DP1PlaylistItem(
            id: 'wk_test',
            duration: 0,
            title: 'Test Work',
          ),
        ],
      );

      final json = status.toJson();

      expect(json['items'], isNotNull);
      expect((json['items'] as List).length, 1);
      expect((json['items'] as List)[0]['id'], 'wk_test');
      expect((json['items'] as List)[0]['title'], 'Test Work');
    });
  });

  group('FF1DeviceStatus', () {
    test('fromJson parses device status correctly', () {
      final json = {
        'connectedWifi': 'MyWiFi',
        'screenRotation': 'landscape',
        'installedVersion': '1.2.3',
        'latestVersion': '1.3.0',
        'internetConnected': true,
      };

      final status = FF1DeviceStatus.fromJson(json);

      expect(status.connectedWifi, 'MyWiFi');
      expect(status.screenRotation, ScreenOrientation.landscape);
      expect(status.installedVersion, '1.2.3');
      expect(status.latestVersion, '1.3.0');
      expect(status.internetConnected, true);
    });

    test('toJson serializes correctly', () {
      const status = FF1DeviceStatus(
        connectedWifi: 'TestNetwork',
        screenRotation: ScreenOrientation.portrait,
        installedVersion: '2.0.0',
        latestVersion: '2.1.0',
        internetConnected: false,
      );

      final json = status.toJson();

      expect(json['connectedWifi'], 'TestNetwork');
      expect(json['screenRotation'], 'portrait');
      expect(json['installedVersion'], '2.0.0');
      expect(json['latestVersion'], '2.1.0');
      expect(json['internetConnected'], false);
    });
  });

  group('FF1ConnectionStatus', () {
    test('fromJson parses connection status correctly', () {
      final json = {'isConnected': true};

      final status = FF1ConnectionStatus.fromJson(json);

      expect(status.isConnected, true);
    });

    test('toJson serializes correctly', () {
      const status = FF1ConnectionStatus(isConnected: false);

      final json = status.toJson();

      expect(json['isConnected'], false);
    });
  });
}
