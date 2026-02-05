/// Kind of playlist row stored in Drift.
///
/// Copied from old repo [DriftPlaylistKind].
/// Mapped to the `type` column in the Playlists table:
/// - 0: DP1 playlist from feed servers
/// - 1: Address-based playlist (e.g. under my_collection channel).
enum DriftPlaylistKind {
  dp1(0),
  address(1);

  const DriftPlaylistKind(this.value);
  final int value;
}

/// Kind of channel row stored in Drift.
///
/// Copied from old repo [DriftChannelKind].
/// Mapped to the `type` column in the Channels table:
/// - 0: DP1 channel from feed servers
/// - 1: Local virtual channel (e.g. my_collection).
enum DriftChannelKind {
  dp1(0),
  localVirtual(1);

  const DriftChannelKind(this.value);
  final int value;
}
