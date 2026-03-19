import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/domain/models/wallet_address.dart';
import 'package:app/domain/utils/address_deduplication.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:uuid/uuid.dart';

/// Favorite playlist ID (always present for every user).
const String favoritePlaylistId = Playlist.favoriteId;

/// Convenience extensions for [Playlist].
extension PlaylistExt on Playlist {
  /// Creates a minimal DP1 playlist for a single work (playlist item).
  /// Use when casting a single work to FF1.
  static Playlist fromPlaylistItem(
    List<PlaylistItem> items, {
    String? name,
    String? description,
  }) {
    final id = const Uuid().v4();
    return Playlist(
      id: id,
      name: name ?? 'Works',
      description: description,
      type: PlaylistType.dp1,
      playlistSource: PlaylistSource.global,
      itemCount: items.length,
    );
  }

  /// Returns true if this playlist is address-based (user's wallet collection).
  bool get isAddressPlaylist => type == PlaylistType.addressBased;

  // Get the playlist id for an address-based playlist
  static String addressPlaylistId(String ownerAddress) {
    final chain = Chain.fromAddress(ownerAddress).toString();
    final normalizedAddress = ownerAddress.toNormalizedAddress();
    return 'addr:$chain:$normalizedAddress';
  }

  /// Creates an address-based playlist from a [WalletAddress].
  /// Use this to generate the playlist structure before persisting.
  static Playlist fromWalletAddress(
    WalletAddress walletAddress, {
    String channelId = Channel.myCollectionId,
    String? name,
  }) {
    final chain = walletAddress.chain;
    final normalizedAddress = walletAddress.address.toNormalizedAddress();
    final now = DateTime.now();

    final dynamicQueries = [
      DynamicQuery(
        endpoint: '${AppConfig.indexerApiUrl}/graphql',
        params: DynamicQueryParams(
          owners: [normalizedAddress],
        ),
      ),
    ];

    return Playlist(
      id: addressPlaylistId(walletAddress.address),
      name: name ?? walletAddress.name,
      type: PlaylistType.addressBased,
      channelId: channelId,
      ownerAddress: normalizedAddress,
      ownerChain: chain,
      ownerName: walletAddress.name,
      sortMode: PlaylistSortMode.provenance,
      createdAt: now,
      updatedAt: now,
      dynamicQueries: dynamicQueries,
    );
  }
}
