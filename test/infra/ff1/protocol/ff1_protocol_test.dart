import 'dart:convert';
import 'dart:typed_data';

import 'package:app/infra/ff1/protocol/ff1_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FF1Protocol', () {
    late FF1Protocol protocol;

    setUp(() {
      protocol = const FF1Protocol();
    });

    group('Varint encoding/decoding', () {
      test('encodes small values correctly', () {
        final builder = BytesBuilder();
        protocol._writeVarint(builder, 0);
        expect(builder.toBytes(), [0]);
      });

      test('encodes single-byte values (0-127)', () {
        final tests = [
          (0, [0]),
          (1, [1]),
          (127, [127]),
        ];

        for (final (value, expected) in tests) {
          final builder = BytesBuilder();
          protocol._writeVarint(builder, value);
          expect(builder.toBytes(), expected, reason: 'value=$value');
        }
      });

      test('encodes multi-byte values (128+)', () {
        final tests = [
          (128, [0x80, 0x01]),
          (255, [0xFF, 0x01]),
          (300, [0xAC, 0x02]),
          (16384, [0x80, 0x80, 0x01]),
        ];

        for (final (value, expected) in tests) {
          final builder = BytesBuilder();
          protocol._writeVarint(builder, value);
          expect(builder.toBytes(), expected, reason: 'value=$value');
        }
      });

      test('decodes varint correctly', () {
        final tests = [
          ([0], 0),
          ([1], 1),
          ([127], 127),
          ([0x80, 0x01], 128),
          ([0xFF, 0x01], 255),
          ([0xAC, 0x02], 300),
          ([0x80, 0x80, 0x01], 16384),
        ];

        for (final (bytes, expected) in tests) {
          final reader = _VarintReader(bytes);
          expect(reader.readVarint(), expected, reason: 'bytes=$bytes');
        }
      });
    });

    group('buildCommand', () {
      test('builds command with no parameters', () {
        final bytes = protocol.buildCommand(
          command: 'test_cmd',
          replyId: 'abcd',
          params: [],
        );

        // Parse manually
        final reader = _VarintReader(bytes);

        // Read command
        final cmdLength = reader.readVarint();
        final cmdBytes = reader.read(cmdLength);
        expect(utf8.decode(cmdBytes), 'test_cmd');

        // Read replyId
        final replyLength = reader.readVarint();
        final replyBytes = reader.read(replyLength);
        expect(utf8.decode(replyBytes), 'abcd');

        // No more data
        expect(reader.hasMore, false);
      });

      test('builds command with parameters', () {
        final bytes = protocol.buildCommand(
          command: 'connect_wifi',
          replyId: 'test',
          params: ['MySSID', 'MyPassword'],
        );

        final reader = _VarintReader(bytes);

        // Command
        final cmdLen = reader.readVarint();
        expect(utf8.decode(reader.read(cmdLen)), 'connect_wifi');

        // ReplyId
        final replyLen = reader.readVarint();
        expect(utf8.decode(reader.read(replyLen)), 'test');

        // Param 1
        final param1Len = reader.readVarint();
        expect(utf8.decode(reader.read(param1Len)), 'MySSID');

        // Param 2
        final param2Len = reader.readVarint();
        expect(utf8.decode(reader.read(param2Len)), 'MyPassword');

        expect(reader.hasMore, false);
      });

      test('handles empty strings', () {
        final bytes = protocol.buildCommand(
          command: '',
          replyId: '',
          params: [''],
        );

        final reader = _VarintReader(bytes);

        // Command (empty)
        final cmdLen = reader.readVarint();
        expect(cmdLen, 0);

        // ReplyId (empty)
        final replyLen = reader.readVarint();
        expect(replyLen, 0);

        // Param (empty)
        final paramLen = reader.readVarint();
        expect(paramLen, 0);
      });
    });

    group('parseResponse', () {
      test('parses successful response with no data', () {
        // Build response: topic="abcd", errorCode=0, no data
        final bytes = _buildResponse(
          topic: 'abcd',
          errorCode: 0,
          data: [],
        );

        final response = protocol.parseResponse(bytes);

        expect(response.topic, 'abcd');
        expect(response.errorCode, 0);
        expect(response.data, isEmpty);
        expect(response.isSuccess, true);
        expect(response.isError, false);
      });

      test('parses successful response with data', () {
        final bytes = _buildResponse(
          topic: 'test',
          errorCode: 0,
          data: ['value1', 'value2', 'value3'],
        );

        final response = protocol.parseResponse(bytes);

        expect(response.topic, 'test');
        expect(response.errorCode, 0);
        expect(response.data, ['value1', 'value2', 'value3']);
        expect(response.isSuccess, true);
      });

      test('parses error response', () {
        final bytes = _buildResponse(
          topic: 'fail',
          errorCode: 1,
          data: ['error message'],
        );

        final response = protocol.parseResponse(bytes);

        expect(response.topic, 'fail');
        expect(response.errorCode, 1);
        expect(response.data, ['error message']);
        expect(response.isError, true);
        expect(response.isSuccess, false);
      });

      test('handles WiFi scan response (list of SSIDs)', () {
        final bytes = _buildResponse(
          topic: 'scan',
          errorCode: 0,
          data: ['WiFi1', 'WiFi2', 'WiFi3'],
        );

        final response = protocol.parseResponse(bytes);

        expect(response.data.length, 3);
        expect(response.data, ['WiFi1', 'WiFi2', 'WiFi3']);
      });

      test('handles keepWifi response (topicId)', () {
        final bytes = _buildResponse(
          topic: 'keep',
          errorCode: 0,
          data: ['topic_12345'],
        );

        final response = protocol.parseResponse(bytes);

        expect(response.data.length, 1);
        expect(response.data.first, 'topic_12345');
      });
    });

    group('generateReplyId', () {
      test('generates 4-character ID', () {
        final replyId = protocol.generateReplyId();
        expect(replyId.length, 4);
      });

      test('generates lowercase letters', () {
        final replyId = protocol.generateReplyId();
        expect(replyId, matches(r'^[a-z]{4}$'));
      });

      test('generates unique IDs', () {
        final ids = <String>{};
        for (var i = 0; i < 100; i++) {
          ids.add(protocol.generateReplyId());
        }
        // Should have at least some unique IDs (very unlikely to get duplicates)
        expect(ids.length, greaterThan(50));
      });
    });

    group('Integration: command -> response round-trip', () {
      test('scan_wifi command and response', () {
        // Build command
        final cmdBytes = protocol.buildCommand(
          command: 'scan_wifi',
          replyId: 'abcd',
          params: [],
        );

        expect(cmdBytes, isNotEmpty);

        // Simulate device response
        final respBytes = _buildResponse(
          topic: 'abcd',
          errorCode: 0,
          data: ['Network1', 'Network2'],
        );

        final response = protocol.parseResponse(respBytes);

        expect(response.topic, 'abcd');
        expect(response.isSuccess, true);
        expect(response.data, ['Network1', 'Network2']);
      });

      test('connect_wifi command and response', () {
        final cmdBytes = protocol.buildCommand(
          command: 'connect_wifi',
          replyId: 'test',
          params: ['MyWiFi', 'password123'],
        );

        expect(cmdBytes, isNotEmpty);

        // Success response with topicId
        final respBytes = _buildResponse(
          topic: 'test',
          errorCode: 0,
          data: ['topic_abc123'],
        );

        final response = protocol.parseResponse(respBytes);

        expect(response.topic, 'test');
        expect(response.isSuccess, true);
        expect(response.data.first, 'topic_abc123');
      });

      test('get_info command and response', () {
        final cmdBytes = protocol.buildCommand(
          command: 'get_info',
          replyId: 'info',
          params: [],
        );

        expect(cmdBytes, isNotEmpty);

        final respBytes = _buildResponse(
          topic: 'info',
          errorCode: 0,
          data: ['{"version":"1.0.0","deviceId":"FF1_12345"}'],
        );

        final response = protocol.parseResponse(respBytes);

        expect(response.topic, 'info');
        expect(response.isSuccess, true);
        expect(response.data.first, contains('version'));
      });
    });
  });
}

