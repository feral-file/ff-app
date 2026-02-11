import 'package:app/domain/models/models.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for addresses.
///
/// Watches address-based playlists and converts them to [WalletAddress] for UI.
final addressesProvider = StreamProvider<List<WalletAddress>>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService
      .watchPlaylists(type: PlaylistType.addressBased)
      .map((playlists) {
    return playlists
        .where(
          (playlist) =>
              playlist.ownerAddress != null &&
              playlist.ownerAddress!.isNotEmpty,
        )
        .map(
          (playlist) => WalletAddress(
            address: playlist.ownerAddress!,
            name: playlist.name,
            createdAt: playlist.createdAt ?? DateTime.now(),
          ),
        )
        .toList();
  });
});
