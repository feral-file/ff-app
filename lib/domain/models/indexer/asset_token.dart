//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

// ignore_for_file: public_member_api_docs, sort_constructors_first, always_put_required_named_parameters_first, avoid_catches_without_on_clauses, avoid_equals_and_hash_code_on_mutable_classes, hash_and_equals, annotate_overrides // Reason: copied from the legacy mobile app; keep models stable and auditable.

import 'package:app/domain/models/blockchain.dart';

class TokenMetadata {
  TokenMetadata({
    this.name,
    this.description,
    this.imageUrl,
    this.animationUrl,
    this.mimeType,
    this.artists,
    this.publisher,
  });

  final String? name;
  final String? description;
  final String? imageUrl;
  final String? animationUrl;
  final String? mimeType;
  final List<Artist>? artists;
  final Publisher? publisher;

  factory TokenMetadata.fromJson(Map<String, dynamic> json) => TokenMetadata(
    name: json['name'] as String?,
    description: json['description'] as String?,
    imageUrl: json['image_url'] as String?,
    animationUrl: json['animation_url'] as String?,
    mimeType: json['mime_type'] as String?,
    artists: (json['artists'] as List?)
        ?.map((e) => Artist.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    publisher: json['publisher'] != null
        ? Publisher.fromJson(
            Map<String, dynamic>.from(json['publisher'] as Map),
          )
        : null,
  );

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (description != null) 'description': description,
    if (imageUrl != null) 'image_url': imageUrl,
    if (animationUrl != null) 'animation_url': animationUrl,
    if (mimeType != null) 'mime_type': mimeType,
    if (artists != null) 'artists': artists!.map((a) => a.toJson()).toList(),
    if (publisher != null) 'publisher': publisher!.toJson(),
  };

  TokenMetadata copyWith({
    String? name,
    String? description,
    String? imageUrl,
    String? animationUrl,
    String? mimeType,
    List<Artist>? artists,
    Publisher? publisher,
  }) {
    return TokenMetadata(
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      animationUrl: animationUrl ?? this.animationUrl,
      mimeType: mimeType ?? this.mimeType,
      artists: artists ?? this.artists,
      publisher: publisher ?? this.publisher,
    );
  }
}

class AssetToken {
  AssetToken({
    required this.id,
    required this.cid,
    required this.chain,
    required this.standard,
    required this.contractAddress,
    required this.tokenNumber,
    this.currentOwner,
    this.updatedAt,
    this.owners,
    this.provenanceEvents,
    this.ownerProvenances,
    this.mediaAssets,
    this.display,
  });

  final int id;
  final String cid; // primary key in app
  final String chain;
  final String standard;
  final String contractAddress;
  final String tokenNumber;
  final String? currentOwner;
  final DateTime? updatedAt;

  /// Unified display data from indexer.
  final TokenMetadata? display;
  final PaginatedOwners? owners;
  final PaginatedProvenanceEvents? provenanceEvents;
  final PaginatedOwnerProvenances? ownerProvenances;

  /// Unified media assets from indexer.
  final List<MediaAsset>? mediaAssets;

  /// All media assets.
  List<MediaAsset> get allMediaAssets => mediaAssets ?? [];

