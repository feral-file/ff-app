import 'package:app/domain/constants/indexer_constants.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> waitForAddressIndexingCompletion({
  required IndexerService indexerService,
  required String address,
  Duration pollInterval = const Duration(seconds: 5),
  Duration timeout = const Duration(minutes: 15),
}) async {
  final results = await indexerService.indexAddressesList([address]);
  final result = results.firstWhere(
    (entry) => entry.address == address,
    orElse: () =>
        throw Exception('Indexer did not return workflow for $address'),
  );

  final workflowId = result.workflowId;
  if (workflowId.isEmpty) {
    throw Exception('Empty workflowId for $address');
  }

  final startedAt = DateTime.now();
  while (true) {
    try {
      final status = await indexerService.getAddressIndexingJobStatus(
        workflowId: workflowId,
      );
      if (status.status.isDone) {
        if (!status.status.isSuccess) {
          throw Exception(
            'Indexing finished with ${status.status.name} for $address',
          );
        }
        return;
      }
    } on Object {
      // Retry transient status read failures during long-running workflows.
    }

    if (DateTime.now().difference(startedAt) > timeout) {
      throw Exception(
        'Timed out waiting for workflow $workflowId for $address',
      );
    }

    await Future<void>.delayed(pollInterval);
  }
}

Future<List<AssetToken>> fetchAllTokensByOffsetCursor({
  required IndexerService indexerService,
  required String address,
  int pageSize = indexerTokensPageSize,
  int maxPages = 100,
}) async {
  final allTokens = <AssetToken>[];
  int? nextOffset = 0;

  for (var page = 0; page < maxPages; page++) {
    final response = await indexerService.fetchTokensPageByAddresses(
      addresses: [address],
      limit: pageSize,
      offset: nextOffset,
    );

    if (response.tokens.isNotEmpty) {
      allTokens.addAll(response.tokens);
    }
    if (response.nextOffset == null) {
      return allTokens;
    }
    nextOffset = response.nextOffset;
  }

  fail('Pagination did not terminate within $maxPages pages for $address');
}
