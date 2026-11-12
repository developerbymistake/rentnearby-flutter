import 'package:flutter/material.dart';
import '../template/fitness_app_theme.dart';
import 'template_motion.dart';
import 'trip_plan_look.dart';

class TripSkeletonCard extends StatelessWidget {
  const TripSkeletonCard({super.key, this.rows = 3, this.height});

  final int rows;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: TripLook.card(color: FitnessAppTheme.white, radius: TripLook.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TemplatePlaceholder(height: 14, width: 120),
          const SizedBox(height: 8),
          const TemplatePlaceholder(height: 10, width: 80),
          for (var i = 0; i < rows; i++) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                TemplatePlaceholder(height: 22, width: 22, radius: 11),
                SizedBox(width: 10),
                Expanded(child: TemplatePlaceholder(height: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
