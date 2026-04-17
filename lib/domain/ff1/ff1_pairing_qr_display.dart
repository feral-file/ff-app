/// Whether the Chromium UI `displayUrl` indicates the pairing QR step is shown.
///
/// [displayUrl] must be non-empty; call only when device status includes a
/// non-empty `displayURL` from the relayer.
///
/// True when the `step` query parameter (main URL or hash fragment) contains
/// `qr` (case-insensitive), e.g. `qrcode` or `pairingQr`.
bool isPairingQrStepInDisplayUrl(String displayUrl) {
  assert(displayUrl.isNotEmpty, 'displayUrl must be non-empty');
  final uri = Uri.tryParse(displayUrl);
  if (uri == null) {
    return false;
  }
  if (_stepValueIndicatesQr(uri.queryParameters['step'])) {
    return true;
  }
  // Hash-routed SPAs often put query parameters in [Uri.fragment] (e.g.
  // `#/path?step=qrcode`).
  final fragment = uri.fragment;
  if (fragment.isEmpty) {
    return false;
  }
  final q = fragment.indexOf('?');
  if (q < 0 || q >= fragment.length - 1) {
    return false;
  }
  final params = Uri.splitQueryString(fragment.substring(q + 1));
  return _stepValueIndicatesQr(params['step']);
}

bool _stepValueIndicatesQr(String? step) {
  if (step == null || step.isEmpty) {
    return false;
  }
  return step.toLowerCase().contains('qr');
}
