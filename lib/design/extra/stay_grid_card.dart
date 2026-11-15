import 'package:bakhli/models/card_fact.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/widgets/plan_badge_chip.dart';
import '../template/fitness_app_theme.dart';
import 'card_kit.dart';
import 'travel_icon.dart';
import 'trip_pick_kit.dart';

class StayGridCard extends StatelessWidget {
  static double get height => DS.s(300);
  static double get photoHeight => DS.s(112);

  static double heightOf(BuildContext context) {
    final s = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.5).toDouble();
    return photoHeight + DS.s(18) + DS.s(170) * s;
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
  static BorderRadius get _radius => DS.br(const BorderRadius.all(Radius.circular(16)));

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(borderRadius: _radius, boxShadow: DS.shadows(ShadowTokens.tight(_tone.accentDark))),
      child: Material(
        color: Colors.transparent,
        borderRadius: _radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: _radius,
            gradient: LinearGradient(
              colors: [DesignColors.surface, _tone.wash],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
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
                        builder: (_, c) => KitPhoto(url: thumbnailUrl, width: c.maxWidth, height: photoHeight, tone: _tone, iconSize: 44, rich: true),
                      ),
                      if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: DS.s(36),
                          child: const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: DesignGradients.scrimBottom))),
                        ),
                      if (tagLabel.isNotEmpty)
                        Positioned(top: DS.s(8), left: DS.s(8), right: DS.s(8), child: Align(alignment: Alignment.topLeft, child: KitTagChip(tagLabel, tone: _tone, solid: true))),
                      if (isFeatured) Positioned(left: DS.s(8), bottom: DS.s(8), child: PlanBadgeChip(color: _tone.accentDark, compact: false)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: DS.insets(l: 10, t: 8, r: 10, b: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong, height: 1.2)),
                        if (locationLabel.isNotEmpty) ...[
                          SizedBox(height: DS.s(4)),
                          Row(children: [
                            const TravelIcon(TravelIcon.place, size: 12),
                            SizedBox(width: DS.s(3)),
                            Expanded(child: Text(locationLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.style(12, FontWeight.w500, color: TypeTokens.secondary))),
                          ]),
                        ],
                        if (facts.isNotEmpty) ...[
                          SizedBox(height: DS.s(6)),
                          Wrap(spacing: DS.gh(4), runSpacing: DS.gv(4), children: [for (final f in facts.take(3)) KitFactChip(f, tone: _tone)]),
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
                                  TextSpan(text: priceValue, style: TypeTokens.style(18, FontWeight.w800, color: _tone.accentDark)),
                                  if (priceUnit.isNotEmpty) TextSpan(text: priceUnit, style: TypeTokens.caption),
                                ]),
                                maxLines: 1,
                              ),
                            ),
                          ),
                          SizedBox(width: DS.s(6)),
                          Container(
                            width: DS.s(28),
                            height: DS.s(28),
                            decoration: BoxDecoration(gradient: _tone.gradient, shape: BoxShape.circle),
                            child: Icon(Icons.chevron_right_rounded, size: DS.s(20), color: DesignColors.onPrimary),
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
    final radius = DS.br(const BorderRadius.all(Radius.circular(24)));
    return Container(
      decoration: BoxDecoration(gradient: gradient, borderRadius: radius, boxShadow: DS.shadows(PickKit.shadow(shadowColor))),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: DS.sym(h: 20, v: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TravelIcon(iconAsset, size: 22),
                SizedBox(width: DS.s(8)),
                Text(label,
                    style: TextStyle(
                        fontFamily: FitnessAppTheme.fontName,
                        fontSize: DS.f(14),
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
