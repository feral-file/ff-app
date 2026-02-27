import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final _log = Logger('PendingAddressesStore');

/// Persists wallet addresses that were added before the Drift database was
/// ready (i.e. while the seed database was still downloading on a fresh
/// install).
///
/// After the database gate opens, `app.dart` reads these addresses, creates
/// the corresponding SQLite playlists, starts address workers, then clears
/// this store.
///
/// Storage is a plain JSON file so no ObjectBox schema regeneration is needed.
class PendingAddressesStore {
  static const _fileName = 'pending_addresses.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  /// Returns the list of addresses waiting to be migrated to SQLite.
  Future<List<String>> getAddresses() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return [];
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<String>();
    } on Object catch (e, stack) {
      _log.warning('Failed to read pending addresses', e, stack);
      return [];
    }
  }

  /// Adds [address] to the pending list (deduplicated; case-insensitive for
  /// Ethereum addresses).
  Future<void> addAddress(String address) async {
    try {
      final current = await getAddresses();
      final normalised = address.trim();
      final alreadyPresent = current.any(
        (a) => a.toLowerCase() == normalised.toLowerCase(),
      );
      if (alreadyPresent) return;

      final updated = [...current, normalised];
      final file = await _file();
      await file.writeAsString(jsonEncode(updated));
      _log.info('Stored pending address: $normalised');
    } on Object catch (e, stack) {
      _log.warning('Failed to store pending address: $address', e, stack);
    }
  }

  /// Removes all pending addresses (call after successful migration).
  Future<void> clear() async {
    try {
      final file = await _file();
      if (file.existsSync()) {
        await file.delete();
      }
      _log.info('Cleared pending addresses');
    } on Object catch (e, stack) {
      _log.warning('Failed to clear pending addresses', e, stack);
    }
  }
}