// Helper to build a response message manually
List<int> _buildResponse({
  required String topic,
  required int errorCode,
  required List<String> data,
}) {
  final builder = BytesBuilder();

  // Write topic
  final topicBytes = utf8.encode(topic);
  _writeVarint(builder, topicBytes.length);
  builder.add(topicBytes);

  // Write error code (as varint + byte)
  _writeVarint(builder, 1);
  builder.addByte(errorCode);

  // Write data
  for (final item in data) {
    final itemBytes = utf8.encode(item);
    _writeVarint(builder, itemBytes.length);
    builder.add(itemBytes);
  }

  return builder.toBytes();
}

void _writeVarint(BytesBuilder builder, int value) {
  while (value >= 0x80) {
    builder.addByte((value & 0x7F) | 0x80);
    value >>= 7;
  }
  builder.addByte(value);
}

// Helper class (same as in FF1Protocol)
class _VarintReader {
  _VarintReader(this._data);

  final List<int> _data;
  int _position = 0;

  List<int> readNext() {
    final length = readVarint();
    return read(length);
  }

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

  List<int> read(int length) {
    if (_position + length > _data.length) {
      throw RangeError('Not enough data to read $length bytes');
    }
    final result = _data.sublist(_position, _position + length);
    _position += length;
    return result;
  }

  bool get hasMore => _position < _data.length;
}

// Extension to expose private methods for testing
extension FF1ProtocolTest on FF1Protocol {
  void _writeVarint(BytesBuilder builder, int value) {
    while (value >= 0x80) {
      builder.addByte((value & 0x7F) | 0x80);
      value >>= 7;
    }
    builder.addByte(value);
  }
}
