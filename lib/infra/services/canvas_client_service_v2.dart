import 'dart:async';

import 'package:app/domain/models/dp1/dp1_intent.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/models/ff1/art_framing.dart';
import 'package:app/domain/models/ff1/canvas_cast_request_reply.dart';
import 'package:app/domain/models/ff1/screen_orientation.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/tv_cast/tv_cast_api.dart';
import 'package:app/infra/ff1/tv_cast/tv_cast_service.dart';
import 'package:app/infra/services/device_info_service.dart';
import 'package:app/util/user_agent_utils.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

/// Client service for casting and controlling FF1 devices via relayer.
class CanvasClientServiceV2 {
  CanvasClientServiceV2(
    this._deviceInfoService,
    this._tvCastApi, {
    Future<String> Function()? getDeviceId,
    String? dp1FeedBaseUrl,
  })  : _dp1FeedBaseUrl = dp1FeedBaseUrl ?? '' {
    _getDeviceId =
        getDeviceId ?? () => Future<String>.value(_deviceInfoService.deviceId);
  }

  final DeviceInfoService _deviceInfoService;
  final TvCastApi _tvCastApi;
  late final Future<String> Function() _getDeviceId;
  final String _dp1FeedBaseUrl;
  static final _log = Logger('CanvasClientServiceV2');
  final List<CursorOffset> dragOffsets = <CursorOffset>[];

  DeviceInfoV2 get clientDeviceInfo => DeviceInfoV2(
        deviceId: _deviceInfoService.deviceId,
        deviceName: _deviceInfoService.deviceName,
        platform: _platform,
      );

  TvCastService _getStub(FF1Device device) =>
      TvCastServiceImpl(_tvCastApi, device);

  DevicePlatform get _platform {
    final device = DeviceInfo.instance;
    if (device.isAndroid) {
      return DevicePlatform.android;
    }
    if (device.isIOS) {
      return DevicePlatform.iOS;
    }
    return DevicePlatform.other;
  }

  Future<ConnectReplyV2> _connect(FF1Device device) async {
    final stub = _getStub(device);
    final deviceInfo = clientDeviceInfo;
    final userId = await _getDeviceId();
    final request = ConnectRequestV2(
      clientDevice: deviceInfo,
      primaryAddress: userId,
    );
    return stub.connect(request);
  }

  Future<bool> connectToDevice(FF1Device device) async {
    try {
      final response = await _connect(device);
      return response.ok;
    } catch (e) {
      _log.info('CanvasClientService: connectToDevice error: $e');
      return false;
    }
  }

  Future<void> disconnectDevice(FF1Device device) async {
    final stub = _getStub(device);
    await stub.disconnect(DisconnectRequestV2());
  }

  Future<bool> castPlaylist(
    FF1Device device,
    DP1Playlist playlist,
    DP1Intent intent, {
    bool usingUrl = true,
  }) async {
    try {
      final canConnect = await connectToDevice(device);
      if (!canConnect) {
        return false;
      }
      final stub = _getStub(device);
      final playlistUrl = _dp1FeedBaseUrl.isNotEmpty
          ? '$_dp1FeedBaseUrl/api/v1/playlists/${playlist.id}'
          : playlist.id;
      final dp1CallRequest = usingUrl
          ? CastDP1UrlPlaylistRequest(
              playlistUrl: playlistUrl,
              intent: intent,
            )
          : CastDP1JsonPlaylistRequest(
              dp1Call: playlist,
              intent: intent,
            );
      final response = await stub.castDP1Playlist(dp1CallRequest);
      return response.ok;
    } catch (e) {
      _log.info('CanvasClientService: castPlaylist error: $e');
      return false;
    }
  }

  Future<bool> pauseCasting(FF1Device device) async {
    final stub = _getStub(device);
    final response = await stub.pauseCasting(PauseCastingRequest());
    return response.ok;
  }

  Future<bool> resumeCasting(FF1Device device) async {
    final stub = _getStub(device);
    final response = await stub.resumeCasting(ResumeCastingRequest());
    return response.ok;
  }

  Future<bool> nextArtwork(FF1Device device, {String? startTime}) async {
    final stub = _getStub(device);
    final request = NextArtworkRequest(
      startTime: startTime == null ? null : int.tryParse(startTime),
    );
    final response = await stub.nextArtwork(request);
    return response.ok;
  }

  Future<bool> previousArtwork(FF1Device device, {String? startTime}) async {
    final stub = _getStub(device);
    final request = PreviousArtworkRequest(
      startTime: startTime == null ? null : int.tryParse(startTime),
    );
    final response = await stub.previousArtwork(request);
    return response.ok;
  }

  Future<bool> moveToArtwork(FF1Device device, {required int index}) async {
    final stub = _getStub(device);
    final request = MoveToArtworkRequest(index: index);
    final response = await stub.moveToArtwork(request);
    return response.ok;
  }

  Future<UpdateDurationReply> updateDuration(
    FF1Device device,
    List<PlayArtworkV2> artworks,
  ) async {
    final stub = _getStub(device);
    return stub.updateDuration(UpdateDurationRequest(artworks: artworks));
  }

