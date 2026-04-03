import 'package:app/domain/utils/work_detail_favorite_playlist_row.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowFavoritePlaylistRowOnWorkDetail', () {
    test('shows when not full screen and this work is favorited', () {
      expect(
        shouldShowFavoritePlaylistRowOnWorkDetail(
          isFullScreen: false,
          isCurrentWorkInFavorite: true,
        ),
        isTrue,
      );
    });

    test('hides when full screen even if favorited', () {
      expect(
        shouldShowFavoritePlaylistRowOnWorkDetail(
          isFullScreen: true,
          isCurrentWorkInFavorite: true,
        ),
        isFalse,
      );
    });

    test('hides when this work is not favorited', () {
      expect(
        shouldShowFavoritePlaylistRowOnWorkDetail(
          isFullScreen: false,
          isCurrentWorkInFavorite: false,
        ),
        isFalse,
      );
    });
  });
}
