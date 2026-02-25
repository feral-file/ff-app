import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Base class for FF1-related errors
abstract class FF1Error implements Exception {
  const FF1Error(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Bluetooth connection error
class FF1BluetoothError extends FF1Error {
  const FF1BluetoothError(super.message);
}

/// Device disconnected error
class FF1DisconnectedError extends FF1BluetoothError {
  const FF1DisconnectedError({
    required this.disconnectReason,
  }) : super('Bluetooth device disconnected: $disconnectReason');

  final DisconnectReason? disconnectReason;
}

/// Connection cancelled by user/caller
class FF1ConnectionCancelledError extends FF1BluetoothError {
  const FF1ConnectionCancelledError() : super('Connection cancelled');
}

/// Error codes from FF1 device responses
enum FF1ResponseErrorCode {
  wrongPassword(1, 'Incorrect Wi-Fi password'),
  noInternet(2, 'No internet access'),
  serverUnreachable(3, 'Cannot reach server'),
  wifiRequired(4, 'Wi-Fi required'),
  deviceUpdating(5, 'Device is updating'),
  versionCheckFailed(6, 'Version check failed'),
  unknown(255, 'Unknown error');

  const FF1ResponseErrorCode(this.code, this.description);

  final int code;
  final String description;

  static FF1ResponseErrorCode fromCode(int code) {
    for (final errorCode in FF1ResponseErrorCode.values) {
      if (errorCode.code == code) {
        return errorCode;
      }
    }
    return FF1ResponseErrorCode.unknown;
  }
}

/// Base error class for FF1 device responses (error code != 0)
abstract class FF1ResponseError extends FF1Error {
  const FF1ResponseError({
    required this.title,
    required String message,
    this.shouldGoBack = false,
    this.shouldShowSupport = false,
  }) : super(message);

  final String title;
  final bool shouldGoBack;
  final bool shouldShowSupport;

  factory FF1ResponseError.fromCode(int errorCode) {
    final code = FF1ResponseErrorCode.fromCode(errorCode);
    switch (code) {
      case FF1ResponseErrorCode.wrongPassword:
        return const WrongWifiPasswordError();
      case FF1ResponseErrorCode.noInternet:
        return const WifiNoInternetError();
      case FF1ResponseErrorCode.serverUnreachable:
        return const WifiServerUnreachableError();
      case FF1ResponseErrorCode.wifiRequired:
        return const WifiRequiredError();
      case FF1ResponseErrorCode.deviceUpdating:
        return const DeviceUpdatingError();
      case FF1ResponseErrorCode.versionCheckFailed:
        return const VersionCheckFailedError();
      case FF1ResponseErrorCode.unknown:
        return UnknownWifiError(errorCode);
    }
  }
}

/// Wrong WiFi password
class WrongWifiPasswordError extends FF1ResponseError {
  const WrongWifiPasswordError()
      : super(
          title: 'Incorrect Wi-Fi password',
          message:
              "FF1 couldn't connect to Wi-Fi. The password may be incorrect. "
              'Check it and try again.',
        );
}

/// WiFi connected but no internet
class WifiNoInternetError extends FF1ResponseError {
  const WifiNoInternetError()
      : super(
          title: 'No internet access',
          message:
              "FF1 is connected to Wi-Fi but can't reach the internet. "
              'Check the router connection, then try again.',
        );
}

/// WiFi connected, internet OK, but cannot reach Feral File server
class WifiServerUnreachableError extends FF1ResponseError {
  const WifiServerUnreachableError()
      : super(
          title: "Can't reach server",
          message:
              "FF1 is online but can't reach the server. Network settings may "
              'be blocking access. Check firewall settings or try a different network.',
        );
}

/// Device requires WiFi connection
class WifiRequiredError extends FF1ResponseError {
  const WifiRequiredError()
      : super(
          title: 'Wi-Fi required',
          message: 'FF1 needs a Wi-Fi connection. Connect to a network to continue.',
        );
}

/// Device is currently updating firmware
class DeviceUpdatingError extends FF1ResponseError {
  const DeviceUpdatingError()
      : super(
          title: 'FF1 is updating',
          message:
              'FF1 is installing an update. Wait for the update to finish, '
              'then try again.',
          shouldGoBack: true,
        );
}

/// Version check failed (may need support)
class VersionCheckFailedError extends FF1ResponseError {
  const VersionCheckFailedError()
      : super(
          title: 'Setup failed',
          message:
              "FF1 couldn't complete setup. This may be related to a connection issue. "
              'Contact support for help.',
          shouldGoBack: true,
          shouldShowSupport: true,
        );
}

/// Unknown WiFi connection error
class UnknownWifiError extends FF1ResponseError {
  UnknownWifiError(this.errorCode)
      : super(
          title: 'Wi-Fi connection failed',
          message:
              "FF1 couldn't connect to Wi-Fi. The network conditions may be unstable. "
              'Move FF1 closer to the router and try again.',
        );

  final int errorCode;
}
