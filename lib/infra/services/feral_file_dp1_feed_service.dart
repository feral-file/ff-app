import 'package:app/infra/services/dp1_feed_with_channel_extension_service_impl.dart';

/// DP1 feed service for Feral File endpoints.
class FeralFileDP1FeedService extends DP1FeedWithChannelExtensionServiceImpl {
  /// Creates a FeralFileDP1FeedService.
  FeralFileDP1FeedService({
    required super.baseUrl,
    required super.databaseService,
    required super.appStateService,
    required super.apiKey,
    super.isExternalFeedService,
    super.dio,
  });
}
