import 'package:bakhli/design/tokens/design_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../utils/photo_url.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/listing_palette.dart';
import 'art_3d.dart';
import 'motion_kit.dart';
import 'photo_circle.dart';
import 'template_motion.dart';
import 'wide_card.dart';

const BorderRadius kMealsRadius = BorderRadius.only(
  topLeft: Radius.circular(8),
  topRight: Radius.circular(54),
  bottomLeft: Radius.circular(8),
  bottomRight: Radius.circular(8),
);

class RoundGoButton extends StatelessWidget {
  const RoundGoButton({
    super.key,
    required this.color,
    this.size = 38,
    this.icon = Icons.arrow_forward,
    this.onTap,
  });

  final Color color;
  final double size;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: DS.s(size),
      height: DS.s(size),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        shape: BoxShape.circle,
        boxShadow: DS.shadows(Ink3D.goBtn),
      ),
      child: Icon(icon, color: color, size: DS.s(22)),
    );
    if (onTap == null) return button;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: button,
    );
  }
}

class PriceLine extends StatelessWidget {
  const PriceLine({
    super.key,
    required this.number,
    this.unit = '',
    this.numberSize = 26,
    this.unitSize = 11,
    this.caption,
  });

  final String number;
  final String unit;
  final double numberSize;
  final double unitSize;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final big = numberSize > 26;
    final cap = caption;
    final unitMax = DS.s(MediaQuery.textScalerOf(context).scale(big ? 110 : 62));
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.bottomLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cap != null && cap.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: DS.s(6), bottom: DS.s(5)),
              child: Text(
                cap,
                maxLines: 1,
                style: Ink3D.text(
                  11,
                  FontWeight.w700,
                  white.withValues(alpha: 0.9),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          Text(
            number,
            maxLines: 1,
            softWrap: false,
            style: Ink3D.text(numberSize, FontWeight.w500, white, height: 1),
          ),
          if (unit.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: DS.s(big ? 5 : 4), bottom: DS.s(big ? 4 : 3)),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: unitMax),
                child: Text(
                  unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(unitSize, FontWeight.w500, white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class WholeWordLine extends StatelessWidget {
  const WholeWordLine(this.text, {super.key, required this.style, this.maxWidth});

  final String text;
  final TextStyle style;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final room = maxWidth;
    if (room == null) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(text, maxLines: 1, softWrap: false, style: style),
      );
    }
    final scaler = MediaQuery.textScalerOf(context);
    double widthOf(String t, TextStyle st) {
      final tp = TextPainter(text: TextSpan(text: t, style: st), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)..layout();
      final w = tp.width;
      tp.dispose();
      return w;
    }

    var longest = 0.0;
    for (final w in text.split(RegExp(r'\s+'))) {
      final x = widthOf(w, style);
      if (x > longest) longest = x;
    }
    final usable = room - DS.s(6);
    final fit = longest <= usable ? 1.0 : (usable / longest).clamp(0.7, 1.0);
    final st = fit == 1.0 ? style : style.copyWith(fontSize: (style.fontSize ?? 12) * fit);
    return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: st);
  }
}

class MealsCardV extends StatelessWidget {
  const MealsCardV({
    super.key,
    required this.tone,
    required this.title,
    this.description,
    this.art,
    this.photo,
    this.sticker,
    this.tag,
    this.chips,
    this.caption,
    this.number,
    this.unit = '',
    this.goIcon = Icons.arrow_forward,
    this.onTap,
    this.width,
    this.minCardHeight = 194,
    this.semanticsLabel,
    this.wholeWords = false,
    this.titleLines = 1,
    this.descriptionLines = 2,
    this.uniformSlots = false,
    this.starBadge = false,
    this.cellBottom = 18,
    this.compact = false,
    this.rail = false,
    this.photoUrl,
  });

  final ListingTone tone;
  final String title;
  final String? description;
  final String? art;
  final Widget? photo;
  final String? sticker;
  final String? tag;
  final List<String>? chips;
  final String? caption;
  final String? number;
  final String unit;
  final IconData goIcon;
  final VoidCallback? onTap;
  final double? width;
  final double minCardHeight;
  final String? semanticsLabel;
  final bool wholeWords;
  final int titleLines;
  final int descriptionLines;
  final bool uniformSlots;
  final bool starBadge;
  final double cellBottom;
  final bool compact;
  final bool rail;
  final String? photoUrl;

  static double get slotGap => DS.s(16);

