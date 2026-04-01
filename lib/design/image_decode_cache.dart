/// Returns decode width or height in pixels for a widget laid out at
/// [logicalSize] logical pixels, using [devicePixelRatio] (typically from
/// `MediaQuery`).
///
/// Use for `memCacheWidth` / `memCacheHeight` on cached network images so
/// decoded bitmaps match on-screen physical pixels. A fixed 2× multiplier
/// under-decodes on 3× screens and causes upscaling blur.
int decodePixelsForLogicalSize(
  double logicalSize,
  double devicePixelRatio,
) {
  return (logicalSize * devicePixelRatio).round();
}
