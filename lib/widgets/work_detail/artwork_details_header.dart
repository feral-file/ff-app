import 'package:app/design/content_rhythm.dart';
import 'package:flutter/material.dart';

/// Header for work/artwork detail: title and optional subtitle (e.g. artist).
/// Matches old repo ArtworkDetailsHeader layout.
class ArtworkDetailsHeader extends StatelessWidget {
  const ArtworkDetailsHeader({
    required this.title,
    required this.subTitle,
    super.key,
    this.hideArtist = false,
    this.onTitleTap,
    this.onSubTitleTap,
    this.color,
  });

  final String title;
  final String subTitle;
  final bool hideArtist;
  final VoidCallback? onTitleTap;
  final VoidCallback? onSubTitleTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideArtist && subTitle.isNotEmpty)
          GestureDetector(
            onTap: onSubTitleTap,
            child: Text(
              subTitle,
              style: ContentRhythm.supporting(context).copyWith(
                fontStyle: FontStyle.italic,
                color: color ?? Colors.white,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        GestureDetector(
          onTap: onTitleTap,
          child: Text(
            title,
            style: ContentRhythm.title(context).copyWith(
              fontWeight: FontWeight.bold,
              color: color ?? Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
