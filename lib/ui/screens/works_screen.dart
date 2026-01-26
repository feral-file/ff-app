import 'package:app/app/providers/works_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Works list screen.
/// Shows all items (works) stored in the database.
class WorksScreen extends ConsumerWidget {
  /// Creates a WorksScreen.
  const WorksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worksAsync = ref.watch(allWorksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Works'),
      ),
      body: worksAsync.when(
        data: (works) => _buildWorksList(context, works),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(context, error),
      ),
    );
  }

  Widget _buildWorksList(BuildContext context, List<PlaylistItem> works) {
    if (works.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.image_not_supported,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'No works available',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Works will appear here after loading playlists',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Note: Dynamic playlists need to be resolved '
                'from the indexer to show items',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: works.length,
      itemBuilder: (context, index) {
        final work = works[index];
        return _WorkListTile(work: work);
      },
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, color: Colors.red.shade700, size: 48),
          const SizedBox(height: 16),
          Text(
            'Error: $error',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade700),
          ),
        ],
      ),
    );
  }
}

class _WorkListTile extends StatelessWidget {
  const _WorkListTile({required this.work});

  final PlaylistItem work;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildThumbnail(),
      title: Text(
        work.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: _buildSubtitle(),
      trailing: _buildKindBadge(),
      onTap: () => context.go('${Routes.works}/${work.id}'),
    );
  }

  Widget _buildThumbnail() {
    if (work.thumbnailUrl != null && work.thumbnailUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          work.thumbnailUrl!,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        ),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  Widget? _buildSubtitle() {
    final parts = <String>[];

    if (work.artistName != null && work.artistName!.isNotEmpty) {
      parts.add(work.artistName!);
    } else if (work.subtitle != null && work.subtitle!.isNotEmpty) {
      parts.add(work.subtitle!);
    }

    if (work.durationSec != null) {
      final duration = Duration(seconds: work.durationSec!);
      parts.add(_formatDuration(duration));
    }

    if (parts.isEmpty) return null;

    return Text(
      parts.join(' • '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildKindBadge() {
    final kindText = work.kind == PlaylistItemKind.dp1Item
        ? 'DP1'
        : 'Token';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: work.kind == PlaylistItemKind.dp1Item
            ? Colors.blue.shade100
            : Colors.green.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        kindText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: work.kind == PlaylistItemKind.dp1Item
              ? Colors.blue.shade700
              : Colors.green.shade700,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}
