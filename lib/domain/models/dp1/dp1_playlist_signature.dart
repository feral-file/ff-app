import 'package:flutter/foundation.dart';

// ignore_for_file: public_member_api_docs

/// One DP-1 v1.1.0 playlist signature entry (wire object under `signatures[]`).
///
/// Legacy v1.0.x single-string signatures use the top-level `signature` field on
/// the playlist ([DP1Playlist.legacySignature]), not string elements inside
/// `signatures[]` (those are ignored when parsing wire JSON).
@immutable
class DP1PlaylistSignature {
  const DP1PlaylistSignature({
    this.alg,
    this.kid,
    this.ts,
    this.payloadHash,
    this.role,
    this.sig,
  });

  factory DP1PlaylistSignature.fromJson(Map<String, dynamic> json) {
    return DP1PlaylistSignature(
      alg: json['alg'] as String?,
      kid: json['kid'] as String?,
      ts: json['ts'] as String?,
      payloadHash: json['payload_hash'] as String?,
      role: json['role'] as String?,
      sig: json['sig'] as String?,
    );
  }

  final String? alg;
  final String? kid;
  final String? ts;
  final String? payloadHash;
  final String? role;
  final String? sig;

  Map<String, dynamic> toJson() {
    return {
      if (alg != null) 'alg': alg,
      if (kid != null) 'kid': kid,
      if (ts != null) 'ts': ts,
      if (payloadHash != null) 'payload_hash': payloadHash,
      if (role != null) 'role': role,
      if (sig != null) 'sig': sig,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DP1PlaylistSignature &&
          runtimeType == other.runtimeType &&
          alg == other.alg &&
          kid == other.kid &&
          ts == other.ts &&
          payloadHash == other.payloadHash &&
          role == other.role &&
          sig == other.sig;

  @override
  int get hashCode => Object.hash(alg, kid, ts, payloadHash, role, sig);
}
