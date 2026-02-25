// ignore_for_file: public_member_api_docs, sort_constructors_first, one_member_abstracts // Reason: protocol-shaped indexer models; keep stable + auditable.

/// Base type for parsed change metadata.
///
/// The indexer returns `meta` as a JSON object. We keep it portable and
/// auditable by parsing into small, explicit value types.
abstract class ChangeMeta {
  /// Serialize to JSON.
  Map<String, dynamic> toJson();
}

/// Artist represents an artist/creator referenced in change metadata.
class ChangeArtist {
  /// Creates a ChangeArtist.
  const ChangeArtist({
    required this.did,
    required this.name,
  });

  /// Decentralized identifier.
  final String did;

  /// Display name.
  final String name;

  /// Creates from JSON.
  factory ChangeArtist.fromJson(Map<String, dynamic> json) => ChangeArtist(
        did: json['did'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'did': did,
        'name': name,
      };
}

/// Publisher represents the publisher referenced in token metadata changes.
class ChangePublisher {
  /// Creates a ChangePublisher.
  const ChangePublisher({
    this.name,
    this.url,
  });

  /// Display name.
  final String? name;

  /// Website URL.
  final String? url;

  /// Creates from JSON (nullable).
  factory ChangePublisher.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ChangePublisher();
    return ChangePublisher(
      name: json['name'] as String?,
      url: json['url'] as String?,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (url != null) 'url': url,
      };
}

/// Normalized metadata fields we track for change diffs.
class MetadataFields {
  /// Creates MetadataFields.
  const MetadataFields({
    this.animationUrl,
    this.imageUrl,
    this.artists,
    this.publisher,
    this.mimeType,
  });

  final String? animationUrl;
  final String? imageUrl;
  final List<ChangeArtist>? artists;
  final ChangePublisher? publisher;
  final String? mimeType;

  /// Creates from JSON (nullable).
  factory MetadataFields.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MetadataFields();
    return MetadataFields(
      animationUrl: json['animation_url'] as String?,
      imageUrl: json['image_url'] as String?,
      artists: (json['artists'] as List?)
          ?.whereType<Map<Object?, Object?>>()
          .map((e) => ChangeArtist.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      publisher: ChangePublisher.fromJson(
        (json['publisher'] as Map?)?.cast<String, dynamic>(),
      ),
      mimeType: json['mime_type'] as String?,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        if (animationUrl != null) 'animation_url': animationUrl,
        if (imageUrl != null) 'image_url': imageUrl,
        if (artists != null)
          'artists': artists!.map((a) => a.toJson()).toList(),
        if (publisher != null) 'publisher': publisher!.toJson(),
        if (mimeType != null) 'mime_type': mimeType,
      };
}

/// Metadata for token/owner/balance changes (provenance-like).
class ProvenanceChangeMeta implements ChangeMeta {
  /// Creates ProvenanceChangeMeta.
  const ProvenanceChangeMeta({
    required this.chain,
    required this.standard,
    required this.contract,
    required this.tokenNumber,
    required this.tokenId,
    this.from,
    this.to,
    this.quantity,
    this.txHash,
  });

  /// e.g. `eip155:1`, `tezos:mainnet`
  final String chain;

  /// e.g. `erc721`, `erc1155`, `fa2`
  final String standard;

  /// Contract address.
  final String contract;

  /// Token number (string to preserve large ints).
  final String tokenNumber;

  /// Numeric token ID (indexer internal).
  final int tokenId;

  /// Sender address (null for mints).
  final String? from;

  /// Recipient address (null for burns).
  final String? to;

  /// Quantity transferred/minted/burned (nullable).
  final String? quantity;

  /// Transaction hash (nullable).
  final String? txHash;

  /// Creates from JSON.
  factory ProvenanceChangeMeta.fromJson(Map<String, dynamic> json) =>
      ProvenanceChangeMeta(
        chain: json['chain'] as String? ?? '',
        standard: json['standard'] as String? ?? '',
        contract: json['contract'] as String? ?? '',
        tokenNumber: json['token_number']?.toString() ?? '',
        tokenId: int.tryParse(json['token_id']?.toString() ?? '') ?? 0,
        from: json['from'] as String?,
        to: json['to'] as String?,
        quantity: json['quantity']?.toString(),
        txHash: json['tx_hash'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        'chain': chain,
        'standard': standard,
        'contract': contract,
        'token_number': tokenNumber,
        'token_id': tokenId,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (quantity != null) 'quantity': quantity,
        if (txHash != null) 'tx_hash': txHash,
      };

  /// A stable token CID string (DP-1-ish) derived from change metadata.
  ///
  /// Note: Some indexer deployments already provide `token_cid` elsewhere.
  String get tokenCid => '$chain:$standard:$contract:$tokenNumber';

  bool _isNullOrZeroAddress(String? address) {
    if (address == null) return true;
    final v = address.trim();
    if (v.isEmpty) return true;
    final lower = v.toLowerCase();
    return lower == '0x0000000000000000000000000000000000000000';
  }

  /// True when this change represents a mint (from null/zero address).
  bool isMint() => _isNullOrZeroAddress(from) && !_isNullOrZeroAddress(to);

  /// True when this change represents a burn (to null/zero address).
  bool isBurn() => _isNullOrZeroAddress(to) && !_isNullOrZeroAddress(from);

  /// True when this change represents a transfer (both from/to non-null).
  bool isTransfer() => !_isNullOrZeroAddress(from) && !_isNullOrZeroAddress(to);
}

/// Metadata for metadata changes.
class MetadataChangeMeta implements ChangeMeta {
  /// Creates MetadataChangeMeta.
  const MetadataChangeMeta({
    required this.old,
    required this.new_,
    required this.tokenId,
  });

