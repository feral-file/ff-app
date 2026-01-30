import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Curated DP-1 channel URLs.
///
/// Each entry should be a full channel URL like:
/// `https://example.org/api/v1/channels/ch_...`
///
/// This list is intentionally kept as a simple const so it is easy to
/// audit and update. The integration layer can later swap this to a remote
/// config source if needed.
const List<String> curatedDp1ChannelUrls = <String>[
  // TODO(feralfile): Add curated channel URLs here.
  "https://dp1-feed-operator-api-prod.autonomy-system.workers.dev/api/v1/channels/0fdd0465-217c-4734-9bfd-2d807b414482",
  "https://dp1-feed-operator-api-dev.objkt-com.workers.dev/api/v1/channels/5b467722-202d-44d2-af77-4c438c7f2258",
];

/// Provider wrapper for [curatedDp1ChannelUrls].
///
/// Tests can override this provider to inject curated channel URLs without
/// relying on compile-time constants.
final curatedDp1ChannelUrlsProvider = Provider<List<String>>((ref) {
  return curatedDp1ChannelUrls;
});
