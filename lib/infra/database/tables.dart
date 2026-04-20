import 'package:drift/drift.dart';

/// Publishers table.
/// A publisher can own multiple channels.
@DataClassName('PublisherData')
class Publishers extends Table {
  /// Publisher identifier.
  IntColumn get id => integer()();

  /// Publisher display name.
  TextColumn get title => text()();

  /// Creation timestamp in microseconds.
  Int64Column get createdAtUs => int64()();

  /// Last update timestamp in microseconds.
  Int64Column get updatedAtUs => int64()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Channels table.
/// Stores DP1 channels and local virtual channels.
@DataClassName('ChannelData')
class Channels extends Table {
  /// Channel identifier (DP-1 ID like ch_*).
  TextColumn get id => text()();

  /// Channel type: 0 = DP1, 1 = local virtual, 2 = living (registry/catalog).
  IntColumn get type => integer()();

  /// HTTP ETag from last successful single-resource GET (nullable).
  TextColumn get etag => text().nullable()();

  /// Feed server base URL for DP1 channels.
  TextColumn get baseUrl => text().nullable()();

  /// URL-friendly identifier.
  TextColumn get slug => text().nullable()();

  /// Publisher reference.
  IntColumn get publisherId =>
      integer().nullable().references(Publishers, #id)();

  /// Channel title.
  TextColumn get title => text()();

  /// Curator name.
  TextColumn get curator => text().nullable()();

  /// Channel description.
  TextColumn get summary => text().nullable()();

  /// Cover image URL.
  TextColumn get coverImageUri => text().nullable()();

  /// Creation timestamp in microseconds.
  Int64Column get createdAtUs => int64()();

  /// Last update timestamp in microseconds.
  Int64Column get updatedAtUs => int64()();

  /// Display order.
  IntColumn get sortOrder => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Playlists table.
/// Stores DP1 playlists and address-based playlists.
@DataClassName('PlaylistData')
class Playlists extends Table {
  /// Playlist identifier (DP-1 ID like pl_*).
  TextColumn get id => text()();

  /// Reference to Channels table.
  TextColumn get channelId => text().nullable()();

  /// Playlist type: 0 = DP1, 1 = address-based.
  IntColumn get type => integer()();

  /// Feed server base URL for DP1 playlists.
  TextColumn get baseUrl => text().nullable()();

  /// DP1 protocol version.
  TextColumn get dpVersion => text().nullable()();

  /// URL-friendly identifier.
  TextColumn get slug => text().nullable()();

  /// Playlist title.
  TextColumn get title => text()();

  /// Creation timestamp in microseconds.
  Int64Column get createdAtUs => int64()();

  /// Last update timestamp in microseconds.
  Int64Column get updatedAtUs => int64()();

  /// Legacy single-signature string (v1.0.x), e.g. `ed25519:<hex>`.
  TextColumn get signature => text().nullable()();

  /// DP-1 v1.1.0 `signatures` array as JSON (list of signature objects).
  TextColumn get signatures => text().withDefault(const Constant('[]'))();

  /// DP1 defaults configuration.
  TextColumn get defaultsJson => text().nullable()();

  /// Dynamic query configuration for fetching tokens.
  TextColumn get dynamicQueriesJson => text().nullable()();

  /// Owner address for address-based playlists (uppercase).
  TextColumn get ownerAddress => text().nullable()();

  /// Blockchain type (e.g., "ETH", "BTC").
  TextColumn get ownerChain => text().nullable()();

  /// Sort mode: 0 = position-based, 1 = provenance-based.
  IntColumn get sortMode => integer()();

  /// Number of items in the playlist.
  IntColumn get itemCount => integer().withDefault(const Constant(0))();

  /// HTTP ETag from last successful single-resource GET (nullable).
  TextColumn get etag => text().nullable()();

  /// DP-1 playlist-level `note.text` (nullable).
  TextColumn get playlistNoteText => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Rows for channels the user follows (living channels); local-only,
/// no sync server.
@DataClassName('FollowedChannelData')
class FollowedChannels extends Table {
  /// References [Channels.id].
  TextColumn get channelId => text().references(Channels, #id)();

  /// When the user tapped Follow.
  Int64Column get followedAtUs => int64()();

  /// Last successful poll attempt (nullable).
  Int64Column get lastPolledAtUs => int64().nullable()();

  /// Red-dot / unseen update flag for this session (also cleared on app detach).
  IntColumn get hasUnseenUpdate =>
      integer().withDefault(const Constant(0))();

  /// After first successful poll, we emit update toasts (avoids noise right
  /// after Follow).
  IntColumn get initialPollDone =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {channelId};
}

/// Items table.
/// Stores unique playlist items (DP1 items and indexer tokens).
/// This corresponds to "Works" in the domain layer.
@DataClassName('ItemData')
class Items extends Table {
  /// Item identifier (CID for tokens, DP1 item ID for DP1 items).
  TextColumn get id => text()();

  /// Item kind: 0 = DP1 item, 1 = indexer token.
  IntColumn get kind => integer()();

  // Lite UI fields for quick display
  /// Display title.
  TextColumn get title => text().nullable()();

  /// Thumbnail image URL.
  TextColumn get thumbnailUri => text().nullable()();

  /// Duration in seconds.
  IntColumn get durationSec => integer().nullable()();

  /// Provenance data as JSON.
  TextColumn get provenanceJson => text().nullable()();

  // DP1 fields
  /// Source URI.
  TextColumn get sourceUri => text().nullable()();

  /// Reference URI.
  TextColumn get refUri => text().nullable()();

  /// License information.
  TextColumn get license => text().nullable()();

  /// Reproduction data as JSON.
  TextColumn get reproJson => text().nullable()();

  /// Override configuration as JSON.
  TextColumn get overrideJson => text().nullable()();

  /// Display configuration as JSON.
  TextColumn get displayJson => text().nullable()();

  /// List of artists as JSON (list of DP1Artist).
  TextColumn get listArtistJson => text().nullable()();

  /// Enrichment status: 0 = pending, 1 = enriched, 2 = failed.
  IntColumn get enrichmentStatus => integer().withDefault(const Constant(0))();

  /// Last update timestamp in microseconds.
  Int64Column get updatedAtUs => int64()();

  @override
  Set<Column> get primaryKey => {id};
}

/// PlaylistEntries table.
/// Join table for playlist membership with per-playlist ordering.
@DataClassName('PlaylistEntryData')
class PlaylistEntries extends Table {
  /// Reference to Playlists table.
  TextColumn get playlistId => text()();

  /// Reference to Items table.
  TextColumn get itemId => text()();

  /// Position in playlist (for position-based sorting).
  IntColumn get position => integer().nullable()();

  /// Sort key in microseconds (for provenance-based sorting).
  Int64Column get sortKeyUs => int64()();

  /// Last update timestamp in microseconds.
  Int64Column get updatedAtUs => int64()();

  @override
  Set<Column> get primaryKey => {playlistId, itemId};
}
