import 'package:app/app/providers/database_service_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local followed channel ids (living channels).
final followedChannelIdsProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(databaseServiceProvider).watchFollowedChannelIds();
});
