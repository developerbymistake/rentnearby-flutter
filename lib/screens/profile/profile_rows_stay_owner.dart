import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../design/design.dart';
import '../../features/stay_owner/strings/stay_profile_strings.dart';

class StayOwnerProfileRows extends StatelessWidget {
  const StayOwnerProfileRows({super.key});

  static void _planTrip() {
    if (Get.isRegistered<AuthController>()) Get.find<AuthController>().openPlace(AppPlace.trips);
  }

  static List<Widget> activityRows() => [
        IconRow3D(
          key: const ValueKey('stay_profile_plan_trip'),
          art: ListingArt.worldMap,
          title: StayProfileStrings.planATrip,
          subtitle: StayProfileStrings.travelAsGuest,
          onTap: _planTrip,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            StatusPill3D(label: StayProfileStrings.newChip, color: StatusTone3D.both.pillText, onGradient: false),
            Icon(Icons.chevron_right_rounded, size: DS.s(22), color: DesignColors.textDisabled),
          ]),
        ),
      ];

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
