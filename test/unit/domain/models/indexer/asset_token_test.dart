import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal token map matching AssetToken.toJson() output (cid-based).
/// Used for isolate round-trip and RebuildMetadataDone compatibility.
Map<String, dynamic> minimalCidBasedToken({
  String cid = 'bafy-test',
  String chain = 'eip155:1',
  String standard = 'erc721',
  String contractAddress = '0x1234',
  String tokenNumber = '1',
}) =>
    {
      'id': 1,
      'cid': cid,
      'chain': chain,
      'standard': standard,
      'contract_address': contractAddress,
      'token_number': tokenNumber,
    };

/// Minimal token map with token_cid (GraphQL/legacy shape).
Map<String, dynamic> minimalTokenCidBasedToken({
  String tokenCid = 'bafy-test',
  String chain = 'eip155:1',
  String standard = 'erc721',
  String contractAddress = '0x1234',
  String tokenNumber = '1',
}) =>
    {
      'id': 1,
      'token_cid': tokenCid,
      'chain': chain,
      'standard': standard,
      'contract_address': contractAddress,
      'token_number': tokenNumber,
    };

void main() {
  group('AssetToken.fromJson', () {
    test('accepts cid-based payload (toJson output shape)', () {
      final json = minimalCidBasedToken(cid: 'bafy-xyz');
      final token = AssetToken.fromJson(json);
      expect(token.cid, 'bafy-xyz');
      expect(token.chain, 'eip155:1');
      expect(token.contractAddress, '0x1234');
      expect(token.tokenNumber, '1');
    });

    test('accepts token_cid-based payload (GraphQL shape)', () {
      final json = minimalTokenCidBasedToken(tokenCid: 'bafy-gql');
      final token = AssetToken.fromJson(json);
      expect(token.cid, 'bafy-gql');
      expect(token.chain, 'eip155:1');
    });

    test('prefers token_cid over cid when both present', () {
      final json = {
        ...minimalCidBasedToken(),
        'token_cid': 'bafy-prefer',
        'cid': 'bafy-other',
      };
      final token = AssetToken.fromJson(json);
      expect(token.cid, 'bafy-prefer');
    });
  });

  group('AssetToken.toJson round-trip', () {
    test('toJson produces cid-based payload parseable by fromJson', () {
      final json = minimalCidBasedToken();
      final token = AssetToken.fromJson(json);
      final serialized = token.toJson();
      final roundTripped = AssetToken.fromJson(serialized);
      expect(roundTripped.cid, token.cid);
      expect(roundTripped.id, token.id);
      expect(roundTripped.chain, token.chain);
    });
  });
}
