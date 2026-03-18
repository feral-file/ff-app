# Seed Sync Race Condition — Suggested Solution

## Problem

When two syncs run concurrently (e.g. startup sync + Forget I Exist), both can:

1. **beforeReplace** — call `setNotReady` → close DB, delete files (race: double close, double delete)
2. **replaceDatabaseFromTemporaryFile** — delete canonical DB, rename temp to canonical (race: one can overwrite the other’s result)

Result: non-deterministic DB state, possible crashes or corruption.

## Solution: Serialize Replace Phase in `SeedDatabaseSyncService`

Use a lock so only one sync can run the replace phase at a time:

**Critical section:** `beforeReplace` → `replaceDatabaseFromTemporaryFile` → `afterReplace`

**Outside lock:** ETag check, download (can run concurrently; each uses its own temp file).

### Implementation

```dart
// seed_database_sync_service.dart
import 'package:synchronized/synchronized.dart';

class SeedDatabaseSyncService {
  // ...
  final _replaceLock = Lock();

  Future<bool> sync({...}) async {
    try {
      // ... ETag check, shouldDownload logic ...

      onDownloadStarted?.call(...);

      // Download outside lock — multiple downloads can run concurrently
      final tempPath = await _seedDatabaseService.downloadToTemporaryFile(
        onProgress: onProgress,
      );

      // Critical section: only one sync at a time
      await _replaceLock.synchronized(() async {
        await beforeReplace();
        await _seedDatabaseService.replaceDatabaseFromTemporaryFile(tempPath);

        if (remoteEtag != null && remoteEtag.isNotEmpty) {
          _saveLocalEtag(remoteEtag);
        }

        await afterReplace();
      });

      _log.info(...);
      return true;
    } on ... {
      // ...
    }
  }
}
```

### Flow

| Sync A (startup) | Sync B (Forget I Exist) |
|------------------|-------------------------|
| ETag check | ETag check |
| Download to temp A | Download to temp B |
| Acquire lock | (wait) |
| beforeReplace | |
| replace(temp A) | |
| afterReplace | |
| Release lock | Acquire lock |
| Return (session overridden) | beforeReplace |
| | replace(temp B) |
| | afterReplace |
| | Release lock |
| | Return (session active) |

- Session A: inactive → no state/UI updates.
- Session B: active → updates state.
- Replace phase: only one runs at a time → no race.

### Trade-offs

- **Pros:** Simple, avoids race, uses existing `synchronized` package.
- **Cons:** Two downloads can run concurrently (extra bandwidth). The inactive session’s download is wasted but acceptable.

### Alternative: Serialize Entire `sync()` in `SeedDatabaseSyncService`

If you want to avoid any concurrent downloads:

```dart
final _syncLock = Lock();

Future<bool> sync({...}) async {
  return _syncLock.synchronized(() async {
    // ... entire sync logic ...
  });
}
```

- **Pros:** No concurrent downloads.
- **Cons:** New sync waits for the old one to finish before starting. Override behavior is unchanged (session still active/inactive), but the new sync is delayed.

### Recommendation

Use the **replace-phase lock** only. It fixes the race and keeps the new sync starting immediately. Extra download for the overridden session is usually acceptable.
