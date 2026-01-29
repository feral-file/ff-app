import 'package:app/app/providers/api_retry_strategy.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider family for fetching a channel from the feed server.
///
/// Uses automatic retry with custom strategy:
/// https://riverpod.dev/docs/concepts2/retry
///
/// Example:
/// ```dart
/// final channel = await ref.watch(
///   fetchChannelProvider(channelId).future,
/// );
/// ```
final fetchChannelProvider = FutureProvider.autoDispose.family<Channel, String>(
  (ref, channelId) async {
    final service = ref.watch(dp1FeedServiceProvider);

    // Fetch the channel
    await service.fetchChannel(
      baseUrl: AppConfig.dp1FeedUrl,
      channelId: channelId,
    );

    // Return the saved channel from database
    final databaseService = ref.watch(databaseServiceProvider);
    final channel = await databaseService.getChannelById(channelId);

    if (channel == null) {
      throw Exception('Channel $channelId not found after fetch');
    }

    return channel;
  },
  // Apply custom retry strategy for network errors
  retry: apiRetryStrategy,
);

/// Provider for fetching channels from the feed server.
///
/// Uses automatic retry with custom strategy.
///
/// Returns the number of channels fetched.
final fetchChannelsProvider = FutureProvider.autoDispose<int>(
  (ref) async {
    final service = ref.watch(dp1FeedServiceProvider);

    final count = await service.fetchChannels(
      baseUrl: AppConfig.dp1FeedUrl,
      limit: 100,
    );

    return count;
  },
  // Apply custom retry strategy for network errors
  retry: apiRetryStrategy,
);

/// Provider for fetching playlists from the feed server.
///
/// Uses automatic retry with custom strategy.
///
/// Returns the number of playlists fetched.
final fetchPlaylistsProvider = FutureProvider.autoDispose<int>(
  (ref) async {
    final service = ref.watch(dp1FeedServiceProvider);

    final count = await service.fetchPlaylists(
      baseUrl: AppConfig.dp1FeedUrl,
      limit: 10,
    );

    return count;
  },
  // Apply custom retry strategy for network errors
  retry: apiRetryStrategy,
);

/// Provider family for fetching tokens by CIDs from the indexer.
///
/// Uses automatic retry with custom strategy.
final fetchTokensByCIDsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, List<String>>(
      (ref, cids) async {
        final service = ref.watch(indexerServiceProvider);

        final tokens = await service.fetchTokensByCIDs(cids: cids);

        return tokens;
      },
      // Apply custom retry strategy for network errors
      retry: apiRetryStrategy,
    );

/// Provider family for fetching tokens by owner addresses.
///
/// Uses aggressive retry strategy due to importance of user data.
final fetchTokensByAddressesProvider = FutureProvider.autoDispose
    .family<int, List<String>>(
      (ref, addresses) async {
        final service = ref.watch(indexerServiceProvider);

        final count = await service.fetchTokensForAddresses(
          addresses: addresses,
          limit: 100,
        );

        return count;
      },
      // Use aggressive retry for user data
      retry: aggressiveApiRetry,
    );
