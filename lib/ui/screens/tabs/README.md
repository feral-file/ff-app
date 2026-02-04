# Tab Pages Implementation - Riverpod Architecture

This directory contains the tab pages for the main home screen, implementing Riverpod best practices for performance optimization.

## Architecture

### Tabs
- **PlaylistsTabPage**: Displays curated and personal playlists
- **ChannelsTabPage**: Displays curated and personal channels
- **WorksTabPage**: Grid view of all works with pagination
- **SearchTabPage**: Search across channels, playlists, and works

## Performance Optimizations

### Selective Watching with `select`

All tab pages implement Riverpod's `select` pattern to minimize unnecessary rebuilds. This follows the official guidance: https://riverpod.dev/docs/how_to/select

#### Why use `select`?

By default, `ref.watch(provider)` rebuilds the widget whenever **any** property of the state changes. Using `select`, we only rebuild when **specific properties** change.

**Example from PlaylistsTabPage:**

```dart
// Watch per type (curated = dp1, personal = addressBased)
final curatedState = ref.watch(playlistsProvider(PlaylistType.dp1));
final personalState = ref.watch(playlistsProvider(PlaylistType.addressBased));
final curatedPlaylists = curatedState.playlists;
final personalPlaylists = personalState.playlists;
```

### Benefits

1. **Fewer rebuilds**: Widgets only rebuild when data they display actually changes
2. **Better performance**: Reduces unnecessary UI redraws
3. **Clearer intent**: Explicitly shows what data the widget depends on

### Implementation Pattern

Each tab page follows this pattern:

```dart
@override
Widget build(BuildContext context) {
  // Select only the fields we need
  final isLoading = ref.watch(provider.select((s) => s.isLoading));
  final error = ref.watch(provider.select((s) => s.error));
  final data = ref.watch(provider.select((s) => s.data));
  
  // Use selected fields in UI
  if (isLoading) return LoadingView();
  if (error != null) return ErrorView(error);
  return DataView(data);
}
```

## Data Loading Flow

### Initial Load
1. Tab page calls mutation: `loadMutation.run(() => notifier.load())`
2. Notifier fetches data from database/API
3. State updates trigger selective rebuilds
4. UI displays data

### Pull-to-Refresh
1. User pulls down to refresh
2. `RefreshIndicator` triggers `onRefresh` callback
3. Mutation tracks refresh state
4. Notifier reloads data
5. UI updates when complete

### Load More (Pagination)
1. Scroll listener detects near end of list
2. Checks `hasMore` flag and loading state
3. Triggers load more mutation
4. Appends new data to existing list
5. Shows loading indicator at bottom

## Mutation States

Mutations track async operation states:
- `MutationIdle`: Not started
- `MutationPending`: Loading (show progress indicator)
- `MutationSuccess`: Completed successfully
- `MutationError`: Failed (show error message)

## State Management

### Provider Structure

```
Provider (Notifier)
  ├─ State class with multiple fields
  │  ├─ data: List<T>
  │  ├─ isLoading: bool
  │  └─ error: String?
  └─ Notifier methods
     ├─ load()
     ├─ refresh()
     └─ loadMore()
```

### Mutation Providers

Each data operation has a corresponding mutation provider:
- `loadPlaylistsMutationProvider`
- `refreshPlaylistsMutationProvider`
- `loadMorePlaylistsMutationProvider`

## UI Patterns

### Loading State
```dart
if (isLoading && data.isEmpty) {
  return Center(child: CircularProgressIndicator());
}
```

### Error State
```dart
if (error != null && data.isEmpty) {
  return ErrorView(
    error: error,
    onRetry: () => notifier.load(),
  );
}
```

### Empty State
```dart
if (data.isEmpty) {
  return EmptyStateView(
    icon: Icons.inbox,
    message: 'No items yet',
  );
}
```

### Load More Indicator
```dart
if (loadMoreMutation.isPending) {
  return SliverToBoxAdapter(
    child: Center(child: CircularProgressIndicator()),
  );
}
```

## DP-1 Terminology

Following the vocabulary rules, we use only canonical domain terms:
- **Channel**: Feed of playlists
- **Playlist**: Collection of works
- **Work**: Individual art piece (displayed as PlaylistItem in code)

No custom object types like "Exhibition", "Season", or "Program" - these are playlist roles only.

## Testing

All tab pages support:
- Provider overrides for unit testing
- Fake data injection via overrides
- Mutation state verification
- Scroll behavior testing

## Related Files

- `lib/app/providers/playlists_provider.dart` - Playlists state management
- `lib/app/providers/channels_provider.dart` - Channels state management
- `lib/app/providers/works_provider.dart` - Works state management
- `lib/app/providers/search_provider.dart` - Search functionality
- `lib/app/providers/mutations.dart` - Mutation pattern implementation
