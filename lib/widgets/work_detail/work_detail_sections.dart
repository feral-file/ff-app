import 'dart:collection';

import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/extensions/asset_token_ext.dart';
import 'package:app/domain/extensions/extensions.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/theme/app_color.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jiffy/jiffy.dart';
import 'package:url_launcher/url_launcher.dart';

// Dividers matching old artwork detail page (non-const to use LayoutConstants)
final Widget _artworkDataDivider = Divider(
  height: LayoutConstants.space8,
  color: const Color.fromRGBO(255, 255, 255, 0.3),
  thickness: LayoutConstants.dividerThickness,
);

final Widget _artworkSectionDivider = Divider(
  height: LayoutConstants.space1,
  color: AppColor.white,
  thickness: LayoutConstants.dividerThickness,
);

/// Expandable section with header and optional divider (matches old repo).
class SectionExpandedWidget extends StatefulWidget {
  const SectionExpandedWidget({
    super.key,
    this.header,
    this.headerStyle,
    this.headerPadding,
    this.child,
    this.iconOnExpanded,
    this.iconOnUnExpanded,
    this.withDivider = true,
    this.padding = EdgeInsets.zero,
    this.isExpandedDefault = false,
  });

  final String? header;
  final TextStyle? headerStyle;
  final EdgeInsets? headerPadding;
  final Widget? child;
  final Widget? iconOnExpanded;
  final Widget? iconOnUnExpanded;
  final bool withDivider;
  final EdgeInsets padding;
  final bool isExpandedDefault;

  @override
  State<SectionExpandedWidget> createState() => _SectionExpandedWidgetState();
}

class _SectionExpandedWidgetState extends State<SectionExpandedWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpandedDefault;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultIcon = Icon(
      Icons.chevron_right,
      size: LayoutConstants.iconSizeSmall,
      color: theme.colorScheme.secondary,
    );
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.withDivider) _artworkSectionDivider,
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: ColoredBox(
              color: Colors.transparent,
              child: Padding(
                padding:
                    widget.headerPadding ??
                    EdgeInsets.only(top: LayoutConstants.space4),
                child: Row(
                  children: [
                    Text(
                      widget.header ?? '',
                      style:
                          widget.headerStyle ??
                          AppTypography.body(context).white,
                    ),
                    const Spacer(),
                    if (_isExpanded)
                      widget.iconOnExpanded ??
                          RotatedBox(
                            quarterTurns: 1,
                            child: defaultIcon,
                          )
                    else
                      widget.iconOnUnExpanded ??
                          RotatedBox(
                            quarterTurns: 2,
                            child: defaultIcon,
                          ),
                  ],
                ),
              ),
            ),
          ),
          Visibility(
            visible: _isExpanded,
            child: Column(
              children: [
                SizedBox(height: LayoutConstants.space6),
                widget.child ?? const SizedBox(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single metadata row (title + value, optional link).
class MetaDataItem extends StatelessWidget {
  const MetaDataItem({
    required this.title,
    required this.value,
    super.key,
    this.titleStyle,
    this.onTap,
    this.tapLink,
    this.forceSafariVC,
    this.linkStyle,
    this.valueStyle,
  });

  final String title;
  final String value;
  final TextStyle? titleStyle;
  final VoidCallback? onTap;
  final String? tapLink;
  final bool? forceSafariVC;
  final TextStyle? linkStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    var onValueTap = onTap;
    if (onValueTap == null && tapLink != null && tapLink!.isNotEmpty) {
      final uri = Uri.parse(tapLink!);
      onValueTap = () async {
        await launchUrl(
          uri,
          mode: forceSafariVC ?? false
              ? LaunchMode.externalApplication
              : LaunchMode.platformDefault,
        );
      };
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            title,
            style: titleStyle ?? AppTypography.body(context).grey,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: onValueTap,
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
              style: onValueTap != null
                  ? linkStyle ??
                        AppTypography.body(
                          context,
                        ).copyWith(color: AppColor.feralFileHighlight)
                  : valueStyle ?? AppTypography.body(context).white,
            ),
          ),
        ),
      ],
    );
  }
}

/// Provenance row: title, value, optional "View" link.
class ProvenanceItem extends StatelessWidget {
  const ProvenanceItem({
    required this.title,
    required this.value,
    super.key,
    this.onTap,
    this.tapLink,
    this.forceSafariVC,
  });

  final String title;
  final String value;
  final VoidCallback? onTap;
  final String? tapLink;
  final bool? forceSafariVC;

