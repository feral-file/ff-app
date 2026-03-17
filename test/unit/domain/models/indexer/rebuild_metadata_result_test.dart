import 'package:app/domain/models/indexer/rebuild_metadata_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RebuildMetadataDone', () {
    test('toJson and fromJson round-trip', () {
      const tokenMap = <String, dynamic>{
        'token_cid': 'bafy-test',
        'chain': 'eip155:1',
        'standard': 'erc721',
      };
      const done = RebuildMetadataDone(token: tokenMap);
      final json = done.toJson();
      expect(json['kind'], RebuildMetadataDone.kind);
      expect(json['token'], tokenMap);

      final parsed = RebuildMetadataResult.fromJson(json);
      expect(parsed, isA<RebuildMetadataDone>());
      expect((parsed as RebuildMetadataDone).token, tokenMap);
    });
  });

  group('RebuildMetadataFailed', () {
    test('toJson and fromJson round-trip', () {
      const failed = RebuildMetadataFailed(
        error: 'Metadata rebuild failed: workflow status FAILED',
      );
      final json = failed.toJson();
      expect(json['kind'], RebuildMetadataFailed.kind);
      expect(json['error'], 'Metadata rebuild failed: workflow status FAILED');

      final parsed = RebuildMetadataResult.fromJson(json);
      expect(parsed, isA<RebuildMetadataFailed>());
      expect((parsed as RebuildMetadataFailed).error, failed.error);
    });
  });

  group('RebuildMetadataResult.fromJson', () {
    test('parses RebuildMetadataDone when kind matches', () {
      final parsed = RebuildMetadataResult.fromJson({
        'kind': 'RebuildMetadataDone',
        'token': {'token_cid': 'x'},
      });
      expect(parsed, isA<RebuildMetadataDone>());
    });

    test('parses RebuildMetadataFailed when kind is RebuildMetadataFailed', () {
      final parsed = RebuildMetadataResult.fromJson({
        'kind': 'RebuildMetadataFailed',
        'error': 'Token not found',
      });
      expect(parsed, isA<RebuildMetadataFailed>());
      expect((parsed as RebuildMetadataFailed).error, 'Token not found');
    });

    test('parses RebuildMetadataFailed when kind is unknown', () {
      final parsed = RebuildMetadataResult.fromJson({
        'kind': 'Unknown',
        'error': 'Something went wrong',
      });
      expect(parsed, isA<RebuildMetadataFailed>());
    });
  });
}
