import 'package:flutter/material.dart';
import '../template/fitness_app_theme.dart';
import 'template_motion.dart';
import 'trip_plan_look.dart';
import 'package:bakhli/design/tokens/design_scale.dart';

class TripSkeletonCard extends StatelessWidget {
  const TripSkeletonCard({super.key, this.rows = 3, this.height});

  final int rows;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: EdgeInsets.only(bottom: DS.gv(14)),
      padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(14), DS.s(16), DS.s(14)),
      decoration: TripLook.card(color: FitnessAppTheme.white, radius: TripLook.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TemplatePlaceholder(height: DS.s(14), width: DS.s(120)),
          SizedBox(height: DS.s(8)),
          TemplatePlaceholder(height: DS.s(10), width: DS.s(80)),
          for (var i = 0; i < rows; i++) ...[
            SizedBox(height: DS.s(12)),
            Row(
              children: [
                TemplatePlaceholder(height: DS.s(22), width: DS.s(22), radius: DS.radius(11)),
                SizedBox(width: DS.s(10)),
                Expanded(child: TemplatePlaceholder(height: DS.s(12), radius: DS.radius(8))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
