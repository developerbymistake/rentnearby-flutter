import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/app_routes.dart';
import '../../design/design.dart';
import '../../features/stay_owner/ring/stay_ring_switch_row.dart';
import '../../features/stay_owner/strings/stay_ring_strings.dart';

class StayOwnerProfileRows extends StatelessWidget {
  const StayOwnerProfileRows({super.key});

  static const Key ringSwitchKey = ValueKey('profile_stay_ring');
  static const Key ringReadyKey = ValueKey('profile_stay_ring_ready');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(16)),
      child: WhiteCard3D(
        child: Column(
          children: [
            const StayRingSwitchRow(key: ringSwitchKey),
            IconRow3D(
              key: ringReadyKey,
              art: ListingArt.mobilePhone,
              title: StayRingReadyStrings.title,
              subtitle: StayRingReadyStrings.subtitle,
              divider: true,
              onTap: () => Get.toNamed(AppRoutes.stayRingReady),
              trailing: Icon(Icons.chevron_right_rounded, size: DS.s(22), color: DesignColors.textDisabled),
            ),
          ],
        ),
      ),
    );
  }
}
