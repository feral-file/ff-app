import 'package:app/domain/extensions/extensions.dart';
import 'package:app/domain/models/models.dart';
import 'package:graphql/client.dart';
import 'package:logging/logging.dart';
import 'package:sentry_link/sentry_link.dart';
import 'package:wallet/wallet.dart' as wallet;

/// Service for validating raw addresses and resolving ENS/TNS domains.
class DomainAddressService {
  /// Creates a [DomainAddressService].
  DomainAddressService({
    required String resolverUrl,
    required String resolverApiKey,
  }) : _resolverUrl = resolverUrl,
       _resolverApiKey = resolverApiKey,
       _log = Logger('DomainAddressService');

  final String _resolverUrl;
  final String _resolverApiKey;
  final Logger _log;

  static const String _lookupQuery = '''
    query {
      lookup(inputs: [
        { chain: "<chain>", name: "<name>", skipCache: false },
      ]) {
        chain
        name
        address
        error
      }
    }
  ''';

  /// Verify an Ethereum address.
  String? verifyEthereumAddress(String address) {
    try {
      if (!address.isEthereumAddressFormat()) {
        return null;
      }
      final checksum = wallet.EthereumAddress.fromHex(
        address,
        enforceEip55: true,
      );
      return checksum.eip55With0x;
    } on Exception {
      return null;
    }
  }

  /// Verify a Tezos address.
  String? verifyTezosAddress(String address) {
    if (!address.isTezosAddressFormat()) {
      return null;
    }
    return address.isValidTezosAddress ? address : null;
  }

  /// Verify an ENS domain.
  Future<String?> verifyENS(String value) async {
    return _resolveDomainAddress(domain: value, chain: 'ethereum');
  }

  /// Verify a TNS domain.
  Future<String?> verifyTNS(String value) async {
    return _resolveDomainAddress(domain: value, chain: 'tezos');
  }

  /// Verify an address or ENS/TNS domain.
  ///
  /// Returns null if input is invalid or domain cannot be resolved.
  Future<Address?> verifyAddressOrDomain(String value) async {
    final input = value.trim();
    if (input.isEmpty) {
      return null;
    }

    final ethAddress = verifyEthereumAddress(input);
    if (ethAddress != null) {
      return Address(address: ethAddress, type: Chain.ethereum);
    }

    final tezosAddress = verifyTezosAddress(input);
    if (tezosAddress != null) {
      return Address(address: tezosAddress, type: Chain.tezos);
    }

    if (input.isENSFormat()) {
      final resolved = await verifyENS(input);
      if (resolved != null) {
        final checksumAddress = verifyEthereumAddress(resolved);
        if (checksumAddress != null) {
          return Address(
            address: checksumAddress,
            type: Chain.ethereum,
            domain: input,
          );
        }
      }
    }

    if (input.isTNSFormat()) {
      final resolved = await verifyTNS(input);
      if (resolved != null) {
        final checksumAddress = verifyTezosAddress(resolved);
        if (checksumAddress != null) {
          return Address(
            address: checksumAddress,
            type: Chain.tezos,
            domain: input,
          );
        }
      }
    }

    return null;
  }

  Future<String?> _resolveDomainAddress({
    required String domain,
    required String chain,
  }) async {
    if (_resolverUrl.isEmpty) {
      _log.warning(
        'DOMAIN_RESOLVER_URL is empty; cannot resolve domain $domain',
      );
      return null;
    }

    final client = GraphQLClient(
      cache: GraphQLCache(dataIdFromObject: (_) => null),
      link: Link.from([
        SentryGql.link(
          shouldStartTransaction: true,
          graphQlErrorsMarkTransactionAsFailed: true,
        ),
        HttpLink(
          _resolverUrl,
          defaultHeaders: {
            if (_resolverApiKey.isNotEmpty) 'X-API-KEY': _resolverApiKey,
          },
        ),
      ]),
      queryRequestTimeout: const Duration(seconds: 10),
    );

    try {
      final result = await client.query(
        QueryOptions(
          document: gql(
            _lookupQuery
                .replaceFirst('<chain>', chain)
                .replaceFirst('<name>', domain),
          ),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        _log.warning(
          'Failed to resolve domain $domain on $chain: ${result.exception}',
        );
        return null;
      }

      final lookup = result.data?['lookup'];
      if (lookup is! List || lookup.isEmpty) {
        return null;
      }

      final first = lookup.first;
      if (first is! Map) {
        return null;
      }

      final address = first['address']?.toString();
      if (address == null || address.isEmpty) {
        return null;
      }

      return address;
    } on Object catch (e, stack) {
      _log.warning(
        'Domain resolve request failed for $domain on $chain',
        e,
        stack,
      );
      return null;
    }
  }
}
