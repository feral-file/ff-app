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
  String? mainStep;
  try {
    mainStep = uri.queryParameters['step'];
  } on FormatException {
    // Ignore malformed main query and keep trying the fragment query because
    // hash-routed URLs may still carry a valid `step` value.
  }
  if (_stepValueIndicatesQr(mainStep)) {
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
  try {
    final params = Uri.splitQueryString(fragment.substring(q + 1));
    return _stepValueIndicatesQr(params['step']);
  } on FormatException {
    // Relayer payloads are external input; malformed fragment query encoding
    // should be treated as non-QR instead of crashing UI sync.
    return false;
  }
}

bool _stepValueIndicatesQr(String? step) {
  if (step == null || step.isEmpty) {
    return false;
  }
  return step.toLowerCase().contains('qr');
}
