import 'package:synchronized/synchronized.dart';

final Map<String, Lock> _addressTokenSyncLocks = <String, Lock>{};

/// Returns the shared per-address lock for owner list-token sync.
///
/// Address token catch-up can be entered through multiple service entrypoints.
/// They must serialize same-address runs so an older fetch cannot overwrite a
/// newer cursor clear or completion.
Lock addressTokensSyncLock(String normalizedAddress) =>
    _addressTokenSyncLocks.putIfAbsent(normalizedAddress, Lock.new);
