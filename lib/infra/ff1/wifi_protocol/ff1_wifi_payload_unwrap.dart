/// Unwraps relayer / cast API JSON (`message` / `data` nesting) to a flat map.
library;

/// Walks nested `message` and `data` keys until a leaf map is found.
///
/// Used by [FF1WifiControl] for command responses that mirror `deviceMetrics`
/// and FFP DDC payloads.
Map<String, dynamic> unwrapFf1RelayerPayload(Map<String, dynamic> response) {
  dynamic current = response;
  while (current is Map<String, dynamic>) {
    if (current.containsKey('message') && current['message'] is Map) {
      current = Map<String, dynamic>.from(current['message'] as Map);
      continue;
    }
    if (current.containsKey('data') && current['data'] is Map) {
      current = Map<String, dynamic>.from(current['data'] as Map);
      continue;
    }
    return current;
  }
  throw StateError('Invalid relayer payload type');
}
