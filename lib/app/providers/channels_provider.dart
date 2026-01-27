import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../domain/models/channel.dart';
import '../../infra/database/database_provider.dart';
import 'mutations.dart';

/// Enhanced state for channels with curated vs personal separation.
class ChannelsState {
  /// Creates a ChannelsState.
  const ChannelsState({
    required this.curatedChannels,
    required this.personalChannels,
    required this.isLoading,
    this.error,
  });

  /// Curated channels from DP1 feeds.
  final List<Channel> curatedChannels;

  /// Personal channels (e.g., My Collection).
  final List<Channel> personalChannels;

  /// Whether channels are being loaded.
  final bool isLoading;

  /// Error if loading failed.
  final String? error;

  /// Initial state.
  factory ChannelsState.initial() {
    return const ChannelsState(
      curatedChannels: [],
      personalChannels: [],
      isLoading: false,
    );
  }

  /// Loading state.
  factory ChannelsState.loading() {
    return const ChannelsState(
      curatedChannels: [],
      personalChannels: [],
      isLoading: true,
    );
  }

  /// Loaded state.
  factory ChannelsState.loaded({
    required List<Channel> curated,
    required List<Channel> personal,
  }) {
    return ChannelsState(
      curatedChannels: curated,
      personalChannels: personal,
      isLoading: false,
    );
  }

  /// Error state.
  factory ChannelsState.error(String error) {
    return ChannelsState(
      curatedChannels: [],
      personalChannels: [],
      isLoading: false,
      error: error,
    );
  }

  /// Copy with new values.
  ChannelsState copyWith({
    List<Channel>? curatedChannels,
    List<Channel>? personalChannels,
    bool? isLoading,
    String? error,
  }) {
    return ChannelsState(
      curatedChannels: curatedChannels ?? this.curatedChannels,
      personalChannels: personalChannels ?? this.personalChannels,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for channels list.
/// Provides reactive access to channels from the database.
class ChannelsNotifier extends Notifier<ChannelsState> {
  late final Logger _log;

  @override
  ChannelsState build() {
    _log = Logger('ChannelsNotifier');
    return ChannelsState.initial();
  }

  /// Load channels from database.
  Future<void> loadChannels() async {
    try {
      _log.info('Loading channels from database...');
      state = ChannelsState.loading();

      final databaseService = ref.read(databaseServiceProvider);
      final allChannels = await databaseService.getChannels();

      _log.info('Loaded ${allChannels.length} total channels from database');

      // Separate curated vs personal
      // Personal channels are pinned (like "My Collection")
      final curated = allChannels.where((c) => !c.isPinned).toList();
      final personal = allChannels.where((c) => c.isPinned).toList();

      _log.info('Curated channels: ${curated.length}, Personal channels: ${personal.length}');

      state = ChannelsState.loaded(curated: curated, personal: personal);
    } catch (e, stack) {
      _log.severe('Failed to load channels', e, stack);
      state = ChannelsState.error(e.toString());
    }
  }

  /// Refresh channels (re-load from database).
  Future<void> refresh() async {
    await loadChannels();
  }
}

/// Provider for channels list.
final channelsProvider = NotifierProvider<ChannelsNotifier, ChannelsState>(
  ChannelsNotifier.new,
);

/// Mutation for loading channels.
final loadChannelsMutationProvider =
    NotifierProvider<MutationNotifier<void>, MutationState<void>>(
  MutationNotifier.new,
);

/// Mutation for refreshing channels.
final refreshChannelsMutationProvider =
    NotifierProvider<MutationNotifier<void>, MutationState<void>>(
  MutationNotifier.new,
);

/// Mutation for loading more channels.
final loadMoreChannelsMutationProvider =
    NotifierProvider<MutationNotifier<void>, MutationState<void>>(
  MutationNotifier.new,
);

/// Provider for a specific channel by ID.
final channelByIdProvider =
    FutureProvider.family<Channel?, String>((ref, channelId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getChannelById(channelId);
});
