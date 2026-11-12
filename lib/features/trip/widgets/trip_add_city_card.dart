import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
import 'package:get/get.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_navigation.dart';
import '../trip_strings_mca_a3.dart';

class TripAddCityCard extends StatelessWidget {
  const TripAddCityCard({super.key});

  static String? _disabledText(TripLegEditBlock b) => switch (b) {
        TripLegEditBlock.offline => TripStringsMcaA3.connectToAddCity,
        TripLegEditBlock.maxLegs => TripStringsMcaA3.maxCities,
        TripLegEditBlock.noDays => TripStringsMcaA3.noDaysLeft,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final p = c.plan.value;
      c.offline.value;
      c.trip.value;
      if (p == null || c.isReadOnly || c.needsUpdate.value) return const SizedBox.shrink();
      final block = c.canAddLeg(null);
      if (block == TripLegEditBlock.readOnly) return const SizedBox.shrink();
      final disabled = _disabledText(block);
      final enabled = block == TripLegEditBlock.none;
      final tone = enabled ? TripEntryStyle.accent : FitnessAppTheme.deactivatedText;
      return TemplateEntranceOnce(
        child: Semantics(
        button: true,
        enabled: enabled,
        child: TripSurface(
          onTap: enabled ? () => TripNavigation.addCity(context) : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: enabled ? TripEntryStyle.gradient : null,
                      color: enabled ? null : TripEntryStyle.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add_rounded, size: 22, color: enabled ? FitnessAppTheme.white : tone),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          TripStringsMcaA3.addAnotherCity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: FitnessAppTheme.fontName,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: enabled ? FitnessAppTheme.darkerText : FitnessAppTheme.deactivatedText),
                        ),
                        Text(
                          disabled ?? TripStringsMcaA3.upToFourCities,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: FitnessAppTheme.lightText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ),
        ),
      ),
      );
    });
  }
}
