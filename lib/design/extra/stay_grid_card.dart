import 'package:bakhli/models/card_fact.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/widgets/plan_badge_chip.dart';
import '../template/fitness_app_theme.dart';
import 'card_kit.dart';
import 'travel_icon.dart';
import 'trip_pick_kit.dart';

class StayGridCard extends StatelessWidget {
  static const double height = 312;
  static const double photoHeight = 120;

  static double heightOf(BuildContext context) {
    final s = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.5).toDouble();
    return photoHeight + 18 + 170 * s;
  }

  const StayGridCard({
    super.key,
    required this.thumbnailUrl,
    required this.tagLabel,
    required this.title,
    required this.locationLabel,
    required this.facts,
    required this.priceCaption,
    required this.priceValue,
    required this.priceUnit,
    required this.onViewDetails,
    this.isFeatured = false,
  });

  final String? thumbnailUrl;
  final String tagLabel;
  final String title;
  final String locationLabel;
  final List<CardFact> facts;
  final String priceCaption;
  final String priceValue;
  final String priceUnit;
  final bool isFeatured;
  final VoidCallback onViewDetails;

  static const _tone = KitTone.stay;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: CardRadius.tile, boxShadow: ShadowTokens.elev2),
      child: Material(
        color: Colors.transparent,
        borderRadius: CardRadius.tile,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onViewDetails,
          splashColor: DesignColors.splash,
          highlightColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: photoHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LayoutBuilder(
                      builder: (_, c) => KitPhoto(url: thumbnailUrl, width: c.maxWidth, height: photoHeight, tone: _tone, iconSize: 40),
                    ),
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 36,
                      child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: DesignGradients.scrimBottom))),
                    ),
                    if (tagLabel.isNotEmpty)
                      Positioned(top: 8, left: 8, right: 8, child: Align(alignment: Alignment.topLeft, child: KitTagChip(tagLabel, tone: _tone, solid: true))),
                    if (isFeatured) Positioned(left: 8, bottom: 8, child: PlanBadgeChip(color: _tone.accentDark, compact: false)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TypeTokens.style(14, FontWeight.w700, color: DesignColors.textStrong, height: 1.2)),
                      if (locationLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const TravelIcon(TravelIcon.place, size: 12),
                          const SizedBox(width: 3),
                          Expanded(child: Text(locationLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.caption)),
                        ]),
                      ],
                      if (facts.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(spacing: 4, runSpacing: 4, children: [for (final f in facts.take(3)) KitFactChip(f, tone: _tone)]),
                      ],
                      const Spacer(),
                      Row(children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text.rich(
                              TextSpan(children: [
                                if (priceCaption.isNotEmpty) TextSpan(text: '$priceCaption ', style: TypeTokens.caption),
                                TextSpan(text: priceValue, style: TypeTokens.style(15, FontWeight.w800, color: _tone.accentDark)),
                                if (priceUnit.isNotEmpty) TextSpan(text: priceUnit, style: TypeTokens.caption),
                              ]),
                              maxLines: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(gradient: _tone.gradient, shape: BoxShape.circle),
                          child: const Icon(Icons.chevron_right_rounded, size: 20, color: DesignColors.onPrimary),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return PressScale(child: card);
  }
}

class StayFloatingPill extends StatelessWidget {
  const StayFloatingPill({
    super.key,
    required this.label,
    required this.onTap,
    this.iconAsset = TravelIcon.map,
    this.gradient = PickKit.stayGradient,
    this.shadowColor = PickKit.stay,
  });

  final String label;
  final VoidCallback onTap;
  final String iconAsset;
  final Gradient gradient;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(24));
    return Container(
      decoration: BoxDecoration(gradient: gradient, borderRadius: radius, boxShadow: PickKit.shadow(shadowColor)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TravelIcon(iconAsset, size: 22),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: FitnessAppTheme.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
