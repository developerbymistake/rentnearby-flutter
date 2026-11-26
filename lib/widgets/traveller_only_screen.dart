import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../design/design.dart';
import '../navigation/traveller_gate.dart';

class TravellerOnlyScreen extends StatelessWidget {
  const TravellerOnlyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.surface,
      body: Center(
        child: StateCard(
          asset: TravelIcon.route,
          title: TravellerGateStrings.title,
          message: TravellerGateStrings.message,
          actionLabel: TravellerGateStrings.goBack,
          onAction: () => Get.back(),
          layout: StateLayout.plain,
        ),
      ),
    );
  }
}
