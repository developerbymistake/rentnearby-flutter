import 'package:flutter/material.dart';

import '../../features/nearby/card_strings.dart';
import '../../utils/photo_url.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/design_scale.dart';
import '../tokens/listing_palette.dart';
import '../tokens/type_tokens.dart';
import 'art_3d.dart';
import 'calm_card_kit.dart';
import 'card_kit.dart';
import 'motion_kit.dart';
import 'travel_icon.dart';

class StayPhotoCard extends StatelessWidget {
  const StayPhotoCard({
    super.key,
    required this.palette,
    required this.title,
    required this.place,
    this.photoUrl,
    this.art = ListingArt.stay,
    this.featured = false,
    this.chips = const [],
    this.leadChip,
    required this.price,
    this.caption = CardStrings.from,
    this.unit = CardStrings.perNight,
    this.was,
    this.offTag,
    this.address,
    this.note,
    this.actions = const [],
    this.dimmed = false,
    this.picked = false,
    this.onTap,
    this.titleKey,
    this.semanticsLabel,
  });

  final ListingPalette palette;
  final String title;
  final String place;
  final String? photoUrl;
  final String art;
  final bool featured;
  final List<String> chips;
  final String? leadChip;
  final String price;
  final String? caption;
  final String unit;
  final String? was;
  final String? offTag;
  final String? address;
  final String? note;
  final List<CalmAction> actions;
  final bool dimmed;
  final bool picked;
  final VoidCallback? onTap;
  final Key? titleKey;
  final String? semanticsLabel;

  static const double bannerHeight = 116;
  static const double artSize = 96;
  static const double featuredStar = 13;
  static const int maxChips = 3;
  static const double priceShare = 0.45;
  static const Key featuredKey = ValueKey('stay-card-featured');
  static const Key bannerArtKey = ValueKey('stay-card-art');

  Widget _artArea() => DecoratedBox(
        key: bannerArtKey,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [palette.button, palette.g1]),
        ),
        child: Center(child: Art3D(asset: art, size: artSize)),
      );

  Widget _banner() {
    final src = PhotoUrl.parse(photoUrl);
    final p = place.trim();
    return SizedBox(
      height: DS.s(bannerHeight),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (src == null)
            _artArea()
          else
            KitPhoto(url: src, width: double.infinity, height: DS.s(bannerHeight), tone: palette.tone, asset: art, iconSize: artSize),
          if (p.isNotEmpty)
            Positioned(
              left: DS.s(8),
              top: DS.s(8),
              right: DS.s(8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: DS.sym(h: 9, v: 4),
                  decoration: BoxDecoration(
                    color: ListingPalette.forest.text.withValues(alpha: Alpha.v80),
                    borderRadius: DS.br(CardRadius.chip),
                  ),
                  child: Text(
                    p,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TypeTokens.style(9.5, FontWeight.w600, color: DesignColors.onPrimary, chip: true),
                  ),
                ),
              ),
            ),
          if (featured)
            Positioned(
              right: DS.s(10),
              bottom: DS.s(10),
              child: Container(
                key: featuredKey,
                padding: DS.sym(h: 9, v: 4),
                decoration: BoxDecoration(color: ListingPalette.forest.g2, borderRadius: DS.br(CardRadius.chip)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TravelIcon(TravelIcon.star, size: featuredStar),
                    Gap.h(4),
                    Text(
                      CardStrings.featured,
                      maxLines: 1,
                      style: TypeTokens.style(10, FontWeight.w700, color: DesignColors.onPrimary, chip: true),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    final p = place.trim();
    return Padding(
      padding: DS.insets(l: 14, t: 9, r: 14, b: 2),
      child: LayoutBuilder(
        builder: (context, box) => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CalmChip(CardStrings.forStay, palette: palette, kind: CalmChipKind.tag),
                  Gap.v(5),
                  Text(
                    title,
                    key: titleKey,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong, height: 1.2),
                  ),
                  if (p.isNotEmpty) ...[
                    Gap.v(3),
                    Text(
                      p,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TypeTokens.style(12, FontWeight.w500, color: CalmText.secondary, height: 1.35),
                    ),
                  ],
                ],
              ),
            ),
            Gap.h(14),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth.isFinite ? box.maxWidth * priceShare : double.infinity),
              child: CalmPriceBlock(
                palette: palette,
                value: price,
                caption: caption,
                unit: unit,
                was: was,
                offTag: offTag,
                minWidth: 84,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _chips() {
    final lead = leadChip;
    final shown = [for (final c in chips) if (c.trim().isNotEmpty) c.trim()].take(maxChips).toList();
    final hasLead = lead != null && lead.trim().isNotEmpty;
    if (!hasLead && shown.isEmpty) return null;
    return Padding(
      padding: DS.insets(l: 14, r: 14, t: 8),
      child: Wrap(
        spacing: DS.gh(6),
        runSpacing: DS.gv(6),
        children: [
          if (hasLead) CalmChip(lead.trim(), palette: palette, kind: CalmChipKind.muted),
          for (final c in shown) CalmChip(c, palette: palette),
        ],
      ),
    );
  }

  bool get _hasBottom => actions.isNotEmpty || (address != null && address!.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final radius = DS.circular(16);
    final chipRow = _chips();
    Widget card = Container(
      decoration: CalmCard.box(palette, radius: radius),
      foregroundDecoration: picked
          ? BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: palette.g2, width: DS.s(2), strokeAlign: BorderSide.strokeAlignOutside),
            )
          : null,
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _banner(),
            _body(),
            ?chipRow,
            if (_hasBottom) ...[
              Gap.v(8),
              CalmBottomRow(palette: palette, address: address, note: note, actions: actions),
            ] else
              Gap.v(12),
          ],
        ),
      ),
    );
    if (dimmed) card = Opacity(opacity: Alpha.v60, child: card);
    final tap = onTap;
    if (tap != null) {
      card = PressScale(
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: tap, child: card),
      );
    }
    return Padding(
      padding: DS.insets(l: 14, r: 14, b: 18),
      child: Semantics(
        label: semanticsLabel ?? '$title, $place, $price',
        button: tap != null,
        container: true,
        child: card,
      ),
    );
  }
}
