/// GraphQL queries for collections.
///
/// Keep these strings stable and auditable (OSS-first posture).
///
/// Source of truth: legacy Feral File app repo (`lib/nft_collection/graphql/queries/*`).
const String collectionQuery = r'''
    query GetCollections($creators: [String!]! = [], $offset: Int64! = 0, $size: Int64! = 100) {
  collections(
    creators: $creators,
    offset: $offset,
    size: $size,
  ) {
    id
    description
    externalID
    imageURL
    items
    name
    creators
    published
    source
    createdAt
  }
}
''';
