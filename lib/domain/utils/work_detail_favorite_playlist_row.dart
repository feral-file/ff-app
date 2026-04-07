/// Whether the Favorite playlist row appears on work detail below the preview.
///
/// The row should reflect that **this** work is in Favorites, not merely that
/// the Favorite playlist has other items.
bool shouldShowFavoritePlaylistRowOnWorkDetail({
  required bool isFullScreen,
  required bool isCurrentWorkInFavorite,
}) => !isFullScreen && isCurrentWorkInFavorite;
