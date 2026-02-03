import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// In-memory anchor store for indexer change journal pagination.
///
/// Key: normalized address (uppercase).
/// Value: last processed anchor.
class ChangesAnchorNotifier extends Notifier<Map<String, int>> {
  late final Logger _log;

  @override
  Map<String, int> build() {
    _log = Logger('ChangesAnchorNotifier');
    return <String, int>{};
  }

  /// Get the anchor for an address.
  int? getAnchor(String address) => state[address.toUpperCase()];

  /// Update the anchor for an address.
  void setAnchor({
    required String address,
    required int anchor,
  }) {
    final key = address.toUpperCase();
    state = {...state, key: anchor};
    _log.fine('Updated anchor for $key: $anchor');
  }
}

/// Provider for tracking change anchors per address.
final changesAnchorProvider =
    NotifierProvider<ChangesAnchorNotifier, Map<String, int>>(
  ChangesAnchorNotifier.new,
);
// End of file.
