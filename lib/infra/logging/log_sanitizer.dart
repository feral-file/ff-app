import 'dart:convert';
import 'dart:typed_data';

/// Helpers for safe, bounded logging payloads.
class LogSanitizer {
  LogSanitizer._();

  static final RegExp _sensitiveKeyPattern = RegExp(
    r'authorization|cookie|token|password|secret|api[-_]?key|signature',
    caseSensitive: false,
  );

  static const _maxDepth = 4;
  static const _maxStringLength = 200;

  static Map<String, dynamic> sanitizeMap(
    Map<String, dynamic> source, {
    int depth = 0,
  }) {
    final result = <String, dynamic>{};
    source.forEach((key, value) {
      result[key] = _sanitizeValue(key: key, value: value, depth: depth);
    });
    return result;
  }

  static Map<String, dynamic> sanitizeHeaders(Map<String, dynamic> headers) {
    return sanitizeMap(headers);
  }

  static dynamic sanitizeBody(dynamic body) {
    if (body == null) {
      return null;
    }

    if (body is Map<String, dynamic>) {
      return sanitizeMap(body);
    }

    if (body is Map) {
      return sanitizeMap(
        body.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    if (body is List) {
      return {
        'type': 'list',
        'length': body.length,
      };
    }

    if (body is String) {
      final preview = body.length > _maxStringLength
          ? '${body.substring(0, _maxStringLength)}...'
          : body;
      return {
        'type': 'string',
        'length': body.length,
        'preview': preview,
      };
    }

    if (body is Uint8List || body is List<int>) {
      final bytes = body is Uint8List
          ? body
          : Uint8List.fromList(body as List<int>);
      return sanitizeBlePayload(bytes);
    }

    return {
      'type': body.runtimeType.toString(),
      'value': _truncate(body.toString()),
    };
  }

  static Map<String, dynamic> sanitizeGraphqlVariables(
    Map<String, dynamic> vars,
  ) {
    return sanitizeMap(vars);
  }

  static Map<String, dynamic> sanitizeError(Object error) {
    return {
      'type': error.runtimeType.toString(),
      'message': _truncate(error.toString()),
    };
  }

  static Map<String, dynamic> sanitizeBlePayload(
    List<int> bytes, {
    int maxPreviewBytes = 16,
  }) {
    final length = bytes.length;
    final previewLength = length > maxPreviewBytes ? maxPreviewBytes : length;
    final preview = bytes
        .take(previewLength)
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join(' ')
        .toUpperCase();

    return {
      'length': length,
      'hexPreview': preview,
      'truncated': length > maxPreviewBytes,
    };
  }

  static dynamic _sanitizeValue({
    required String key,
    required dynamic value,
    required int depth,
  }) {
    if (_sensitiveKeyPattern.hasMatch(key)) {
      return 'REDACTED';
    }

    if (value == null || value is num || value is bool) {
      return value;
    }

    if (value is String) {
      if (_looksSensitive(value)) {
        return 'REDACTED';
      }
      return _truncate(value);
    }

    if (depth >= _maxDepth) {
      return '<max-depth>';
    }

    if (value is Map<String, dynamic>) {
      return sanitizeMap(value, depth: depth + 1);
    }

    if (value is Map) {
      return sanitizeMap(
        value.map((k, v) => MapEntry(k.toString(), v)),
        depth: depth + 1,
      );
    }

    if (value is List) {
      final preview = value
          .take(5)
          .map(
            (item) => _sanitizeValue(key: key, value: item, depth: depth + 1),
          )
          .toList();
      return {
        'type': 'list',
        'length': value.length,
        'preview': preview,
      };
    }

    return _truncate(value.toString());
  }

  static bool _looksSensitive(String value) {
    if (value.length > 20 &&
        (value.startsWith('Bearer ') || value.contains('.'))) {
      return true;
    }

    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return sanitizeMap(decoded).values.any((v) => v == 'REDACTED');
      }
    } on Object {
      // Ignore decode errors.
    }
    return false;
  }

  static String _truncate(String value) {
    if (value.length <= _maxStringLength) {
      return value;
    }
    return '${value.substring(0, _maxStringLength)}...';
  }
}
