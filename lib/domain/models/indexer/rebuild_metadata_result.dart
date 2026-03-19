// ignore_for_file: public_member_api_docs // Reason: protocol-shaped isolate wire models.

import 'package:app/domain/models/indexer/asset_token.dart';

/// Result of rebuild metadata operation from isolate.
/// Either [RebuildMetadataDone] (success) or [RebuildMetadataFailed] (error).
abstract class RebuildMetadataResult {
  const RebuildMetadataResult();

  /// Parse from JSON received from isolate.
  /// Returns [RebuildMetadataDone] or [RebuildMetadataFailed] based on kind.
  static RebuildMetadataResult fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String?;
    if (kind == RebuildMetadataDone.kind) {
      return RebuildMetadataDone.fromJson(json);
    }
    return RebuildMetadataFailed.fromJson(json);
  }
}

/// Success: metadata rebuilt and token fetched.
class RebuildMetadataDone extends RebuildMetadataResult {
  const RebuildMetadataDone({required this.token});

  factory RebuildMetadataDone.fromJson(Map<String, dynamic> json) {
    final token = json['token'] as Map<String, dynamic>?;
    if (token == null) {
      throw ArgumentError('RebuildMetadataDone requires token');
    }
    return RebuildMetadataDone(token: token);
  }

  static const String kind = 'RebuildMetadataDone';

  final Map<String, dynamic> token;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'token': token,
      };

  /// Parsed token as [AssetToken].
  AssetToken get assetToken => AssetToken.fromJson(token);
}

/// Failure: metadata rebuild failed with error message.
class RebuildMetadataFailed extends RebuildMetadataResult {
  const RebuildMetadataFailed({required this.error});

  factory RebuildMetadataFailed.fromJson(Map<String, dynamic> json) =>
      RebuildMetadataFailed(
        error: json['error'] as String? ?? 'Metadata rebuild failed',
      );

  static const String kind = 'RebuildMetadataFailed';

  final String error;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'error': error,
      };
}
