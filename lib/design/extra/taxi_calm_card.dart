import 'package:flutter/material.dart';

import '../../features/nearby/card_strings.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/design_scale.dart';
import '../tokens/listing_palette.dart';
import '../tokens/type_tokens.dart';
import 'art_3d.dart';
import 'calm_card_kit.dart';
import 'motion_kit.dart';
import 'photo_circle.dart';

class TaxiCalmCard extends StatelessWidget {
  const TaxiCalmCard({
    super.key,
    required this.title,
    this.lines = const [],
    this.lineMax = 1,
    this.tag = CardStrings.taxi,
    this.photoUrl,
    required this.art,
    this.featured = false,
    this.chips = const [],
    required this.price,
    this.unit = '',
    this.address,
    this.note,
    this.actions = const [],
    this.moreActions = const [],
    this.picked = false,
    this.onTap,
    this.semanticsLabel,
  });

  final String title;
  final List<String> lines;
  final int lineMax;
  final String tag;
  final String? photoUrl;
  final String art;
  final bool featured;
  final List<String> chips;
  final String price;
  final String unit;
  final String? address;
  final String? note;
  final List<CalmAction> actions;
  final List<CalmAction> moreActions;
  final bool picked;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  static const ListingPalette palette = ListingPalette.coral;
  static const double stickOut = 0.10;
  static const double topSpace = 30;

  static double circleFor(double cardWidth) => cardWidth < 300 ? 104 : cardWidth < 340 ? 120 : 136;

  Widget _header(double c) {
    final shown = [for (final l in lines) if (l.trim().isNotEmpty) l.trim()];
    final secondary = TypeTokens.style(12, FontWeight.w500, color: CalmText.secondary);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: DS.s(c - 24)),
      child: Padding(
        padding: EdgeInsets.only(left: DS.s(c + 22), right: DS.s(18)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CalmChip(tag, palette: palette, kind: CalmChipKind.tag, fg: palette.text),
              Gap.v(5),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong, height: 1.2),
              ),
              for (var i = 0; i < shown.length; i++) ...[
                if (i == 0) Gap.v(2),
                _line(shown[i], secondary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String text, TextStyle style) {
    final line = Text(text, maxLines: lineMax, overflow: TextOverflow.ellipsis, style: style);
    if (lineMax < 2) return line;
    return Stack(
      children: [
        ExcludeSemantics(child: Opacity(opacity: 0, child: Text('\n' * (lineMax - 1), maxLines: lineMax, style: style))),
        line,
      ],
    );
  }

  Widget _mid() {
    final shown = [for (final c in chips) if (c.trim().isNotEmpty) c.trim()];
    return Padding(
      padding: DS.insets(l: 16, t: 8, r: 16, b: 10),
      child: LayoutBuilder(
        builder: (context, box) => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
                spacing: DS.gh(6),
                runSpacing: DS.gv(6),
                children: [for (final c in shown) CalmChip(c, palette: palette)],
              ),
            ),
            Gap.h(12),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth.isFinite ? box.maxWidth * 0.5 : double.infinity),
              child: CalmPriceBlock(
                palette: palette,
                value: price,
                unit: unit,
                valueColor: palette.text,
                minWidth: 92,
                unitAlign: TextAlign.left,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moreRow() => Padding(
        padding: DS.insets(l: 12, r: 12, b: 12),
        child: Align(
          alignment: Alignment.centerRight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < moreActions.length; i++) ...[
                  if (i > 0) Gap.h(5),
                  CalmPillButton(action: moreActions[i], palette: palette),
                ],
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final radius = DS.br(CardRadius.hero);
    return Padding(
      padding: DS.insets(l: 14, r: 14, t: topSpace),
      child: LayoutBuilder(builder: (context, box) {
        final c = circleFor(box.maxWidth);
        final hasBottom = actions.isNotEmpty || (address != null && address!.trim().isNotEmpty);
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
            child: Padding(
              padding: EdgeInsets.only(top: DS.s(12)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(c),
                  _mid(),
                  if (hasBottom)
                    CalmBottomRow(
                      palette: palette,
                      address: address,
                      note: note,
                      actions: actions,
                      padding: DS.insets(l: 12, t: 9, r: 12, b: 12),
                    ),
                  if (moreActions.isNotEmpty) _moreRow(),
                ],
              ),
            ),
          ),
        );
        final tap = onTap;
        if (tap != null) {
          card = PressScale(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: tap, child: card));
        }
        return Semantics(
          label: semanticsLabel ?? title,
          button: true,
          container: true,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              card,
              Positioned(
                left: DS.s(8),
                top: -DS.s(c * stickOut),
                child: PhotoCircle(
                  url: photoUrl,
                  art: art,
                  size: c,
                  tone: ListingTone.coral,
                  star: featured,
                  starSize: c * PhotoCircle.starRatio,
                  starOffset: Offset(c * 0.71, -c * 0.15),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
