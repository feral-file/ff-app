import 'dart:convert';

/// Decodes persisted per-device dismissed firmware latest-version map.
/// Malformed or empty [rawJson] yields an empty map.
Map<String, String> decodeDismissedFirmwareVersionsMap(String rawJson) {
  if (rawJson.isEmpty) {
    return {};
  }
  try {
    final decoded = jsonDecode(rawJson);
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
  } catch (_) {}
  return {};
}

/// Encodes [map] for persisted app-state dismissed-version JSON.
String encodeDismissedFirmwareVersionsMap(Map<String, String> map) =>
    jsonEncode(map);
