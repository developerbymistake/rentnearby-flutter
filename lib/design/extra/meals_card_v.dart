import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'motion_kit.dart';
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
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        shape: BoxShape.circle,
        boxShadow: Ink3D.goBtn,
      ),
      child: Icon(icon, color: color, size: 22),
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
    final unitMax = MediaQuery.textScalerOf(context).scale(big ? 110 : 62);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.bottomLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cap != null && cap.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 5),
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
              padding: EdgeInsets.only(left: big ? 5 : 4, bottom: big ? 4 : 3),
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
    final usable = room - 6;
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
    this.width = 160,
    this.minCardHeight = 194,
    this.semanticsLabel,
    this.wholeWords = false,
    this.titleLines = 1,
    this.descriptionLines = 2,
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
  final double width;
  final double minCardHeight;
  final String? semanticsLabel;
  final bool wholeWords;
  final int titleLines;
  final int descriptionLines;

  static const EdgeInsets cellPadding = EdgeInsets.fromLTRB(8, 46, 8, 18);

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    const white = Colors.white;
    final descMin = scaler.scale(12) * 1.55 * 2;
    final hasNumber = number != null && number!.isNotEmpty;
    final titleStyle = Ink3D.text(17, FontWeight.w700, white, height: 1.3);
    final titleRoom = width - cellPadding.horizontal - 30;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: kMealsRadius,
        gradient: tone.gradient,
        boxShadow: tone.glow(blur: 8),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minCardHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 72, 15, 12),
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
                        minHeight: scaler.scale(10.5) * 1.5,
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
                  Text(
                    KitText.fitWords(title, titleStyle, scaler, titleRoom - 1, titleLines),
                    maxLines: titleLines,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  if (description != null) const SizedBox(height: 6),
                  if (description != null)
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
                              FontWeight.w500,
                              white,
                              height: 1.55,
                            ),
                          ),
                  ),
                  if (chips != null) ...[
                    const SizedBox(height: 6),
                    _ChipsRow(
                      chips!,
                      height: (scaler.scale(10.5) * 1.35 + 4) * 2 + 6,
                      maxChipWidth: width - 30,
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (caption != null && hasNumber)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: scaler.scale(10.5) * 1.4,
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
                      constraints: BoxConstraints(minHeight: scaler.scale(30)),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: PriceLine(
                          number: number!,
                          unit: unit,
                          numberSize: RegExp(r'\d').hasMatch(number!) ? 26 : 17,
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
      child: const SizedBox(width: 112, height: 112),
    );
    Widget body = SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: [
          Padding(padding: cellPadding, child: card),
          if (photo != null) ...[
            Positioned(left: 6, top: 0, child: halo),
            Positioned(
              left: 12,
              top: 2,
              child: PhotoSticker(
                photo: photo!,
                sticker: sticker ?? '',
                size: 100,
                stickerSize: 52,
                stickerOffset: const Offset(66, 64),
              ),
            ),
          ] else if (art != null) ...[
            Positioned(left: 6, top: 0, child: halo),
            Positioned(
              left: 8,
              top: -6,
              child: Art3D(
                asset: art!,
                size: 110,
                shadowBlur: 5,
                shadowOffset: const Offset(4, 6),
                shadowAlpha: 0.22,
              ),
            ),
          ],
        ],
      ),
    );
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
          spacing: 5,
          runSpacing: 6,
          children: [
            for (final chip in chips)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxChipWidth),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
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
      padding: padding,
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
      padding: padding,
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
  const MealsCardSkeleton({super.key, this.width = 160});

  final double width;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final height = 104 + 90 * (scale < 1 ? 1.0 : scale);
    return SizedBox(
      width: width,
      child: Padding(
        padding: MealsCardV.cellPadding,
        child: Container(
          height: height,
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: kMealsRadius,
            boxShadow: Ink3D.softShadow,
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TemplatePlaceholder(height: 48, width: 48, radius: 24),
              SizedBox(height: 10),
              TemplatePlaceholder(height: 16, width: 96),
              SizedBox(height: 12),
              TemplatePlaceholder(height: 10, width: 76),
              SizedBox(height: 8),
              TemplatePlaceholder(height: 10, width: 60),
              Spacer(),
              TemplatePlaceholder(height: 22, width: 64),
            ],
          ),
        ),
      ),
    );
  }
}