  final MetadataFields old;
  final MetadataFields new_;
  final int tokenId;

  /// Creates from JSON.
  factory MetadataChangeMeta.fromJson(Map<String, dynamic> json) =>
      MetadataChangeMeta(
        old: MetadataFields.fromJson(
          (json['old'] as Map?)?.cast<String, dynamic>(),
        ),
        new_: MetadataFields.fromJson(
          (json['new'] as Map?)?.cast<String, dynamic>(),
        ),
        tokenId: int.tryParse(json['token_id']?.toString() ?? '') ?? 0,
      );

  @override
  Map<String, dynamic> toJson() => {
        'old': old.toJson(),
        'new': new_.toJson(),
        'token_id': tokenId,
      };
}

/// Normalized enrichment source fields we track for diffs.
class EnrichmentSourceFields {
  /// Creates EnrichmentSourceFields.
  const EnrichmentSourceFields({
    this.vendor,
    this.vendorHash,
    this.name,
    this.description,
    this.animationUrl,
    this.imageUrl,
    this.artists,
    this.mimeType,
  });

  final String? vendor;
  final String? vendorHash;
  final String? name;
  final String? description;
  final String? animationUrl;
  final String? imageUrl;
  final List<ChangeArtist>? artists;
  final String? mimeType;

  /// Creates from JSON (nullable).
  factory EnrichmentSourceFields.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EnrichmentSourceFields();
    return EnrichmentSourceFields(
      vendor: json['vendor'] as String?,
      vendorHash: json['vendor_hash'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      animationUrl: json['animation_url'] as String?,
      imageUrl: json['image_url'] as String?,
      artists: (json['artists'] as List?)
          ?.whereType<Map<Object?, Object?>>()
          .map((e) => ChangeArtist.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      mimeType: json['mime_type'] as String?,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        if (vendor != null) 'vendor': vendor,
        if (vendorHash != null) 'vendor_hash': vendorHash,
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (animationUrl != null) 'animation_url': animationUrl,
        if (imageUrl != null) 'image_url': imageUrl,
        if (artists != null)
          'artists': artists!.map((a) => a.toJson()).toList(),
        if (mimeType != null) 'mime_type': mimeType,
      };
}

/// Metadata for enrichment source changes.
class EnrichmentSourceChangeMeta implements ChangeMeta {
  /// Creates EnrichmentSourceChangeMeta.
  const EnrichmentSourceChangeMeta({
    required this.old,
    required this.new_,
    required this.tokenId,
  });

  final EnrichmentSourceFields old;
  final EnrichmentSourceFields new_;
  final int tokenId;

  /// Creates from JSON.
  factory EnrichmentSourceChangeMeta.fromJson(Map<String, dynamic> json) =>
      EnrichmentSourceChangeMeta(
        old: EnrichmentSourceFields.fromJson(
          (json['old'] as Map?)?.cast<String, dynamic>(),
        ),
        new_: EnrichmentSourceFields.fromJson(
          (json['new'] as Map?)?.cast<String, dynamic>(),
        ),
        tokenId: int.tryParse(json['token_id']?.toString() ?? '') ?? 0,
      );

  @override
  Map<String, dynamic> toJson() => {
        'old': old.toJson(),
        'new': new_.toJson(),
        'token_id': tokenId,
      };
}

/// Metadata for token viewability changes.
class TokenViewabilityChangeMeta implements ChangeMeta {
  /// Creates TokenViewabilityChangeMeta.
  const TokenViewabilityChangeMeta({
    required this.tokenId,
    required this.tokenCid,
    required this.isViewable,
  });

  final int tokenId;
  final String tokenCid;
  final bool isViewable;

  /// Creates from JSON.
  factory TokenViewabilityChangeMeta.fromJson(Map<String, dynamic> json) =>
      TokenViewabilityChangeMeta(
        tokenId: int.tryParse(json['token_id']?.toString() ?? '') ?? 0,
        tokenCid: json['token_cid'] as String? ?? '',
        isViewable: json['is_viewable'] as bool? ?? false,
      );

  @override
  Map<String, dynamic> toJson() => {
        'token_id': tokenId,
        'token_cid': tokenCid,
        'is_viewable': isViewable,
      };
}

// End of file.
