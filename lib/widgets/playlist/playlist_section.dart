import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/widgets/playlist/playlist_list_row.dart';
import 'package:app/widgets/playlist/playlist_section_header.dart';
import 'package:flutter/material.dart';

/// Playlist Section - Combines header with list of playlist rows.
/// Uses domain [Playlist] only.
class PlaylistSection extends StatefulWidget {
  /// Creates a PlaylistSection.
  const PlaylistSection({
    required this.sectionName,
    required this.playlists,
    this.sectionIcon,
    this.onViewAllTap,
    this.onPlaylistItemTap,
    this.scrollController,
    this.hasMore = true,
    this.isActive = true,
    this.playlistHeaderBuilder,
    super.key,
  });

  /// Section name to display.
  final String? sectionName;

  /// List of playlists to display (domain).
  final List<Playlist> playlists;

  /// Optional icon widget for section header.
  final Widget? sectionIcon;

  /// Callback when "View All" is tapped.
  final VoidCallback? onViewAllTap;

  /// Callback when a playlist item is tapped.
  final void Function(PlaylistItem item)? onPlaylistItemTap;

  /// Optional scroll controller for carousel.
  final ScrollController? scrollController;

  /// Whether there are more playlists to view.
  final bool hasMore;

  /// Whether rows should actively listen to providers.
  final bool isActive;

  /// Optional custom header builder for playlist rows.
  final Widget? Function(Playlist playlist, int itemCount)?
  playlistHeaderBuilder;

  @override
  State<PlaylistSection> createState() => _PlaylistSectionState();
}

class _PlaylistSectionState extends State<PlaylistSection> {
  @override
  void didUpdateWidget(PlaylistSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only rebuild if playlists data actually changed
    if (oldWidget.playlists != widget.playlists ||
        oldWidget.hasMore != widget.hasMore ||
        oldWidget.sectionName != widget.sectionName) {
      // State will rebuild automatically
    }
  }

  @override
  Widget build(BuildContext context) {
    final headerOffset = widget.sectionName == null ? 0 : 1;
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount:
          headerOffset +
          (widget.playlists.isNotEmpty ? widget.playlists.length : 0),
      itemBuilder: (context, index) {
        // Header
        if (index == headerOffset - 1) {
          return Column(
            children: [
              PlaylistSectionHeader(
                sectionName: widget.sectionName ?? '',
                sectionIcon: widget.sectionIcon,
                onViewAllTap: widget.hasMore ? widget.onViewAllTap : null,
                hasMore: widget.hasMore,
              ),
              SizedBox(height: LayoutConstants.space3),
            ],
          );
        }

        // List items
        final playlistIndex = index - headerOffset;
        final playlist = widget.playlists[playlistIndex];
        return PlaylistRowItem(
          playlist: playlist,
          playlistCreator: _getCreatorName(playlist),
          isActive: widget.isActive,
          onItemTap: widget.onPlaylistItemTap,
          scrollController: widget.scrollController,
          headerBuilder: widget.playlistHeaderBuilder == null
              ? null
              : (p, itemCount) =>
                    widget.playlistHeaderBuilder?.call(p, itemCount),
        );
      },
    );
  }

  /// Get creator name for a playlist (domain).
  String _getCreatorName(Playlist playlist) {
    if (playlist.type == PlaylistType.addressBased &&
        playlist.ownerAddress != null) {
      final address = playlist.ownerAddress!;
      if (address.length > 10) {
        return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
      }
      return address;
    }
    return '';
  }
}
