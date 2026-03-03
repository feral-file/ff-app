import 'package:app/domain/constants/asset_token_constants.dart';
import 'package:app/domain/models/blockchain.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:collection/collection.dart';

// ignore_for_file: public_member_api_docs // Reason: copied/adapted from the legacy mobile app; keep helper surface stable.

class _RenderingType {
  static const image = 'image';
  static const svg = 'svg';
  static const gif = 'gif';
  static const audio = 'audio';
  static const video = 'video';
  static const pdf = 'application/pdf';
  static const webview = 'webview';
  static const modelViewer = 'modelViewer';
}

extension AssetTokenExtension on AssetToken {
  String? get displayTitle {
    final title = enrichmentSource?.name ?? metadata?.name;
    if (title == null) {
      return null;
    }
    return title;
  }

  String get displayDescription {
    return enrichmentSource?.description ?? metadata?.description ?? '';
  }

  String? get _mimeType {
    return enrichmentSource?.mimeType ?? metadata?.mimeType;
  }

  String get getMimeType {
    switch (_mimeType) {
      case 'image/avif':
      case 'image/bmp':
      case 'image/jpeg':
      case 'image/jpg':
      case 'image/png':
      case 'image/tiff':
        return _RenderingType.image;

      case 'image/svg+xml':
        return _RenderingType.svg;

      case 'image/gif':
      case 'image/vnd.mozilla.apng':
        return _RenderingType.gif;

      case 'audio/aac':
      case 'audio/midi':
      case 'audio/x-midi':
      case 'audio/mpeg':
      case 'audio/ogg':
      case 'audio/opus':
      case 'audio/wav':
      case 'audio/webm':
      case 'audio/3gpp':
      case 'audio/vnd.wave':
        return _RenderingType.audio;

      case 'video/x-msvideo':
      case 'video/3gpp':
      case 'video/mp4':
      case 'video/mpeg':
      case 'video/ogg':
      case 'video/3gpp2':
      case 'video/quicktime':
      case 'application/x-mpegURL':
      case 'video/x-flv':
      case 'video/MP2T':
      case 'video/webm':
      case 'application/octet-stream':
        return _RenderingType.video;

      case 'application/pdf':
        return _RenderingType.pdf;

      case 'model/gltf-binary':
        return _RenderingType.modelViewer;

      default:
        return _mimeType ?? _RenderingType.webview;
    }
  }

  Blockchain get blockchain => Blockchain.fromChain(chain);

  String? getGalleryThumbnailUrl({
    bool usingThumbnailID = true,
    String? size = 'xs',
  }) {
    String? thumbnailUrl;

    thumbnailUrl = enrichmentSource?.imageUrl ?? metadata?.imageUrl;

    if (size != null) {
      final metadataVariantUrls = metadataMediaAssets
          ?.firstWhereOrNull(
            (mediaAsset) => mediaAsset.sourceUrl == thumbnailUrl,
          )
          ?.variantUrls;

      final enrichmentSourceVariantUrls = enrichmentSourceMediaAssets
          ?.firstWhereOrNull(
            (mediaAsset) => mediaAsset.sourceUrl == thumbnailUrl,
          )
          ?.variantUrls;

      final mediaThumbnailUrl =
          (enrichmentSourceVariantUrls?[size] ??
                  enrichmentSourceVariantUrls?.values.firstOrNull)
              as String? ??
          (metadataVariantUrls?[size] ??
                  metadataVariantUrls?.values.firstOrNull)
              as String?;

      if (mediaThumbnailUrl != null && mediaThumbnailUrl.isNotEmpty) {
        thumbnailUrl = mediaThumbnailUrl;
      }
    }

    if (thumbnailUrl?.isNotEmpty ?? false) {
      if (size != null) {
        // if url in format https://imagedelivery.net/5BJzhBHeVhlhbn58hvcXAQ/../xl, then replace the /xl with size
        if (thumbnailUrl?.startsWith(
              'https://imagedelivery.net/5BJzhBHeVhlhbn58hvcXAQ/',
            ) ??
            false) {
          final urlParts = thumbnailUrl?.split('/');
          if (urlParts != null && urlParts.length > 2) {
            urlParts[urlParts.length - 1] = size;
            thumbnailUrl = urlParts.join('/');
          }
        }
      }
      return thumbnailUrl;
    }

    return null;
  }

  String get displayKey => cid.hashCode.toString();

  List<Artist> get getArtists {
    return enrichmentSource?.artists ?? metadata?.artists ?? [];
  }

  String get secondaryMarketURL {
    switch (chain) {
      case 'ethereum':
        return '$OPENSEA_ASSET_PREFIX/$contractAddress/$tokenNumber';
      case 'tezos':
        if (TEIA_ART_CONTRACT_ADDRESSES.contains(contractAddress)) {
          return '$TEIA_ART_ASSET_PREFIX$tokenNumber';
        } else {
          return '$objktAssetPrefix$contractAddress/$tokenNumber';
        }
      default:
        return '';
    }
  }

  String get secondaryMarketName {
    final url = secondaryMarketURL;
    if (url.contains(OPENSEA_ASSET_PREFIX)) {
      return 'OpenSea';
    } else if (url.contains(FXHASH_IDENTIFIER)) {
      return 'FXHash';
    } else if (url.contains(TEIA_ART_ASSET_PREFIX)) {
      return 'Teia Art';
    } else if (url.contains(objktAssetPrefix)) {
      return 'Objkt';
    }
    return '';
  }

  String? getPreviewUrl() {
    final animationUrl =
        enrichmentSource?.animationUrl ?? metadata?.animationUrl;
    if (animationUrl?.isNotEmpty ?? false) {
      return animationUrl;
    }

    return getGalleryThumbnailUrl(size: null);
  }

  List<ProvenanceEvent> get provenance {
    return provenanceEvents?.items ?? [];
  }

  String? getBlockchainUrl() {
    switch (blockchain) {
      case Blockchain.ETHEREUM:
        return 'https://etherscan.io/address/$contractAddress';
      case Blockchain.TEZOS:
        return 'https://tzkt.io/$contractAddress';
    }
  }
}
