import 'package:app/app/feed/feed_manager.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for [FeralFileFeedManager].
///
/// Holds the single feed manager instance used by the app lifecycle.
final feedManagerProvider = Provider<FeralFileFeedManager>((ref) {
  return FeralFileFeedManager(
    databaseService: ref.read(databaseServiceProvider),
    appStateService: ref.read(appStateServiceProvider),
    defaultDp1FeedUrl: AppConfig.dp1FeedUrl,
    defaultDp1FeedApiKey: AppConfig.dp1FeedApiKey,
  );
});
