import 'package:app/domain/models/models.dart';

/// Address model
class Address {
  /// Create an Address
  Address({required this.address, required this.type, this.domain});

  /// Address
  final String address;

  /// Type
  final Chain type;

  /// Domain
  final String? domain;

  /// Copy with
  Address copyWith({String? address, Chain? type, String? domain}) => Address(
    address: address ?? this.address,
    type: type ?? this.type,
    domain: domain ?? this.domain,
  );
}
