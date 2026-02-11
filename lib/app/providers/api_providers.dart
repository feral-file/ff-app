import 'package:app/app/providers/api_retry_strategy.dart';
import 'package:app/app/providers/indexer_provider.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
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

/// Provider family for fetching tokens by CIDs from the indexer.
///
/// Uses automatic retry with custom strategy.
final fetchTokensByCIDsProvider = FutureProvider.autoDispose
    .family<List<AssetToken>, List<String>>(
      (ref, cids) async {
        final service = ref.watch(indexerServiceProvider);

        final tokens = await service.fetchTokensByCIDs(tokenCids: cids);

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
        final service = ref.watch(indexerSyncServiceProvider);

        final count = await service.syncTokensForAddresses(
          addresses: addresses,
          limit: 100,
        );

        return count;
      },
      // Use aggressive retry for user data
      retry: aggressiveApiRetry,
    );
