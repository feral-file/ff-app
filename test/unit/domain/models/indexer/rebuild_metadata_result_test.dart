import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/indexer/rebuild_metadata_result.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal token map matching AssetToken.toJson() output (cid-based).
Map<String, dynamic> _minimalCidToken() => {
      'id': 1,
      'cid': 'bafy-test',
      'chain': 'eip155:1',
      'standard': 'erc721',
      'contract_address': '0x1234',
      'token_number': '1',
    };

void main() {
  group('RebuildMetadataDone', () {
    test('toJson and fromJson round-trip with cid-based token', () {
      final tokenMap = _minimalCidToken();
      final done = RebuildMetadataDone(token: tokenMap);
      final json = done.toJson();
      expect(json['kind'], RebuildMetadataDone.kind);
      expect(json['token'], tokenMap);

      final parsed = RebuildMetadataResult.fromJson(json);
      expect(parsed, isA<RebuildMetadataDone>());
      expect((parsed as RebuildMetadataDone).token, tokenMap);
    });

    test('isolate round-trip: AssetToken.toJson -> RebuildMetadataDone -> assetToken', () {
      final token = AssetToken.fromJson(_minimalCidToken());
      final done = RebuildMetadataDone(token: token.toJson());
      final roundTripped = done.assetToken;
      expect(roundTripped.cid, token.cid);
      expect(roundTripped.id, token.id);
      expect(roundTripped.chain, token.chain);
      expect(roundTripped.contractAddress, token.contractAddress);
      expect(roundTripped.tokenNumber, token.tokenNumber);
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
    test('parses RebuildMetadataDone when kind matches (cid-based token)', () {
      final parsed = RebuildMetadataResult.fromJson({
        'kind': 'RebuildMetadataDone',
        'token': _minimalCidToken(),
      });
      expect(parsed, isA<RebuildMetadataDone>());
      expect((parsed as RebuildMetadataDone).assetToken.cid, 'bafy-test');
    });

    test('parses RebuildMetadataDone with token_cid (legacy shape)', () {
      final parsed = RebuildMetadataResult.fromJson({
        'kind': 'RebuildMetadataDone',
        'token': {
          'id': 1,
          'token_cid': 'bafy-legacy',
          'chain': 'eip155:1',
          'contract_address': '0x1234',
          'token_number': '1',
        },
      });
      expect(parsed, isA<RebuildMetadataDone>());
      expect((parsed as RebuildMetadataDone).assetToken.cid, 'bafy-legacy');
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
