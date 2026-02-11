// ignore_for_file: public_member_api_docs // Reason: isolate wire protocol helper types; keep stable and minimal.

import 'dart:convert';

/// Worker opcodes (main isolate -> background isolate).
///
/// These mirror the old repo's isolate message keys to keep semantics stable.
abstract final class WorkerOpcodes {
  static const fetchAllTokens = 'FETCH_ALL_TOKENS';
  static const reindexAddressesList = 'REINDEX_ADDRESSES_LIST';
  static const updateTokensInIsolate = 'UPDATE_TOKENS_IN_ISOLATE';
  static const fetchManualTokens = 'FETCH_MANUAL_TOKENS';
  static const channelIngested = 'CHANNEL_INGESTED';
}

/// An address + last processed anchor pair.
///
/// We keep this small and sendable between isolates.
class AddressAnchor {
  AddressAnchor({
    required this.address,
    required this.anchor,
  });

  factory AddressAnchor.fromJson(Map<String, dynamic> json) => AddressAnchor(
    address: json['address'] as String? ?? '',
    anchor: int.tryParse(json['anchor']?.toString() ?? '') ?? 0,
  );

  final String address;
  final int anchor;

  Map<String, dynamic> toJson() => {
    'address': address,
    'anchor': anchor,
  };

  /// Encodes this anchor as a compact JSON string payload.
  ///
  /// The old repo sent anchors as a map of address -> JSON string. We keep this
  /// helper to preserve that exact protocol when needed.
  String toJsonString() => jsonEncode(toJson());
}
