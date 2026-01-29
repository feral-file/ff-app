import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// FF1 BLE Protocol: message encoding/decoding with varint length prefixes
///
/// This implements the wire protocol for FF1 device communication:
/// - Commands: [varint][command][varint][replyId][varint][param1]...[varint][paramN]
/// - Responses: [varint][topic][varint+byte][errorCode][varint][data1]...[varint][dataN]
///
/// Separation: Protocol layer only deals with encoding/decoding. Transport layer
/// handles BLE characteristic reads/writes. Control layer orchestrates commands.

/// FF1 BLE protocol codec for encoding commands and decoding responses
class FF1BleProtocol {
  const FF1BleProtocol();

  /// Build a command message
  ///
  /// Format: [varint len][command][varint len][replyId][varint len][param1]...
  ///
  /// [command] - command name (e.g. "connect_wifi", "scan_wifi", "get_info")
  /// [replyId] - 4-character ASCII reply ID for matching responses
  /// [params] - list of parameter values (encoded as strings)
  Uint8List buildCommand({
    required String command,
    required String replyId,
    required List<String> params,
  }) {
    final builder = BytesBuilder();

    // Write command
    final commandBytes = utf8.encode(command);
    _writeVarint(builder, commandBytes.length);
    builder.add(commandBytes);

    // Write replyId
    final replyIdBytes = utf8.encode(replyId);
    _writeVarint(builder, replyIdBytes.length);
    builder.add(replyIdBytes);

    // Write parameters
    for (final param in params) {
      final paramBytes = utf8.encode(param);
      _writeVarint(builder, paramBytes.length);
      builder.add(paramBytes);
    }

    return builder.takeBytes();
  }

  /// Parse a response message
  ///
  /// Format: [varint len][topic][varint+byte][errorCode][varint len][data1]...
  ///
  /// Returns a [FF1BleResponse] with topic, errorCode, and data list
  FF1BleResponse parseResponse(List<int> bytes) {
    final reader = _VarintReader(bytes);

    // Read topic (reply ID)
    final topicBytes = reader.readNext();
    final topic = utf8.decode(topicBytes);

    // Read error code (next varint + first byte of data)
    final errorCodeBytes = reader.readNext();
    final errorCode = errorCodeBytes.isNotEmpty ? errorCodeBytes.first : 0;

    // Read remaining data chunks
    final data = <String>[];
    try {
      while (reader.hasMore) {
        final length = reader.readVarint();
        final chunk = reader.read(length);
        try {
          data.add(utf8.decode(chunk));
        } catch (_) {
          // Ignore invalid UTF-8 chunks
        }
      }
    } catch (_) {
      // End of data
    }

    return FF1BleResponse(
      topic: topic,
      errorCode: errorCode,
      data: data,
    );
  }

  /// Generate a random 4-character alphanumeric reply ID
  String generateReplyId() {
    final random = Random();
    return String.fromCharCodes(
      List.generate(4, (_) => random.nextInt(26) + 97), // a-z
    );
  }

  // Varint encoding: encode int as variable-length bytes (LSB first, MSB = continue bit)
  void _writeVarint(BytesBuilder builder, int value) {
    while (value >= 0x80) {
      builder.addByte((value & 0x7F) | 0x80);
      value >>= 7;
    }
    builder.addByte(value);
  }
}

/// Parsed FF1 BLE response
class FF1BleResponse {
  const FF1BleResponse({
    required this.topic,
    required this.errorCode,
    required this.data,
  });

  /// Reply topic (matches the replyId sent in command)
  final String topic;

  /// Error code (0 = success, non-zero = error)
  final int errorCode;

  /// Response data chunks (list of strings)
  final List<String> data;

  bool get isSuccess => errorCode == 0;
  bool get isError => errorCode != 0;

  @override
  String toString() =>
      'FF1BleResponse(topic: $topic, errorCode: $errorCode, data: $data)';
}

/// Varint reader for parsing FF1 BLE responses
class _VarintReader {
  _VarintReader(this._data);

  final List<int> _data;
  int _position = 0;

  /// Read a varint-prefixed chunk (reads length, then bytes)
  List<int> readNext() {
    final length = readVarint();
    return read(length);
  }

  /// Read a single varint integer
  int readVarint() {
    var result = 0;
    var shift = 0;

    while (_position < _data.length) {
      final byte = _data[_position++];
      result |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) break;
      shift += 7;
    }

    return result;
  }

  /// Read exactly [length] bytes
  List<int> read(int length) {
    if (_position + length > _data.length) {
      throw RangeError('Not enough data to read $length bytes');
    }
    final result = _data.sublist(_position, _position + length);
    _position += length;
    return result;
  }

  /// Check if more data is available
  bool get hasMore => _position < _data.length;
}
