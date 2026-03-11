import 'dart:async';
import 'dart:math';

import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/api/dp1_feed_api.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control_verifier.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_rest_client.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_relayer_transport.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/integration_env.dart';
import '../../helpers/integration_test_harness.dart';

const String _skipReason =
    'FF1 integration skipped because FF1_TEST_TOPIC_ID is missing in .env.';

void main() {
  final env = loadRootEnvValues();
  final skipDeviceFlow = resolveIntegrationTopicId(env).isEmpty;
  const feralFileChannelId = '0fdd0465-217c-4734-9bfd-2d807b414482';

  group('FF1 device actions flow', () {
    test(
      'connects by topic-id, validates status, and executes control actions',
      skip: skipDeviceFlow ? _skipReason : null,
      () async {
        await provisionIntegrationEnvFile();
        final topicId = resolveIntegrationTopicId(loadRootEnvValues());
        final relayerApiKey = AppConfig.ff1RelayerApiKey;
        final userId = env['FF1_TEST_USER_ID'] ?? 'integration-test-runner';

        expect(topicId, isNotEmpty);
        expect(relayerApiKey, isNotEmpty);
        expect(AppConfig.ff1RelayerUrl, isNotEmpty);
        expect(AppConfig.ff1CastApiUrl, isNotEmpty);

        final transport = FF1RelayerTransport(
          relayerUrl: AppConfig.ff1RelayerUrl,
        );
        final control = FF1WifiControl(
          transport: transport,
          restClient: FF1WifiRestClient(
            castApiUrl: AppConfig.ff1CastApiUrl,
            apiKey: relayerApiKey,
          ),
        );
        addTearDown(() async {
          await control.disconnect();
        });

        final device = FF1Device(
          name: 'Integration FF1',
          remoteId: 'integration-remote',
          deviceId: 'integration-device',
          topicId: topicId,
        );

        await control.connect(
          device: device,
          userId: userId,
          apiKey: relayerApiKey,
        );

        final connectionStatus = await control.connectionStatusStream
            .firstWhere((status) => status.isConnected)
            .timeout(
              const Duration(seconds: 45),
              onTimeout: () => throw TimeoutException(
                'Timed out waiting for FF1 connection event.',
              ),
            );
        expect(connectionStatus.isConnected, isTrue);

        final deviceStatus = await control.deviceStatusStream
            .firstWhere(ff1DeviceStatusHasSignal)
            .timeout(
              const Duration(seconds: 60),
              onTimeout: () => throw TimeoutException(
                'Timed out waiting for FF1 device status signal.',
              ),
            );
        expect(ff1DeviceStatusHasSignal(deviceStatus), isTrue);

        final playResponse = await control.tap(topicId: topicId);
        expect(ff1CommandResponseIsOk(playResponse), isTrue);

        final rotateResponse = await control.rotate(
          topicId: topicId,
        );
        expect(rotateResponse.data, isNotNull);
        expect(
          rotateResponse.data?['orientation'],
          isNotEmpty,
        );

        final dragResponse = await control.drag(
          topicId: topicId,
          cursorOffsets: const <Offset>[
            Offset(16, -9),
            Offset(-8, 7),
          ],
        );
        expect(ff1CommandResponseIsOk(dragResponse), isTrue);

        final restartResponse = await control.reboot(topicId: topicId);
        expect(ff1CommandResponseIsOk(restartResponse), isTrue);
      },
      timeout: const Timeout(Duration(minutes: 8)),
    );

    test(
      'displays a random playlist from feed channel then runs resume/next',
      skip: skipDeviceFlow ? _skipReason : null,
      () async {
        await provisionIntegrationEnvFile();
        final topicId = resolveIntegrationTopicId(loadRootEnvValues());
        final relayerApiKey = AppConfig.ff1RelayerApiKey;
        final userId = env['FF1_TEST_USER_ID'] ?? 'integration-test-runner';
        final channelId = env['FF1_TEST_CHANNEL_ID'] ?? feralFileChannelId;
        final feedBaseUrl = AppConfig.dp1FeedUrl;

        expect(topicId, isNotEmpty);
        expect(feedBaseUrl, isNotEmpty);
        expect(relayerApiKey, isNotEmpty);

        final playlists = await _fetchChannelPlaylists(
          baseUrl: feedBaseUrl,
          channelId: channelId,
        );
        expect(playlists, isNotEmpty);
        playlists.shuffle(Random());

        final restClient = FF1WifiRestClient(
          castApiUrl: AppConfig.ff1CastApiUrl,
          apiKey: relayerApiKey,
        );
        final transport = FF1RelayerTransport(
          relayerUrl: AppConfig.ff1RelayerUrl,
        );
        final control = FF1WifiControl(
          transport: transport,
          restClient: restClient,
        );
        addTearDown(() async {
          await control.disconnect();
          restClient.dispose();
        });

        final device = FF1Device(
          name: 'Integration FF1',
          remoteId: 'integration-remote',
          deviceId: 'integration-device',
          topicId: topicId,
        );

        await control.connect(
          device: device,
          userId: userId,
          apiKey: relayerApiKey,
        );

        await control.connectionStatusStream
            .firstWhere((status) => status.isConnected)
            .timeout(
              const Duration(seconds: 45),
              onTimeout: () => throw TimeoutException(
                'Timed out waiting for FF1 connection event.',
              ),
            );

        final displayResponse = await _displayRandomPlaylist(
          topicId: topicId,
          feedBaseUrl: feedBaseUrl,
          playlists: playlists,
          restClient: restClient,
        );
        expect(ff1CommandResponseIsOk(displayResponse), isTrue);

        await Future<void>.delayed(const Duration(seconds: 2));

        final resumeResponse = await control.resume(topicId: topicId);
        expect(ff1CommandResponseHasOkFlag(resumeResponse), isTrue);

        final nextResponse = await control.nextArtwork(topicId: topicId);
        expect(ff1CommandResponseHasOkFlag(nextResponse), isTrue);
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  });
}

Future<List<DP1Playlist>> _fetchChannelPlaylists({
  required String baseUrl,
  required String channelId,
}) async {
  final api = Dp1FeedApiImpl(
    dio: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 40),
      ),
    ),
    baseUrl: baseUrl,
    apiKey: AppConfig.dp1FeedApiKey,
  );

  final response = await api.getPlaylists(
    channelId: channelId,
    limit: 50,
  );
  return response.items;
}

Future<FF1CommandResponse> _displayRandomPlaylist({
  required String topicId,
  required String feedBaseUrl,
  required List<DP1Playlist> playlists,
  required FF1WifiRestClient restClient,
}) async {
  Object? lastError;

  for (final playlist in playlists.take(10)) {
    final playlistUrl = '$feedBaseUrl/api/v1/playlists/${playlist.id}';
    try {
      final displayRaw = await restClient.sendCommand(
        topicId: topicId,
        command: 'displayPlaylist',
        params: <String, dynamic>{
          'playlistUrl': playlistUrl,
          'intent': <String, dynamic>{'action': 'now_display'},
        },
        timeout: const Duration(seconds: 30),
      );
      final response = FF1CommandResponse.fromJson(displayRaw);
      if (ff1CommandResponseIsOk(response)) {
        return response;
      }
      lastError = StateError(
        'displayPlaylist responded without ok for playlist ${playlist.id}',
      );
    } on Exception catch (error) {
      lastError = error;
    }
  }

  throw StateError('Failed to display a playlist after retries: $lastError');
}
