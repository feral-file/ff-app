import 'package:app/app/providers/release_notes_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/appbars/setup_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Release notes index screen.
class ReleaseNotesScreen extends ConsumerWidget {
  /// Creates a [ReleaseNotesScreen].
  const ReleaseNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releaseNotesAsync = ref.watch(releaseNotesListProvider);

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: const SetupAppBar(title: 'Release Notes'),
      body: releaseNotesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(
            'Could not load release notes.',
            style: AppTypography.body(context).copyWith(
              color: PrimitivesTokens.colorsWhite,
            ),
          ),
        ),
        data: (releaseNotes) {
          if (releaseNotes.isEmpty) {
            return Center(
              child: Text(
                'No release notes available.',
                style: AppTypography.body(context).copyWith(
                  color: PrimitivesTokens.colorsWhite,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.symmetric(vertical: LayoutConstants.space6),
            itemCount: releaseNotes.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              color: PrimitivesTokens.colorsBlack,
            ),
            itemBuilder: (context, index) {
              final releaseNote = releaseNotes[index];
              return ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: LayoutConstants.space5,
                  vertical: LayoutConstants.space2,
                ),
                title: Text(
                  releaseNote.date,
                  style: AppTypography.body(context).copyWith(
                    color: PrimitivesTokens.colorsWhite,
                  ),
                ),
                subtitle:
                    releaseNote.ffOsTitle != null ||
                        releaseNote.mobileAppTitle != null
                    ? Padding(
                        padding: EdgeInsets.only(top: LayoutConstants.space2),
                        child: Text(
                          [
                            if (releaseNote.ffOsTitle != null)
                              releaseNote.ffOsTitle!,
                            if (releaseNote.mobileAppTitle != null)
                              releaseNote.mobileAppTitle!,
                          ].join('\n'),
                          style: AppTypography.bodySmall(context).copyWith(
                            color: PrimitivesTokens.colorsGrey,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : null,
                trailing: const Icon(
                  Icons.chevron_right,
                  color: PrimitivesTokens.colorsGrey,
                ),
                onTap: () => context.pushNamed(
                  RouteNames.releaseNoteDetail,
                  extra: releaseNote,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
