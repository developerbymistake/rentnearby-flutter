import 'package:flutter/material.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/screens/profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../e2e_journeys/nearby/nearby_support.dart';
import '../../support/real_phone.dart';
import 'overlay_support.dart';

void main() {
  setUpAll(() {
    loadRealFonts();
    shotsDir = r'F:\Dhasu\UI_Template_resume\Slice3\shots';
  });
  tearDown(Get.reset);

  for (final size in [phoneSize, const Size(360, 640)]) {
    for (final scale in [1.0, 1.3]) {
      overlayTest('profile end clears overlays ${size.height} x$scale', (t) async {
        Get.put<AuthController>(JAuth());
        Get.put<TabConfigController>(JTabs());
        Get.put(PlanController());
        await pumpOverlay(t, const ProfileScreen(), size: size, scale: scale);
        await scrollToEnd(t, find.byType(ProfileScreen));
        await shot(t, 'O_profile_${size.height.toInt()}_$scale');
        expect(contentBottom(t, find.byType(ProfileScreen)), lessThanOrEqualTo(overlayTop(t)));
      });
    }
  }
}
