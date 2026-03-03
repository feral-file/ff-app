import 'dart:convert';

import 'package:app/domain/extensions/extensions.dart';
import 'package:app/domain/models/base_object.dart';

/// Chain model
enum Chain {
  /// Ethereum
  ethereum,

  /// Tezos
  tezos,

  /// Unknown
  unknown
  ;

  /// Create a Chain from a source
  static Chain fromSource(String source) {
    switch (source.toLowerCase()) {
      case 'ethereum':
        return Chain.ethereum;
      case 'tezos':
        return Chain.tezos;
      default:
        return Chain.unknown;
    }
  }

  /// Create a CryptoType from an address
  static Chain fromAddress(String source) {
    if (source.isValidTezosAddress) {
      return Chain.tezos;
    } else if (source.toEthereumAddress() != null) {
      return Chain.ethereum;
    } else {
      return Chain.unknown;
    }
  }

  @override
  String toString() {
    return switch (this) {
      Chain.ethereum => 'ETH',
      Chain.tezos => 'TEZ',
      Chain.unknown => 'UNKNOWN',
    };
  }
}

/// Wallet address model
class WalletAddress implements BaseObject {
  /// Create a WalletAddress
  WalletAddress({
    required this.address,
    required this.createdAt,
    this.isHidden = false,
    String? name,
  }) : name = name?.maskIfNeeded() ?? Chain.fromAddress(address).name;

  /// From JSON
  factory WalletAddress.fromJson(Map<String, dynamic> json) => WalletAddress(
    address: json['address'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    isHidden: json['isHidden'] as bool,
    name: json['name'] as String?,
  );

  /// Address
  final String address;

  /// Created at
  final DateTime createdAt;

  /// Is hidden
  final bool isHidden;

  /// Name
  final String name;

  /// Copy with
  WalletAddress copyWith({
    String? address,
    String? chain,
    DateTime? createdAt,
    bool? isHidden,
    String? name,
  }) => WalletAddress(
    address: address ?? this.address,
    createdAt: createdAt ?? this.createdAt,
    isHidden: isHidden ?? this.isHidden,
    name: name ?? this.name,
  );

  /// To JSON
  Map<String, dynamic> toJson() => {
    'address': address,
    'createdAt': createdAt.toIso8601String(),
    'isHidden': isHidden,
    'name': name,
  };

  /// Crypto type
  String get chain => Chain.fromAddress(address).toString();

  @override
  String get key => address;

  @override
  String get value => jsonEncode(toJson());

  @override
  Map<String, String> get toKeyValue => {
    'key': key,
    'value': value,
  };
}
