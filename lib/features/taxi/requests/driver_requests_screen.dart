import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'controllers/driver_ready_controller.dart';
import 'controllers/driver_requests_controller.dart';
import 'strings/driver_requests_strings.dart';
import 'widgets/driver_requests_body.dart';

class DriverRequestsScreen extends StatelessWidget {
  const DriverRequestsScreen({
    super.key,
    this.controller,
    this.onOpenOffer,
    this.onBack,
    this.ready,
    this.onOpenReady,
    this.tick = const Duration(seconds: 1),
  });

  final DriverRequestsController? controller;
  final DriverReadyController? ready;
  final VoidCallback? onOpenReady;
  final void Function(String offerId)? onOpenOffer;
  final VoidCallback? onBack;
  final Duration tick;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ListingPalette.coral.page,
      body: Column(
        children: [
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: ModuleHeader(
              title: DriverRequestsStrings.title,
              subtitle: DriverRequestsStrings.subtitle,
              titleStyle: TripCustomizeLook.headerTitle,
              subtitleWidget: Text(DriverRequestsStrings.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TripCustomizeLook.headerSubtitle),
              autoHeight: true,
              compact: true,
              tone: KitTone.taxiDriver,
              gradient: ListingTone.coral.gradient,
              onBack: onBack ?? () => Get.back(),
            ),
          ),
          Expanded(
            child: DriverRequestsBody(
              controller: controller,
              ready: ready,
              onOpenReady: onOpenReady,
              onOpenOffer: onOpenOffer,
              tick: tick,
            ),
          ),
        ],
      ),
    );
  }
}
