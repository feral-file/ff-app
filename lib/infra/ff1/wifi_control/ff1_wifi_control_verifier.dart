import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';

/// True when a relayer command response reports success.
bool ff1CommandResponseIsOk(FF1CommandResponse response) {
  final status = response.status?.trim().toLowerCase();
  return status == 'ok';
}

/// Resolves command success using the explicit payload flag when present.
///
/// Some relayer responses include both `status: ok` and `ok: false`. When that
/// happens the nested `ok` flag is the authoritative result because it carries
/// the command-level accept/reject outcome.
bool ff1CommandResponseSucceeded(FF1CommandResponse response) {
  return ff1CommandResponseOkFlag(response) ?? ff1CommandResponseIsOk(response);
}

/// Extracts nested `ok` flag from command response payload when present.
bool? ff1CommandResponseOkFlag(FF1CommandResponse response) {
  final data = response.data;
  if (data == null) {
    return null;
  }
  return _extractOkFlag(data);
}

/// True when command response contains an explicit `ok` flag.
bool ff1CommandResponseHasOkFlag(FF1CommandResponse response) {
  return ff1CommandResponseOkFlag(response) != null;
}

/// True when device status includes at least one signal field.
bool ff1DeviceStatusHasSignal(FF1DeviceStatus? status) {
  if (status == null) {
    return false;
  }
  return (status.connectedWifi?.trim().isNotEmpty ?? false) ||
      status.internetConnected != null ||
      (status.installedVersion?.trim().isNotEmpty ?? false) ||
      (status.latestVersion?.trim().isNotEmpty ?? false);
}

bool? _extractOkFlag(Map<String, dynamic> payload) {
  final directOk = payload['ok'];
  if (directOk is bool) {
    return directOk;
  }

  final nestedMessage = payload['message'];
  if (nestedMessage is Map) {
    return _extractOkFlag(Map<String, dynamic>.from(nestedMessage));
  }

  return null;
}