  factory AssetToken.fromJson(Map<String, dynamic> json) => AssetToken(
    id: int.parse(json['id'].toString()),
    cid: json['token_cid'] as String? ?? json['cid'] as String,
    chain: json['chain'] as String,
    standard: json['standard'] as String? ?? '',
    contractAddress: json['contract_address'] as String,
    tokenNumber: json['token_number'].toString(),
    currentOwner: json['current_owner'] as String?,
    updatedAt: (json['updated_at'] != null)
        ? DateTime.tryParse(json['updated_at'] as String)
        : null,
    display: json['display'] != null
        ? TokenMetadata.fromJson(
            Map<String, dynamic>.from(json['display'] as Map),
          )
        : null,
    owners: json['owners'] != null
        ? PaginatedOwners.fromJson(
            Map<String, dynamic>.from(json['owners'] as Map),
          )
        : null,
    provenanceEvents: json['provenance_events'] != null
        ? PaginatedProvenanceEvents.fromJson(
            Map<String, dynamic>.from(json['provenance_events'] as Map),
          )
        : null,
    ownerProvenances: json['owner_provenances'] != null
        ? PaginatedOwnerProvenances.fromJson(
            Map<String, dynamic>.from(json['owner_provenances'] as Map),
          )
        : null,
    mediaAssets: (json['media_assets'] as List?)
        ?.map((e) => MediaAsset.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'cid': cid,
    'chain': chain,
    'standard': standard,
    'contract_address': contractAddress,
    'token_number': tokenNumber,
    'display': display?.toJson(),
    'owners': owners?.toJson(),
    'provenance_events': provenanceEvents?.toJson(),
    'owner_provenances': ownerProvenances?.toJson(),
    'media_assets': mediaAssets?.map((e) => e.toJson()).toList(),
    'current_owner': currentOwner,
    'updated_at': updatedAt?.toIso8601String(),
    'current_wner': currentOwner,
  };

  factory AssetToken.fromMeilisearchResult(Map<String, dynamic> json) {
    // Extract display_data once to avoid repetition
    final displayData = Map<String, dynamic>.from(json['display_data'] as Map);

    return AssetToken(
      // Top-level fields (direct mapping)
      id: int.parse(displayData['id'].toString()),
      cid: json['token_cid'] as String,
      chain: json['chain'] as String,
      standard: json['standard'] as String,
      contractAddress: json['contract_address'] as String,
      tokenNumber: json['token_number'] as String,

      // Nested fields from display_data
      currentOwner: displayData['current_owner'] as String?,
      updatedAt: displayData['updated_at'] != null
          ? DateTime.tryParse(displayData['updated_at'] as String)
          : null,

      // Nested complex objects from display_data
      display: displayData['display'] != null
          ? TokenMetadata.fromJson(
              Map<String, dynamic>.from(displayData['display'] as Map),
            )
          : null,

      owners: displayData['owners'] != null
          ? PaginatedOwners.fromJson(
              Map<String, dynamic>.from(displayData['owners'] as Map),
            )
          : null,

      provenanceEvents: displayData['provenance_events'] != null
          ? PaginatedProvenanceEvents.fromJson(
              Map<String, dynamic>.from(
                displayData['provenance_events'] as Map,
              ),
            )
          : null,

      ownerProvenances: displayData['owner_provenances'] != null
          ? PaginatedOwnerProvenances.fromJson(
              Map<String, dynamic>.from(
                displayData['owner_provenances'] as Map,
              ),
            )
          : null,

      mediaAssets: displayData['media_assets'] != null
          ? (displayData['media_assets'] as List)
                .map(
                  (e) =>
                      MediaAsset.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList()
          : null,
    );
  }

  AssetToken copyWith({
    int? id,
    String? cid,
    String? chain,
    String? standard,
    String? contractAddress,
    String? tokenNumber,
    String? currentOwner,
    DateTime? updatedAt,
    TokenMetadata? display,
    PaginatedOwners? owners,
    PaginatedProvenanceEvents? provenanceEvents,
    PaginatedOwnerProvenances? ownerProvenances,
    List<MediaAsset>? mediaAssets,
  }) {
    return AssetToken(
      id: id ?? this.id,
      cid: cid ?? this.cid,
      chain: chain ?? this.chain,
      standard: standard ?? this.standard,
      contractAddress: contractAddress ?? this.contractAddress,
      tokenNumber: tokenNumber ?? this.tokenNumber,
      currentOwner: currentOwner ?? this.currentOwner,
      updatedAt: updatedAt ?? this.updatedAt,
      display: display ?? this.display,
      owners: owners ?? this.owners,
      provenanceEvents: provenanceEvents ?? this.provenanceEvents,
      ownerProvenances: ownerProvenances ?? this.ownerProvenances,
      mediaAssets: mediaAssets ?? this.mediaAssets,
    );
  }
}

class Artist {
  Artist({required this.did, required this.name});

  final String did;
  final String name;

  factory Artist.fromJson(Map<String, dynamic> json) => Artist(
    did: json['did'] as String? ?? '',
    name: json['name'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'did': did,
    'name': name,
  };

  Artist copyWith({
    String? did,
    String? name,
  }) {
    return Artist(
      did: did ?? this.did,
      name: name ?? this.name,
    );
  }
}

class Publisher {
  Publisher({this.name, this.url});

  final String? name;
  final String? url;

  factory Publisher.fromJson(Map<String, dynamic> json) => Publisher(
    name: json['name'] as String?,
    url: json['url'] as String?,
  );

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (url != null) 'url': url,
  };

  Publisher copyWith({
    String? name,
    String? url,
  }) {
    return Publisher(
      name: name ?? this.name,
      url: url ?? this.url,
    );
  }
}

class Owner {
  Owner({
    required this.ownerAddress,
    required this.quantity,
  });

  final String ownerAddress;
  final String quantity;

  factory Owner.fromJson(Map<String, dynamic> json) => Owner(
    ownerAddress: json['owner_address'] as String,
    quantity: json['quantity'] as String,
  );

  Map<String, dynamic> toJson() => {
    'owner_address': ownerAddress,
    'quantity': quantity,
  };

  Owner copyWith({
    String? ownerAddress,
    String? quantity,
  }) {
    return Owner(
      ownerAddress: ownerAddress ?? this.ownerAddress,
      quantity: quantity ?? this.quantity,
    );
  }
}

class PaginatedOwners {
  PaginatedOwners({
    required this.items,
    required this.total,
    required this.offset,
  });

  final List<Owner> items;
  final int total;
  final int? offset;

  factory PaginatedOwners.fromJson(Map<String, dynamic> json) =>
      PaginatedOwners(
        items: (json['items'] as List)
            .map((e) => Owner.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        total: int.tryParse(json['total'].toString()) ?? 0,
        offset: int.tryParse(json['offset'].toString()),
      );

  Map<String, dynamic> toJson() => {
    'items': items.map((e) => e.toJson()).toList(),
    'total': total,
    'offset': offset,
  };

  PaginatedOwners copyWith({
    List<Owner>? items,
    int? total,
    int? offset,
  }) {
    return PaginatedOwners(
      items: items ?? this.items,
      total: total ?? this.total,
      offset: offset ?? this.offset,
    );
  }
}

enum ProvenanceEventType {
  mint,
  transfer,
  burn,
  unknown,
}

extension ProvenanceEventTypeJson on ProvenanceEventType {
  String toJson() {
    switch (this) {
      case ProvenanceEventType.mint:
        return 'mint';
      case ProvenanceEventType.transfer:
        return 'transfer';
      case ProvenanceEventType.burn:
        return 'burn';
      case ProvenanceEventType.unknown:
        return 'unknown';
    }
  }

  static ProvenanceEventType fromJson(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'mint':
        return ProvenanceEventType.mint;
      case 'transfer':
        return ProvenanceEventType.transfer;
      case 'burn':
        return ProvenanceEventType.burn;
      default:
        return ProvenanceEventType.unknown;
    }
  }
}

class ProvenanceEvent {
  ProvenanceEvent({
    required this.chain,
    required this.eventType,
    this.fromAddress,
    this.toAddress,
    this.txHash,
    required this.timestamp,
  });

  // eip1155:1, tezos:mainnet, ...
  final String chain;
  final ProvenanceEventType eventType;
  final String? fromAddress;
  final String? toAddress;
  final String? txHash;
  final DateTime timestamp;

  factory ProvenanceEvent.fromJson(Map<String, dynamic> json) =>
      ProvenanceEvent(
        chain: json['chain'] as String,
        eventType: ProvenanceEventTypeJson.fromJson(
          json['event_type'] as String?,
        ),
        fromAddress: json['from_address'] as String?,
        toAddress: json['to_address'] as String?,
        txHash: json['tx_hash'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  Map<String, dynamic> toJson() => {
    'chain': chain,
    'event_type': eventType.toJson(),
    if (fromAddress != null) 'from_address': fromAddress,
    if (toAddress != null) 'to_address': toAddress,
    if (txHash != null) 'tx_hash': txHash,
    'timestamp': timestamp.toIso8601String(),
  };

  String? get txUrl {
    if (txHash == null) return null;
    try {
      final blockchain = Blockchain.fromChain(chain);
      switch (blockchain) {
        case Blockchain.ETHEREUM:
          return 'https://etherscan.io/tx/$txHash';
        case Blockchain.TEZOS:
          return 'https://tzkt.io/$txHash';
      }
    } catch (e) {
      return null;
    }
  }

  bool operator ==(Object other) {
    if (other is ProvenanceEvent) {
      return chain == other.chain &&
          eventType == other.eventType &&
          fromAddress == other.fromAddress &&
          toAddress == other.toAddress &&
          txHash == other.txHash &&
          timestamp == other.timestamp;
    }
    return false;
  }
}

class PaginatedProvenanceEvents {
  PaginatedProvenanceEvents({
    required this.items,
    required this.total,
    required this.offset,
  });

  final List<ProvenanceEvent> items;
  final int total;
  final int? offset;

  factory PaginatedProvenanceEvents.fromJson(Map<String, dynamic> json) =>
      PaginatedProvenanceEvents(
        items: (json['items'] as List)
            .map(
              (e) =>
                  ProvenanceEvent.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        total: int.tryParse(json['total'].toString()) ?? 0,
        offset: int.tryParse(json['offset'].toString()),
      );

  Map<String, dynamic> toJson() => {
    'items': items.map((e) => e.toJson()).toList(),
    'total': total,
    'offset': offset,
  };

  PaginatedProvenanceEvents copyWith({
    List<ProvenanceEvent>? items,
    int? total,
    int? offset,
  }) {
    return PaginatedProvenanceEvents(
      items: items ?? this.items,
      total: total ?? this.total,
      offset: offset ?? this.offset,
    );
  }
}

class OwnerProvenance {
  OwnerProvenance({
    required this.ownerAddress,
    required this.lastTimestamp,
    required this.lastTxIndex,
  });

  final String ownerAddress;
  final DateTime lastTimestamp;
  final int lastTxIndex;

  factory OwnerProvenance.fromJson(Map<String, dynamic> json) =>
      OwnerProvenance(
        ownerAddress: json['owner_address'] as String,
        lastTimestamp: DateTime.parse(json['last_timestamp'] as String),
        lastTxIndex: int.parse(json['last_tx_index'].toString()),
      );

  Map<String, dynamic> toJson() => {
    'owner_address': ownerAddress,
    'last_timestamp': lastTimestamp.toIso8601String(),
    'last_tx_index': lastTxIndex.toString(),
  };

  OwnerProvenance copyWith({
    String? ownerAddress,
    DateTime? lastTimestamp,
    int? lastTxIndex,
  }) {
    return OwnerProvenance(
      ownerAddress: ownerAddress ?? this.ownerAddress,
      lastTimestamp: lastTimestamp ?? this.lastTimestamp,
      lastTxIndex: lastTxIndex ?? this.lastTxIndex,
    );
  }
}

class PaginatedOwnerProvenances {
  PaginatedOwnerProvenances({
    required this.items,
  });

  final List<OwnerProvenance> items;

  factory PaginatedOwnerProvenances.fromJson(Map<String, dynamic> json) =>
      PaginatedOwnerProvenances(
        items: (json['items'] as List)
            .map(
              (e) =>
                  OwnerProvenance.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'items': items.map((e) => e.toJson()).toList(),
  };

  PaginatedOwnerProvenances copyWith({
    List<OwnerProvenance>? items,
  }) {
    return PaginatedOwnerProvenances(
      items: items ?? this.items,
    );
  }
}

class MediaAsset {
  MediaAsset({
    required this.sourceUrl,
    this.mimeType,
    required this.variantUrls,
  });

  final String sourceUrl;
  final String? mimeType;
  final Map<String, dynamic> variantUrls;

  factory MediaAsset.fromJson(Map<String, dynamic> json) => MediaAsset(
    sourceUrl: json['source_url'] as String,
    mimeType: json['mime_type'] as String?,
    variantUrls: Map<String, dynamic>.from(
      (json['variants'] ?? json['variant_urls'] ?? <String, dynamic>{}) as Map,
    ),
  );

  Map<String, dynamic> toJson() => {
    'source_url': sourceUrl,
    if (mimeType != null) 'mime_type': mimeType,
    'variant_urls': variantUrls,
  };
}
