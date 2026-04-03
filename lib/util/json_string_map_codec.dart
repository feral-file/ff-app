import 'dart:convert';

/// Decodes a JSON object into [Map<String, String>].
///
/// Use for persisted maps whose keys and values are both strings (e.g. app
/// state blobs). Malformed JSON, non-object payloads, or decode errors yield
/// an empty map.
Map<String, String> decodeJsonStringMap(String rawJson) {
  if (rawJson.isEmpty) {
    return {};
  }
  try {
    final decoded = jsonDecode(rawJson);
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
  } on Exception {
    return {};
  }
  return {};
}

/// Encodes [map] as a JSON object string.
String encodeJsonStringMap(Map<String, String> map) => jsonEncode(map);
