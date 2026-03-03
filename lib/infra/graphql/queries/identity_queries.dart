/// GraphQL queries for identity lookup.
///
/// Keep these strings stable and auditable (OSS-first posture).
///
/// Source of truth: legacy Feral File app repo (`lib/nft_collection/graphql/queries/*`).
const String identity = r'''
  query identity($account: String!) {
  identity(account: $account) {
    blockchain
    accountNumber
    name
  }
}
''';
