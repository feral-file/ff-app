import 'package:app/app/providers/now_displaying_provider.dart';
import 'package:app/domain/models/now_displaying_object.dart';

/// When FF1 is playing [workId] (not sleeping), returns the active
/// [DP1NowDisplayingObject]. Otherwise null.
///
/// Same rules as the work-detail back layer (thumbnail + controls vs preview).
DP1NowDisplayingObject? dp1NowDisplayingIfPlayingThisWork({
  required NowDisplayingStatus nowDisplaying,
  required String workId,
}) {
  if (nowDisplaying is! NowDisplayingSuccess) return null;
  final obj = nowDisplaying.object;
  if (obj is! DP1NowDisplayingObject) return null;
  if (obj.isSleeping) return null;
  if (obj.currentItem.id != workId) return null;
  return obj;
}
