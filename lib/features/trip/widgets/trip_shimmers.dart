import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

class TripShimmers {
  static Widget rowBox({double height = 76, double radius = 16}) => TemplatePlaceholder(height: DS.s(height), radius: DS.radius(radius));

  static Widget card({required double height, required Widget child, BorderRadius radius = TripEntryStyle.ringRadius}) => Container(
        height: DS.s(height),
        padding: DS.insets(l: 14, t: 12, r: 14, b: 12),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(radius), boxShadow: DS.shadows(TripEntryStyle.cardShadow)),
        child: child,
      );
}

class TripSpotRowSkeleton extends StatelessWidget {
  const TripSpotRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) => TripShimmers.card(
        height: 188,
        radius: TripEntryStyle.cardRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: TemplatePlaceholder(height: double.infinity, radius: DS.radius(8))),
            Gap.v(10),
            TemplatePlaceholder(height: DS.s(14), radius: DS.radius(8)),
            Gap.v(6),
            Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: 0.5, child: TemplatePlaceholder(height: DS.s(12), radius: DS.radius(8)))),
          ],
        ),
      );
}

class TripDayCardSkeleton extends StatelessWidget {
  const TripDayCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: DS.gv(10)),
        child: TripShimmers.card(
          height: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TemplatePlaceholder(height: DS.s(24), width: DS.s(80), radius: DS.radius(16)),
              Gap.v(14),
              TemplatePlaceholder(height: DS.s(18), radius: DS.radius(8)),
              Gap.v(10),
              TemplatePlaceholder(height: DS.s(18), radius: DS.radius(8)),
            ],
          ),
        ),
      );
}

class TripCardSkeleton extends StatelessWidget {
  const TripCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => TripShimmers.card(
        height: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TemplatePlaceholder(height: DS.s(48), width: DS.s(48), radius: DS.radius(24)),
                Gap.h(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(widthFactor: 0.7, child: TemplatePlaceholder(height: DS.s(14), radius: DS.radius(8))),
                      Gap.v(8),
                      FractionallySizedBox(widthFactor: 0.45, child: TemplatePlaceholder(height: DS.s(12), radius: DS.radius(8))),
                      Gap.v(8),
                      FractionallySizedBox(widthFactor: 0.55, child: TemplatePlaceholder(height: DS.s(12), radius: DS.radius(8))),
                    ],
                  ),
                ),
                Gap.h(8),
                TemplatePlaceholder(height: DS.s(24), width: DS.s(64), radius: DS.radius(16)),
              ],
            ),
            const Spacer(),
            TemplatePlaceholder(height: DS.s(44), radius: DS.radius(16)),
          ],
        ),
      );
}