  static EdgeInsets get cellPadding => DS.insets(l: 8, t: 46, r: 8, b: 18);

  static EdgeInsets get railCellPadding => DS.insets(l: 8, t: 16, r: 8, b: 18);

  static const double railArtTop = 108;
  static const double railPad = 14;
  static const double railTitleHeight = 1.2;
  static const double railPlaceHeight = 1.5;
  static const double railTagHeight = 1.3;
  static const double railCaptionHeight = 1.4;
  static final RegExp _digit = RegExp(r'\d');

  static double railMinHeight(TextScaler scaler, {int titleLines = 2, bool digits = true}) {
    double line(double size, double height) => scaler.scale(DS.f(size)) * height;
    final price = digits ? line(26, 1) : line(17, 1);
    final go = DS.s(38);
    return DS.s(railArtTop + railPad) +
        line(10.5, railTagHeight) +
        DS.s(6) +
        DS.s(6) +
        line(17, railTitleHeight) * titleLines +
        DS.s(2) +
        line(12, railPlaceHeight) +
        DS.s(12) +
        DS.s(1) +
        DS.s(8) +
        line(10.5, railCaptionHeight) +
        (price > go ? price : go);
  }

  Widget _wrap(Widget body) {
    if (onTap != null) {
      body = PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: body,
        ),
      );
    }
    if (semanticsLabel == null) return body;
    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      container: true,
      excludeSemantics: true,
      child: body,
    );
  }

  Widget _railBody(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    const white = Colors.white;
    final width = this.width ?? DS.s(160);
    final inner = width - railCellPadding.horizontal - DS.s(railPad * 2);
    final value = number ?? '';
    final hasNumber = value.isNotEmpty;
    final digits = _digit.hasMatch(value);
    final cap = caption ?? '';
    final place = description?.trim() ?? '';
    final label = tag?.trim() ?? '';
    final titleStyle = Ink3D.text(17, FontWeight.w700, white, height: railTitleHeight);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: DS.br(kMealsRadius),
        gradient: tone.gradient,
        boxShadow: tone.glow(blur: 8),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: railMinHeight(scaler, titleLines: titleLines, digits: digits || !hasNumber)),
        child: Padding(
          padding: DS.insets(l: railPad, t: railArtTop, r: railPad, b: railPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (label.isNotEmpty)
                    Container(
                      padding: DS.sym(h: 8, v: 3),
                      decoration: BoxDecoration(color: white.withValues(alpha: Alpha.v22), borderRadius: DS.br(CardRadius.chip)),
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: Ink3D.text(10.5, FontWeight.w700, white, letterSpacing: 0.5, height: railTagHeight),
                      ),
                    ),
                  Gap.v(6),
                  Text(
                    KitText.fitWords(title, titleStyle, scaler, inner - 1, titleLines),
                    maxLines: titleLines,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  if (place.isNotEmpty) ...[
                    Gap.v(2),
                    Text(
                      place,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: Ink3D.text(12, FontWeight.w500, white, height: railPlaceHeight),
                    ),
                  ],
                  Gap.v(12),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: DS.s(1), width: double.infinity, color: white.withValues(alpha: Alpha.scrim)),
                  Gap.v(8),
                  if (cap.isNotEmpty && hasNumber)
                    Text(
                      cap,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ink3D.text(10.5, FontWeight.w700, white.withValues(alpha: Alpha.v90), letterSpacing: 0.6, height: railCaptionHeight),
                    ),
                  if (hasNumber)
                    PriceLine(number: value, unit: unit, numberSize: digits ? 26 : 17)
                  else
                    RoundGoButton(color: tone.button, icon: goIcon),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    final url = PhotoUrl.parse(photoUrl);
    final pictureArt = art ?? (url != null ? ListingArt.stay : null);
    return _FixedWidth(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: [
          Padding(padding: railCellPadding.copyWith(bottom: DS.s(cellBottom)), child: card),
          if (pictureArt != null)
            Positioned(
              left: DS.s(6),
              top: 0,
              child: PhotoCircle(url: url, art: pictureArt, size: 112, photoSize: 100, artSize: 110),
            ),
          if (starBadge && pictureArt != null) Positioned(left: DS.s(90), top: DS.s(-8), child: const StarBadge()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (rail) return _wrap(_railBody(context));
    final scaler = MediaQuery.textScalerOf(context);
    const white = Colors.white;
    final width = this.width ?? DS.s(160);
    final minCardHeight = DS.s(this.minCardHeight);
    final cellBottom = DS.s(this.cellBottom);
    final descMin = scaler.scale(DS.f(12)) * 1.55 * (compact ? 1 : 2);
    final hasNumber = number != null && number!.isNotEmpty;
    final titleStyle = Ink3D.text(17, FontWeight.w700, white, height: 1.3);
    final titleRoom = width - cellPadding.horizontal - DS.s(30);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: DS.br(kMealsRadius),
        gradient: tone.gradient,
        boxShadow: compact ? DS.shadows(const [BoxShadow(color: Color(0x2E000000), offset: Offset(0, 6), blurRadius: 12)]) : tone.glow(blur: 8),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minCardHeight),
        child: Padding(
          padding: DS.insets(l: 15, t: 72, r: 15, b: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tag != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: scaler.scale(DS.f(10.5)) * 1.5,
                      ),
                      child: StarText(
                        tag!.toUpperCase(),
                        style: Ink3D.text(
                          10.5,
                          FontWeight.w700,
                          white.withValues(alpha: 0.9),
                          letterSpacing: 0.6,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: uniformSlots ? scaler.scale(DS.f(17)) * 1.3 * titleLines : 0,
                    ),
                    child: Text(
                      KitText.fitWords(title, titleStyle, scaler, titleRoom - 1, titleLines),
                      maxLines: titleLines,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                  if (description != null || uniformSlots) SizedBox(height: DS.s(6)),
                  if (uniformSlots)
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: scaler.scale(DS.f(12)) * 1.55),
                      child: Text(
                        description ?? '',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: Ink3D.text(12, FontWeight.w500, white, height: 1.55),
                      ),
                    )
                  else if (description != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: descMin),
                    child: wholeWords
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final l
                                  in description!
                                      .split('\n')
                                      .where((e) => e.isNotEmpty)
                                      .take(2))
                                WholeWordLine(
                                  l,
                                  style: Ink3D.text(
                                    12,
                                    FontWeight.w500,
                                    white,
                                    height: 1.55,
                                  ),
                                ),
                            ],
                          )
                        : Text(
                            description!,
                            maxLines: descriptionLines,
                            overflow: TextOverflow.ellipsis,
                            style: Ink3D.text(
                              12,
                              compact ? FontWeight.w400 : FontWeight.w500,
                              white,
                              height: 1.55,
                            ),
                          ),
                  ),
                  if (chips != null || uniformSlots) ...[
                    SizedBox(height: DS.s(uniformSlots ? 8 : 6)),
                    _ChipsRow(
                      chips ?? const [],
                      height: (scaler.scale(DS.f(10.5)) * 1.35 + DS.s(4)) * (uniformSlots ? 1 : 2) + (uniformSlots ? 0 : DS.gv(6)),
                      maxChipWidth: width - DS.s(30),
                    ),
                  ],
                  SizedBox(height: uniformSlots ? slotGap : (compact ? 0 : DS.s(8))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (caption != null && hasNumber)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: scaler.scale(DS.f(10.5)) * 1.4,
                      ),
                      child: Text(
                        caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Ink3D.text(
                          10.5,
                          FontWeight.w700,
                          white.withValues(alpha: 0.9),
                          letterSpacing: 0.6,
                          height: 1.4,
                        ),
                      ),
                    ),
                  if (hasNumber)
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: scaler.scale(DS.f(30))),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: compact ? DS.s(5) : 0),
                          child: PriceLine(
                          number: number!,
                          unit: unit,
                          numberSize: RegExp(r'\d').hasMatch(number!) ? 26 : 17,
                          ),
                        ),
                      ),
                    )
                  else
                    RoundGoButton(color: tone.button, icon: goIcon),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    final halo = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: white.withValues(alpha: 0.22),
      ),
      child: SizedBox(width: DS.s(112), height: DS.s(112)),
    );
    final body = _FixedWidth(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: [
          Padding(padding: cellPadding.copyWith(bottom: cellBottom), child: card),
          if (photo != null) ...[
            Positioned(left: DS.s(6), top: 0, child: halo),
            Positioned(
              left: DS.s(12),
              top: DS.s(2),
              child: PhotoSticker(
                photo: photo!,
                sticker: sticker ?? '',
                size: 100,
                stickerSize: 52,
                stickerOffset: const Offset(66, 64),
              ),
            ),
          ] else if (art != null) ...[
            Positioned(left: DS.s(6), top: 0, child: halo),
            Positioned(
              left: DS.s(8),
              top: DS.s(-6),
              child: Art3D(
                asset: art!,
                size: 110,
                shadowBlur: 5,
                shadowOffset: const Offset(4, 6),
                shadowAlpha: 0.22,
              ),
            ),
          ],
          if (starBadge && (photo != null || art != null))
            Positioned(left: DS.s(90), top: DS.s(-8), child: const StarBadge()),
        ],
      ),
    );
    return _wrap(body);
  }
}

