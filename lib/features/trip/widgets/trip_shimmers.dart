import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

class TripShimmers {
  static Widget rowBox({double height = 76, double radius = 16}) => TemplatePlaceholder(height: height, radius: radius);

  static Widget card({required double height, required Widget child, BorderRadius radius = TripEntryStyle.ringRadius}) => Container(
        height: height,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: radius, boxShadow: TripEntryStyle.cardShadow),
        child: child,
      );
}

class TripSpotRowSkeleton extends StatelessWidget {
  const TripSpotRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) => TripShimmers.card(
        height: 188,
        radius: TripEntryStyle.cardRadius,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: TemplatePlaceholder(height: double.infinity)),
            SizedBox(height: 10),
            TemplatePlaceholder(height: 14),
            SizedBox(height: 6),
            Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: 0.5, child: TemplatePlaceholder(height: 12))),
          ],
        ),
      );
}

class TripDayCardSkeleton extends StatelessWidget {
  const TripDayCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TripShimmers.card(
          height: 150,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TemplatePlaceholder(height: 24, width: 80, radius: 16),
              SizedBox(height: 14),
              TemplatePlaceholder(height: 18),
              SizedBox(height: 10),
              TemplatePlaceholder(height: 18),
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
                const TemplatePlaceholder(height: 48, width: 48, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FractionallySizedBox(widthFactor: 0.7, child: TemplatePlaceholder(height: 14)),
                      const SizedBox(height: 8),
                      const FractionallySizedBox(widthFactor: 0.45, child: TemplatePlaceholder(height: 12)),
                      const SizedBox(height: 8),
                      const FractionallySizedBox(widthFactor: 0.55, child: TemplatePlaceholder(height: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const TemplatePlaceholder(height: 24, width: 64, radius: 16),
              ],
            ),
            const Spacer(),
            const TemplatePlaceholder(height: 44, radius: 16),
          ],
        ),
      );
}
