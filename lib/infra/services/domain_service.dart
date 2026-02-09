import 'dart:async';

import 'package:app/domain/models/models.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:graphql/client.dart';
import 'package:logging/logging.dart';
import 'package:sentry/sentry.dart';

/// Service for resolving domain addresses
abstract class DomainService {
  /// Get an address for a domain
  Future<String?> getAddress(String domain, {Chain? chain});
}

/// Logger for DomainService
final log = Logger('DomainService');

/// Implementation of DomainService
class DomainServiceImpl implements DomainService {
  /// Create a DomainServiceImpl
  static final String _addressEndpoint = AppConfig.domainResolverUrl;

  static const String _addressQuery = '''
    query {
      lookup(inputs: [
        { chain: "<chain>", name: "<var>", skipCache: false },
      ]) {
        chain
        name
        address
        error
      }
    }
  ''';

  static const String _subKey = 'lookup';

  static GraphClient get _ensClient => GraphClient(_addressEndpoint);

  Future<String?> _getAddress(String domain, String chain) async {
    try {
      log.info('Getting address for $domain');
      final startTime = DateTime.now();
      final result = await _ensClient.query(
        doc: _addressQuery
            .replaceFirst('<var>', domain)
            .replaceFirst('<chain>', chain),
        subKey: _subKey,
      ) as List?;
      final endTime = DateTime.now();
      log.info(
          '[Getting address for $domain] Result: $result in ${endTime.difference(startTime).inMilliseconds}ms');
      if (result == null || result.isEmpty) {
        return null;
      }
      final address = result.first['address'] as String?;
      log.info('Address for $domain in $chain: $address');
      return address;
    } catch (e) {
      log.info('Error getting address for $domain: $e');
      unawaited(
        Sentry.captureException(
          '[DomainService] Error getting address for $domain: $e',
        ),
      );
      return null;
    }
  }

  Future<String?> _getEthAddress(String domain) async {
    try {
      final ethAddress = await _getAddress(domain, 'ethereum');
      return ethAddress;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getTezosAddress(String domain) async {
    try {
      final tezosAddress = await _getAddress(domain, 'tezos');
      return tezosAddress;
    } catch (e) {
      unawaited(
        Sentry.captureException(
          'Error getting tezos address for $domain: $e',
        ),
      );
      return null;
    }
  }

  @override
  Future<String?> getAddress(String domain, {Chain? chain}) async {
    if (chain == Chain.ethereum) {
      return _getEthAddress(domain);
    }
    if (chain == Chain.tezos) {
      return _getTezosAddress(domain);
    }

    final ethAddress = await _getEthAddress(domain);
    if (ethAddress != null) {
      return ethAddress;
    }
    final tezosAddress = await _getTezosAddress(domain);
    return tezosAddress;
  }
}

/// GraphQL client for DomainService
class GraphClient {
  /// Create a GraphClient
  GraphClient(this._url);

  final String _url;

  /// Get the GraphQL client
  GraphQLClient get client {
    final httpLink = HttpLink(
      _url,
      defaultHeaders: {
        'X-API-KEY': AppConfig.domainResolverApiKey,
      },
    );
    final authLink = AuthLink(getToken: _getToken);
    final link = authLink.concat(httpLink);

    return GraphQLClient(
      cache: GraphQLCache(dataIdFromObject: (data) => null),
      link: link,
    );
  }

  /// Executes a GraphQL query.
  Future<dynamic> query({
    required String doc,
    Map<String, dynamic> vars = const {},
    bool withToken = false,
    String? subKey,
  }) async {
    try {
      log.info('Querying: $doc');
      final startTime = DateTime.now();
      final options = QueryOptions(
        document: gql(doc),
        variables: vars,
      );

      final result = await client.query(options);
      final endTime = DateTime.now();
      log.info(
          '[Querying: $doc] Result: $result in ${endTime.difference(startTime).inMilliseconds}ms');
      if (subKey != null) {
        return result.data?[subKey];
      }
      return result.data;
    } catch (e) {
      log.info('Error querying: $e');
      unawaited(Sentry.captureException('[DomainService] Error querying: $e'));
      return null;
    }
  }

  /// Mutate a GraphQL mutation.
  Future<dynamic> mutate({
    required String doc,
    Map<String, dynamic> vars = const {},
    bool withToken = false,
  }) async {
    try {
      final options = MutationOptions(
        document: gql(doc),
        variables: vars,
      );

      final result = await client.mutate(options);
      return result.data;
    } on Exception catch (e) {
      log.info('Error mutating: $e');
      unawaited(Sentry.captureException('[DomainService] Error mutating: $e'));
      return null;
    }
  }

  Future<String> _getToken() async => '';
}
