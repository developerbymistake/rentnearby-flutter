import 'package:flutter/material.dart';
import '../design/design.dart';
import '../models/card_fact.dart';
import 'plan_badge_chip.dart';

class HomeCardSurface extends StatelessWidget {
  const HomeCardSurface({
    super.key,
    required this.child,
    this.onTap,
    this.shadow = ShadowTokens.elev2,
    this.radius = CardRadius.tile,
    this.color = DesignColors.surface,
    this.gradient,
  });

  final Gradient? gradient;

  final Widget child;
  final VoidCallback? onTap;
  final List<BoxShadow> shadow;
  final BorderRadius radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        borderRadius: radius,
        boxShadow: shadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: gradient == null ? null : BoxDecoration(gradient: gradient, borderRadius: radius),
          child: InkWell(
            onTap: onTap,
            splashColor: DesignColors.splash,
            highlightColor: Colors.transparent,
            child: child,
          ),
        ),
      ),
    );
    return onTap == null ? card : PressScale(child: card);
  }
}

class HomeRailTile extends StatelessWidget {
  const HomeRailTile({
    super.key,
    required this.title,
    required this.onTap,
    this.thumbnailUrl,
    this.tagLabel,
    this.locationLabel,
    this.facts = const [],
    this.priceCaption = '',
    this.priceValue = '',
    this.priceUnit = '',
    this.noPriceLabel,
    this.stackedCaption = false,
    this.isFeatured = false,
    this.tone = KitTone.stay,
    this.fallbackAsset = TravelIcon.stay,
  });

  static const double width = 148;
  static const double height = 224;
  static const double photoHeight = 92;
  static const double maxTextScale = 1.3;

  final String title;
  final VoidCallback onTap;
  final String? thumbnailUrl;
  final String? tagLabel;
  final String? locationLabel;
  final List<CardFact> facts;
  final String priceCaption;
  final String priceValue;
  final String priceUnit;
  final String? noPriceLabel;
  final bool stackedCaption;
  final bool isFeatured;
  final KitTone tone;
  final String fallbackAsset;

  Widget _price() {
    if (priceValue.isEmpty) {
      return Text(
        noPriceLabel ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TypeTokens.style(
          12,
          FontWeight.w800,
          color: tone.accentDark,
          letterSpacing: 0.8,
        ),
      );
    }
    final amount = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: priceValue,
            style: TypeTokens.style(
              18,
              FontWeight.w800,
              color: tone.accentDark,
            ),
          ),
          if (priceUnit.isNotEmpty)
            TextSpan(text: priceUnit, style: TypeTokens.caption),
        ],
      ),
      maxLines: 1,
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: priceCaption.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(priceCaption, maxLines: 1, style: TypeTokens.caption),
                amount,
              ],
            )
          : amount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: maxTextScale);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: SizedBox(
        width: width,
        height: height,
        child: HomeCardSurface(
          onTap: onTap,
          radius: CardRadius.hero,
          shadow: ShadowTokens.tight(tone.accentDark),
          gradient: LinearGradient(
            colors: [DesignColors.surface, tone.wash],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
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
                      builder: (context, c) => KitPhoto(
                        url: thumbnailUrl,
                        width: c.maxWidth,
                        height: photoHeight,
                        tone: tone,
                        asset: fallbackAsset,
                        iconSize: 36,
                        rich: true,
                      ),
                    ),
                    if (tagLabel != null && tagLabel!.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: KitTagChip(tagLabel!, tone: tone, solid: true),
                      ),
                    if (isFeatured)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: PlanBadgeChip(
                          color: tone.accentDark,
                          compact: false,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypeTokens.style(
                          16,
                          FontWeight.w700,
                          color: DesignColors.textStrong,
                          height: 1.2,
                        ),
                      ),
                      if (locationLabel != null &&
                          locationLabel!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const TravelIcon(TravelIcon.place, size: 12),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                locationLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TypeTokens.style(12, FontWeight.w500, color: TypeTokens.secondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (facts.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Expanded(
                          child: ClipRect(
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  for (final f in facts.take(3))
                                    KitFactChip(f, tone: tone),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      Row(
                        children: [
                          Expanded(child: _price()),
                          const SizedBox(width: 6),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              gradient: tone.gradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: DesignColors.onPrimary,
                            ),
                          ),
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
  }
}
