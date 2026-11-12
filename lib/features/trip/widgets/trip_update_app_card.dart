import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
import '../../../config/app_insets.dart';
import '../../../controllers/app_version_controller.dart';
import '../trip_strings.dart';
import '../trip_strings_a4.dart';

class TripUpdateAppCard extends StatelessWidget {
  const TripUpdateAppCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(KitMetrics.gutter, 14, KitMetrics.gutter, AppInsets.bottomViewPadding(context) + 12),
      decoration: const BoxDecoration(
        color: DesignColors.surface,
        borderRadius: CardRadius.tile,
        boxShadow: ShadowTokens.elev3,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: TripLook.gradient,
                      shape: BoxShape.circle,
                      boxShadow: ShadowTokens.glow(KitTone.trip.glow),
                    ),
                    child: const Center(child: TravelIcon(TravelIcon.airplane, size: 22)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TripStrings.updateAppTitle,
                          style: TextStyle(
                              fontFamily: FitnessAppTheme.fontName, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.18, color: TripLook.textDark),
                        ),
                        SizedBox(height: 2),
                        Text(
                          TripStrings.updateAppBody,
                          style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: TripLook.textLight),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TripButton(
                label: TripStringsA4.openPlayStore,
                height: 48,
                onPressed: () => AppVersionController.to.openStore(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