  @override
  Widget build(BuildContext context) {
    var onValueTap = onTap;
    if (onValueTap == null && tapLink != null && tapLink!.isNotEmpty) {
      final uri = Uri.parse(tapLink!);
      onValueTap = () async {
        await launchUrl(
          uri,
          mode: forceSafariVC ?? false
              ? LaunchMode.externalApplication
              : LaunchMode.platformDefault,
        );
      };
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            title,
            style: AppTypography.body(context).white,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: AppTypography.body(context).white,
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onValueTap != null)
                GestureDetector(
                  onTap: onValueTap,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: LayoutConstants.space3,
                      vertical: LayoutConstants.space1,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColor.feralFileHighlight,
                      ),
                      borderRadius: BorderRadius.circular(
                        LayoutConstants.space16,
                      ),
                    ),
                    child: Text(
                      'View',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(context).copyWith(
                        color: AppColor.feralFileHighlight,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Format address for display (mask middle).
String _maskAddress(String address, {int visible = 5}) {
  if (address.length <= visible * 2) return address;
  return '${address.substring(0, visible)}...${address.substring(address.length - visible)}';
}

/// Format timestamp for provenance.
String _localTimeString(DateTime timestamp) {
  return Jiffy.parseFromDateTime(timestamp).format(pattern: 'MMM d, y • H:mm');
}

/// Build artist string from PlaylistItem (derived from artists list).
String artistStringFromPlaylistItem(PlaylistItem item) {
  return item.artistName;
}

/// Metadata section: from token when available, else item-only.
Widget buildWorkDetailMetadataSection(
  BuildContext context, {
  required PlaylistItem item,
  AssetToken? token,
}) {
  final artistName = token != null
      ? token.getArtists.map((a) => a.name).join(', ')
      : artistStringFromPlaylistItem(item);
  final title = token?.displayTitle ?? item.title;
  final publisherName = token?.metadata?.publisher?.name;

  return SectionExpandedWidget(
    header: 'Metadata',
    padding: EdgeInsets.only(bottom: LayoutConstants.space6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetaDataItem(title: 'Title', value: title ?? ''),
        if (artistName.isNotEmpty) ...[
          _artworkDataDivider,
          MetaDataItem(title: 'Artist', value: artistName),
        ],
        _artworkDataDivider,
        if (publisherName != null && publisherName.isNotEmpty) ...[
          MetaDataItem(
            title: 'Token',
            value: publisherName,
            tapLink: token?.metadata?.publisher?.url,
            forceSafariVC: true,
          ),
          _artworkDataDivider,
        ],
        if (token != null)
          MetaDataItem(
            title: 'Contract',
            value: token.blockchain.name,
            tapLink: token.getBlockchainUrl(),
            forceSafariVC: true,
          ),
        SizedBox(height: LayoutConstants.space8),
      ],
    ),
  );
}

/// Token ownership section (only when token is not null and user owns).
Widget buildWorkDetailTokenOwnershipSection(
  BuildContext context, {
  required List<String> ownerAddresses,
  required AssetToken token,
}) {
  final ownerItem = token.owners?.items.firstWhereOrNull(
    (e) => ownerAddresses.contains(e.ownerAddress),
  );
  if (ownerItem == null || (int.tryParse(ownerItem.quantity) ?? 0) <= 0) {
    return const SizedBox.shrink();
  }

  final displayHolder = _maskAddress(ownerItem.ownerAddress);

  return SectionExpandedWidget(
    header: 'Token ownership',
    padding: EdgeInsets.only(bottom: LayoutConstants.space6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetaDataItem(title: 'Token holder', value: displayHolder),
        _artworkDataDivider,
        MetaDataItem(
          title: 'Token held',
          value: ownerItem.quantity,
          tapLink: token.secondaryMarketURL.isNotEmpty
              ? token.secondaryMarketURL
              : null,
          forceSafariVC: true,
        ),
      ],
    ),
  );
}

/// Provenance section (only when token has provenance events).
Widget buildWorkDetailProvenanceSection(
  BuildContext context, {
  required List<String> ownerAddresses,
  required AssetToken token,
}) {
  final provenances = token.provenance;
  if (provenances.isEmpty) return const SizedBox.shrink();

  final youAddresses = HashSet<String>.from(ownerAddresses);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionExpandedWidget(
        header: 'Provenance',
        padding: EdgeInsets.only(bottom: LayoutConstants.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < provenances.length; i++) ...[
              ProvenanceItem(
                title:
                    _maskAddress(provenances[i].toAddress ?? '') +
                    (youAddresses.contains(provenances[i].toAddress)
                        ? ' (you)'
                        : ''),
                value: _localTimeString(provenances[i].timestamp),
                tapLink: provenances[i].txUrl,
                forceSafariVC: true,
              ),
              if (i < provenances.length - 1) _artworkDataDivider,
            ],
          ],
        ),
      ),
    ],
  );
}

/// Right section placeholder. Matches old repo artworkDetailsRightSection (empty).
Widget buildWorkDetailRightSection(
  BuildContext context,
  PlaylistItem item,
  AssetToken? token,
) {
  return const SizedBox.shrink();
}
