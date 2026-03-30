import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_service_isolate.dart';

/// Fake [IndexerServiceIsolateOperations] for unit tests.
/// Records call order and allows configuring return values.
class FakeIndexerServiceIsolate implements IndexerServiceIsolateOperations {
  final List<String> callSequence = <String>[];

  List<AddressIndexingResult> indexAddressesListResult = const [
    AddressIndexingResult(address: '0xabc', workflowId: 'wf-1'),
  ];
  AddressIndexingJobResponse? pullStatusResult;
  TokensPage fetchTokensResult = const TokensPage(tokens: []);

  /// When non-empty, each [fetchTokensPageByAddresses] call returns the next
  /// entry (cursor pagination tests). When exhausted, uses [fetchTokensResult].
  List<TokensPage> fetchTokensPageSequence = const [];
  int _fetchTokensPageSequenceIndex = 0;

  AssetToken? rebuildMetadataAndFetchTokenResult;

  @override
  Future<List<AddressIndexingResult>> indexAddressesList(
    List<String> addresses,
  ) async {
    callSequence.add('index');
    return indexAddressesListResult;
  }

  @override
  Future<AddressIndexingJobResponse> getAddressIndexingJobStatus(
    String workflowId,
  ) async {
    callSequence.add('pullStatus');
    if (pullStatusResult != null) return pullStatusResult!;
    return const AddressIndexingJobResponse(
      workflowId: 'wf-1',
      address: '0xabc',
      status: IndexingJobStatus.completed,
      totalTokensIndexed: 0,
      totalTokensViewable: 0,
    );
  }

  @override
  Future<TokensPage> fetchTokensPageByAddresses({
    required List<String> addresses,
    int? limit,
    int? offset,
  }) async {
    callSequence.add('fetchTokens');
    if (fetchTokensPageSequence.isNotEmpty &&
        _fetchTokensPageSequenceIndex < fetchTokensPageSequence.length) {
      return fetchTokensPageSequence[_fetchTokensPageSequenceIndex++];
    }
    return fetchTokensResult;
  }

  @override
  Future<AssetToken?> rebuildMetadataAndFetchToken(String cid) async {
    callSequence.add('rebuildMetadataAndFetchToken');
    return rebuildMetadataAndFetchTokenResult;
  }
}
