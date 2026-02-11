import 'package:graphql/client.dart';
import 'package:logging/logging.dart';

/// Resolved address payload from a raw address or ENS/TNS domain.
class AddressResolution {
  /// Creates an [AddressResolution].
  const AddressResolution({
    required this.address,
    required this.chain,
    this.domain,
  });

  /// Resolved owner address.
  final String address;

  /// Address chain (`ethereum` or `tezos`).
  final String chain;

  /// Optional source domain when resolved from ENS/TNS.
  final String? domain;
}

/// Resolves raw addresses and ENS/TNS names to normalized owner addresses.
///
/// Mirrors the old app's `DomainAddressService` behavior:
/// - direct ETH/Tezos validation first
/// - ENS (`.eth`) / TNS (`.tez`) lookup via domain resolver API
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

  static final RegExp _ethAddressRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');
  static final RegExp _tezosAddressRegex = RegExp(
    r'^(tz1|tz2|tz3|KT1)[1-9A-Za-z]{33}$',
  );

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

  /// Validate/resolve an address input.
  ///
  /// Returns null if input is neither a valid address nor a resolvable domain.
  Future<AddressResolution?> verifyAddressOrDomain(String raw) async {
    final input = raw.trim();
    if (input.isEmpty) return null;

    final eth = _verifyEthereumAddress(input);
    if (eth != null) {
      return AddressResolution(address: eth, chain: 'ethereum');
    }

    final tezos = _verifyTezosAddress(input);
    if (tezos != null) {
      return AddressResolution(address: tezos, chain: 'tezos');
    }

    if (_isEnsFormat(input)) {
      final resolved = await _resolveDomainAddress(
        domain: input,
        chain: 'ethereum',
      );
      final verified = resolved == null
          ? null
          : _verifyEthereumAddress(resolved);
      if (verified != null) {
        return AddressResolution(
          address: verified,
          chain: 'ethereum',
          domain: input,
        );
      }
    }

    if (_isTnsFormat(input)) {
      final resolved = await _resolveDomainAddress(
        domain: input,
        chain: 'tezos',
      );
      final verified = resolved == null ? null : _verifyTezosAddress(resolved);
      if (verified != null) {
        return AddressResolution(
          address: verified,
          chain: 'tezos',
          domain: input,
        );
      }
    }

    return null;
  }

  String? _verifyEthereumAddress(String value) {
    return _ethAddressRegex.hasMatch(value) ? value : null;
  }

  String? _verifyTezosAddress(String value) {
    return _tezosAddressRegex.hasMatch(value) ? value : null;
  }

  bool _isEnsFormat(String value) {
    return value.toLowerCase().endsWith('.eth');
  }

  bool _isTnsFormat(String value) {
    return value.toLowerCase().endsWith('.tez');
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
      link: HttpLink(
        _resolverUrl,
        defaultHeaders: {
          if (_resolverApiKey.isNotEmpty) 'X-API-KEY': _resolverApiKey,
        },
      ),
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
