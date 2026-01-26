import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../domain/models/channel.dart';
import '../../infra/database/database_provider.dart';
import 'services_provider.dart';

/// State for channels list.
class ChannelsState {
  /// Creates a ChannelsState.
  const ChannelsState({
    required this.channels,
    required this.isLoading,
    this.error,
  });

  /// List of channels.
  final List<Channel> channels;

  /// Whether channels are being loaded.
  final bool isLoading;

  /// Error if loading failed.
  final String? error;

  /// Initial state.
  factory ChannelsState.initial() {
    return const ChannelsState(
      channels: [],
      isLoading: false,
    );
  }

  /// Loading state.
  factory ChannelsState.loading() {
    return const ChannelsState(
      channels: [],
      isLoading: true,
    );
  }

  /// Loaded state.
  factory ChannelsState.loaded(List<Channel> channels) {
    return ChannelsState(
      channels: channels,
      isLoading: false,
    );
  }

  /// Error state.
  factory ChannelsState.error(String error) {
    return ChannelsState(
      channels: [],
      isLoading: false,
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
      state = ChannelsState.loading();

      final databaseService = ref.read(databaseServiceProvider);
      final channels = await databaseService.getChannels();

      state = ChannelsState.loaded(channels);
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

/// Provider for a specific channel by ID.
final channelByIdProvider =
    FutureProvider.family<Channel?, String>((ref, channelId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getChannelById(channelId);
});
