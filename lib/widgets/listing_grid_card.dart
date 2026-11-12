import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../design/design.dart';
import '../models/card_fact.dart';
import 'plan_badge_chip.dart';

class ListingGridCard extends StatelessWidget {
  static const double height = 262;

  final String? thumbnailUrl;
  final String tagLabel;
  final String title;
  final String locationLabel;
  final List<CardFact> facts;
  final String priceCaption;
  final String priceValue;
  final String priceUnit;
  final bool isPlot;
  final VoidCallback onViewDetails;
  final Color? accent;
  final Color? accentDark;
  final bool isFeatured;
  final Animation<double>? animation;
  final AnimationController? animationController;

  const ListingGridCard({
    super.key,
    required this.thumbnailUrl,
    required this.tagLabel,
    required this.title,
    required this.locationLabel,
    required this.facts,
    required this.priceCaption,
    required this.priceValue,
    required this.priceUnit,
    required this.isPlot,
    required this.onViewDetails,
    this.accent,
    this.accentDark,
    this.isFeatured = false,
    this.animation,
    this.animationController,
  });

  Color get _accent => accent ?? FitnessAppTheme.nearlyDarkBlue;
  Color get _accentDark => accentDark ?? FitnessAppTheme.nearlyDarkBlue;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final card = Container(
      decoration: GateKit.cardSmall(),
      child: Material(
        color: Colors.transparent,
        borderRadius: TripKit.cardRadiusSmall,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onViewDetails,
          highlightColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 104,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    thumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: thumbnailUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: (190 * dpr).round(),
                            memCacheHeight: (104 * dpr).round(),
                            placeholder: (_, _) => const TemplatePlaceholder(height: 104, radius: 0),
                            errorWidget: (_, _, _) => _placeholder(),
                          )
                        : _placeholder(),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(38)),
                        child: Text(
                          tagLabel,
                          style: FitnessAppTheme.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: FitnessAppTheme.white,
                          ),
                        ),
                      ),
                    ),
                    if (isFeatured)
                      Positioned(top: 6, right: 6, child: PlanBadgeChip(color: _accentDark)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TripKit.text(13, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const TravelIcon(TravelIcon.place, size: 12),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FitnessAppTheme.caption.copyWith(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      if (facts.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [for (final f in facts.take(3)) _factChip(f)],
                        ),
                      ],
                      const Spacer(),
                      const SizedBox(height: 8),
                      Container(height: 1, color: FitnessAppTheme.spacer),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    priceCaption,
                                    style: FitnessAppTheme.caption
                                        .copyWith(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                                  ),
                                  const SizedBox(height: 2),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: priceValue,
                                          style: FitnessAppTheme.title
                                              .copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: PickKit.gold),
                                        ),
                                        TextSpan(
                                          text: priceUnit,
                                          style: FitnessAppTheme.caption
                                              .copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward, size: 16, color: FitnessAppTheme.darkText),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (animation == null || animationController == null) return card;
    return TemplateEntrance(animation: animation!, animationController: animationController!, child: card);
  }

  Widget _factChip(CardFact f) {
    final (bg, fg) = switch (f.tone) {
      FactTone.accent => (PickKit.tripTint, FitnessAppTheme.nearlyDarkBlue),
      FactTone.cyan => (PickKit.goodTint, FitnessAppTheme.nearlyBlue),
      FactTone.slate => (FitnessAppTheme.spacer, FitnessAppTheme.lightText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        f.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: FitnessAppTheme.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _placeholder() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              TravelPalette.skyStart.withValues(alpha: Alpha.v15),
              TravelPalette.skyEnd.withValues(alpha: Alpha.v15),
            ],
          ),
        ),
        child: const Center(child: TravelIcon(TravelIcon.stay, size: 40)),
      );
}