class StarBadge extends StatelessWidget {
  const StarBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('meals-star-badge'),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: DS.shadowBlur(8),
            offset: DS.shadowOffset(const Offset(0, 3)),
          ),
        ],
      ),
      child: SizedBox(
        width: DS.s(30),
        height: DS.s(30),
        child: Icon(Icons.star_rounded, size: DS.s(19), color: DesignColors.amber),
      ),
    );
  }
}

class _ChipsRow extends StatelessWidget {
  const _ChipsRow(
    this.chips, {
    required this.height,
    required this.maxChipWidth,
  });

  final List<String> chips;
  final double height;
  final double maxChipWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          spacing: DS.gh(5),
          runSpacing: DS.gv(6),
          children: [
            for (final chip in chips)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxChipWidth),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.26),
                    borderRadius: DS.circular(10),
                  ),
                  child: Padding(
                    padding: DS.sym(h: 8, v: 2),
                    child: StarText(
                      chip,
                      style: Ink3D.text(
                        10.5,
                        FontWeight.w700,
                        Colors.white,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MealsRail extends StatelessWidget {
  const MealsRail({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 10),
    this.physics,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: DS.insets(l: padding.left, t: padding.top, r: padding.right, b: padding.bottom),
      physics: physics,
      clipBehavior: Clip.none,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class MealsGrid extends StatelessWidget {
  const MealsGrid({
    super.key,
    required this.count,
    required this.cardBuilder,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
  });

  final int count;
  final Widget Function(BuildContext context, int index, double width)
  cardBuilder;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: DS.insets(l: padding.left, t: padding.top, r: padding.right, b: padding.bottom),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / 2;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i += 2)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cardBuilder(context, i, w),
                      if (i + 1 < count)
                        cardBuilder(context, i + 1, w)
                      else
                        SizedBox(width: w),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class MealsCardSkeleton extends StatelessWidget {
  const MealsCardSkeleton({super.key, this.width});

  final double? width;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final height = DS.s(104) + DS.s(90) * (scale < 1 ? 1.0 : scale);
    return SizedBox(
      width: width ?? DS.s(160),
      child: Padding(
        padding: MealsCardV.cellPadding,
        child: Container(
          height: height,
          padding: DS.insets(l: 15, t: 14, r: 15, b: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: DS.br(kMealsRadius),
            boxShadow: DS.shadows(Ink3D.softShadow),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TemplatePlaceholder(height: DS.s(48), width: DS.s(48), radius: DS.radius(24)),
              SizedBox(height: DS.s(10)),
              TemplatePlaceholder(height: DS.s(16), width: DS.s(96), radius: DS.radius(8)),
              SizedBox(height: DS.s(12)),
              TemplatePlaceholder(height: DS.s(10), width: DS.s(76), radius: DS.radius(8)),
              SizedBox(height: DS.s(8)),
              TemplatePlaceholder(height: DS.s(10), width: DS.s(60), radius: DS.radius(8)),
              const Spacer(),
              TemplatePlaceholder(height: DS.s(22), width: DS.s(64), radius: DS.radius(8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FixedWidth extends SingleChildRenderObjectWidget {
  const _FixedWidth({required this.width, required super.child});

  final double width;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFixedWidth(BoxConstraints.tightFor(width: width), width);

  @override
  void updateRenderObject(BuildContext context, _RenderFixedWidth renderObject) {
    renderObject
      ..additionalConstraints = BoxConstraints.tightFor(width: width)
      ..fixedWidth = width;
  }
}

class _RenderFixedWidth extends RenderConstrainedBox {
  _RenderFixedWidth(BoxConstraints constraints, this.fixedWidth) : super(additionalConstraints: constraints);

  double fixedWidth;

  @override
  double computeMinIntrinsicHeight(double width) => super.computeMinIntrinsicHeight(fixedWidth);

  @override
  double computeMaxIntrinsicHeight(double width) => super.computeMaxIntrinsicHeight(fixedWidth);
}
