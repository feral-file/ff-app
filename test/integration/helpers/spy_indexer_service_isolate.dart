import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/infra/services/indexer_service_isolate.dart';

/// Wraps a real [IndexerServiceIsolate] and records call order for integration
/// tests.
///
/// Use to verify the address indexing flow: index → pullStatus → fetchTokens.
class SpyIndexerServiceIsolate implements IndexerServiceIsolateOperations {
  SpyIndexerServiceIsolate({required IndexerServiceIsolateOperations delegate})
      : _delegate = delegate;

  final IndexerServiceIsolateOperations _delegate;

  /// Recorded call sequence: 'index', 'pullStatus', 'fetchTokens'.
  final List<String> callSequence = <String>[];

  @override
  Future<List<AddressIndexingResult>> indexAddressesList(
    List<String> addresses,
  ) async {
    callSequence.add('index');
    return _delegate.indexAddressesList(addresses);
  }

  @override
  Future<AddressIndexingJobResponse> getAddressIndexingJobStatus(
    String workflowId,
  ) async {
    callSequence.add('pullStatus');
    return _delegate.getAddressIndexingJobStatus(workflowId);
  }

  @override
  Future<TokensPage> fetchTokensPageByAddresses({
    required List<String> addresses,
    int? limit,
    int? offset,
  }) async {
    callSequence.add('fetchTokens');
    return _delegate.fetchTokensPageByAddresses(
      addresses: addresses,
      limit: limit,
      offset: offset,
    );
  }
}
