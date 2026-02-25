// ignore_for_file: public_member_api_docs // Reason: isolate message types are protocol-shaped; keep stable and minimal.

import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/indexer/changes/change.dart';
import 'package:app/domain/models/indexer/workflow.dart';

/// Base type for isolate -> main messages.
abstract class TokensWorkerMessage {
  const TokensWorkerMessage(this.uuid);

  final String uuid;
}

abstract class TokensWorkerFailure extends TokensWorkerMessage {
  const TokensWorkerFailure(super.uuid, this.exception);

  final Object exception;
}

/// Tokens streaming for address owners (paged).
class FetchTokensData extends TokensWorkerMessage {
  const FetchTokensData(
    super.uuid,
    this.addresses,
    this.assets,
  );

  final List<String> addresses;
  final List<AssetToken> assets;
}

class FetchTokensSuccess extends TokensWorkerMessage {
  const FetchTokensSuccess(super.uuid, this.addresses);

  final List<String> addresses;
}

class FetchTokenFailure extends TokensWorkerFailure {
  const FetchTokenFailure(super.uuid, this.addresses, super.exception);

  final List<String> addresses;
}

/// Address reindex trigger response.
class ReindexAddressesListDone extends TokensWorkerMessage {
  const ReindexAddressesListDone(super.uuid, this.results);

  final List<AddressIndexingResult> results;
}

class ReindexAddressesFailure extends TokensWorkerFailure {
  const ReindexAddressesFailure(super.uuid, super.exception);
}

/// Change-journal page streamed from isolate.
///
/// Main isolate will turn this into:
/// - tokenIds + tokenCids extraction
/// - fetch tokens by tokenIds+owners
/// - ingest + delete-missing
class UpdateTokensData extends TokensWorkerMessage {
  const UpdateTokensData(super.uuid, this.changesList, this.addresses);

  final ChangeList changesList;
  final List<String> addresses;
}

class UpdateTokensSuccess extends TokensWorkerMessage {
  const UpdateTokensSuccess(super.uuid);
}

class UpdateTokensFailure extends TokensWorkerFailure {
  const UpdateTokensFailure(super.uuid, this.addresses, super.exception);

  final List<String> addresses;
}

/// Consolidated manual token fetch response.
///
/// This is used for both:
/// - token IDs + owners (incremental sync)
/// - token CIDs (DP1 item enrichment)
class FetchManualTokensDone extends TokensWorkerMessage {
  const FetchManualTokensDone(super.uuid, this.tokens);

  final List<AssetToken> tokens;
}

class FetchManualTokensFailure extends TokensWorkerFailure {
  const FetchManualTokensFailure(super.uuid, super.exception);
}

/// Signal emitted after channel-ingested notification reaches the isolate.
class ChannelIngestedAck extends TokensWorkerMessage {
  const ChannelIngestedAck(super.uuid);
}

// End of file.