  Future<void> sendKeyBoard(List<FF1Device> devices, int code) async {
    for (final device in devices) {
      final stub = _getStub(device);
      final response =
          await stub.keyboardEvent(KeyboardEventRequest(code: code));
      if (response.ok) {
        _log.info('CanvasClientService: Keyboard Event Success $code');
      } else {
        _log.info('CanvasClientService: Keyboard Event Failed $code');
      }
    }
  }

  Future<ScreenOrientation?> rotateCanvas(
    FF1Device device, {
    bool clockwise = false,
  }) async {
    final stub = _getStub(device);
    final request = RotateRequest(clockwise: clockwise);
    try {
      final response = await stub.rotate(request);
      _log.info(
        'CanvasClientService: Rotate Canvas Success ${response.orientation}',
      );
      return response.orientation;
    } catch (e) {
      _log.info('CanvasClientService: Rotate Canvas Failed');
      return null;
    }
  }

  Future<bool> setSleepMode(FF1Device device, bool sleepMode) async {
    final stub = _getStub(device);
    final request = SetSleepModeRequest(sleepMode: sleepMode);
    try {
      final response = await stub.setSleepMode(request);
      return response.ok;
    } catch (e) {
      _log.info('CanvasClientService: Set Sleep Mode Failed');
      return false;
    }
  }

  Future<bool> updateArtFraming(
    FF1Device device,
    ArtFraming artFraming,
  ) async {
    final stub = _getStub(device);
    final request = UpdateArtFramingRequest(artFraming: artFraming);
    final response = await stub.updateArtFraming(request);
    _log.info(
      'CanvasClientService: Update Art Framing Success: response $response',
    );
    return response.ok;
  }

  Future<void> updateToLatestVersion(FF1Device device) async {
    final stub = _getStub(device);
    final request = UpdateToLatestVersionRequest();
    final response = await stub.updateToLatestVersion(request);
    _log.info(
      'CanvasClientService: Update To Latest Version Success: response ${response.toJson()}',
    );
  }

  Future<void> tap(List<FF1Device> devices) async {
    for (final device in devices) {
      final stub = _getStub(device);
      await stub.tap(TapGestureRequest());
    }
  }

  Future<void> _sendDrag(
    List<FF1Device> devices,
    List<CursorOffset> offsets,
  ) async {
    await Future.forEach(devices, (device) async {
      try {
        final stub = _getStub(device);
        await stub.drag(DragGestureRequest(cursorOffsets: offsets));
      } catch (e) {
        _log.info('CanvasClientService: Drag Failed to device: ${device.deviceId}');
      }
    });
  }

  Future<void> drag(List<FF1Device> devices, Offset offset) async {
    dragOffsets.add(CursorOffset(dx: offset.dx, dy: offset.dy));
    if (dragOffsets.length > 5) {
      final offsets = List<CursorOffset>.from(dragOffsets);
      dragOffsets.clear();
      unawaited(_sendDrag(devices, offsets));
    }
  }

  Future<bool> showPairingQRCode(FF1Device device, bool show) async {
    try {
      final stub = _getStub(device);
      final response =
          await stub.showPairingQRCode(ShowPairingQRCodeRequest(show: show));
      _log.info('CanvasClientService: Show Pairing QR Code ${response.success}');
      return response.success;
    } catch (e) {
      _log.info('CanvasClientService: showPairingQRCode error: $e');
      return false;
    }
  }

  Future<bool> safeShutdown(FF1Device device) async {
    try {
      final stub = _getStub(device);
      await stub.safeShutdown(SafeShutdownRequest());
      return true;
    } catch (e) {
      _log.info('CanvasClientService: safeShutdown error: $e');
      return false;
    }
  }

  Future<bool> safeRestart(FF1Device device) async {
    try {
      final stub = _getStub(device);
      await stub.safeRestart(SafeRestartRequest());
      return true;
    } catch (e) {
      _log.info('CanvasClientService: safeRestart error: $e');
      return false;
    }
  }

  Future<bool> safeFactoryReset(FF1Device device) async {
    try {
      final stub = _getStub(device);
      final response = await stub.safeFactoryReset(SafeFactoryResetRequest());
      return response.ok;
    } catch (e) {
      _log.info('CanvasClientService: safeFactoryReset error: $e');
      rethrow;
    }
  }

  Future<bool> sendLog(FF1Device device, String? title) async {
    try {
      final stub = _getStub(device);
      final deviceId = await _getDeviceId();
      final message = title ?? device.name;
      const apiKey = '';
      final request = SendLogRequest(
        userId: deviceId,
        title: message,
        apiKey: apiKey,
      );
      final response = await stub.sendLog(request);
      if (response.ok) {
        _log.info('CanvasClientService: sendLog success');
      } else {
        _log.info('CanvasClientService: sendLog failed');
      }
      return response.ok;
    } catch (e) {
      _log.info('CanvasClientService: sendLog error: $e');
      rethrow;
    }
  }

  Future<DeviceRealtimeMetrics> getDeviceRealtimeMetrics(
    FF1Device device,
  ) async {
    final stub = _getStub(device);
    final response = await stub.deviceMetrics(DeviceRealtimeMetricsRequest());
    return response.metrics;
  }
}
