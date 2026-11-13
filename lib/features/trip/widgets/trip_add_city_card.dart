import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
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
      final tone = ListingTone.indigo;
      return TemplateEntranceOnce(
        child: Semantics(
          button: true,
          enabled: enabled,
          child: WideCard(
            kind: WideKind.slim,
            tone: tone,
            art: ListingArt.worldMap,
            title: TripStringsMcaA3.addAnotherCity,
            subtitle: disabled ?? TripStringsMcaA3.upToFourCities,
            trailing: RoundGoButton(color: tone.button, icon: Icons.add_rounded),
            trailingWidth: 50,
            dimmed: !enabled,
            reserveChips: false,
            showPrice: false,
            onTap: enabled ? () => TripNavigation.addCity(context) : null,
          ),
        ),
      );
    });
  }
}
