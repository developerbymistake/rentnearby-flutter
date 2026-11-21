import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/app_routes.dart';
import '../../controllers/auth_controller.dart';
import '../../design/design.dart';
import '../../features/taxi_driver/home/taxi_driver_home_controller.dart';
import '../../features/taxi_driver/strings/taxi_hub_strings.dart';

class TaxiDriverProfileRows extends StatelessWidget {
  const TaxiDriverProfileRows({super.key});

  static void _planTrip() {
    if (Get.isRegistered<AuthController>()) Get.find<AuthController>().openPlace(AppPlace.trips);
  }

  static String ratingSub(double? avg, int? count) =>
      avg == null || (count ?? 0) <= 0 ? TaxiHubStrings.noRatingsYet : TaxiHubStrings.ratingSub(avg, count ?? 0);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(16)),
      child: WhiteCard3D(
        child: Column(
          children: [
            IconRow3D(
              art: ListingArt.worldMap,
              title: TaxiHubStrings.planATrip,
              subtitle: TaxiHubStrings.travelAsGuest,
              onTap: _planTrip,
              trailing: Icon(Icons.chevron_right_rounded, size: DS.s(22), color: DesignColors.textDisabled),
            ),
            Obx(() {
              final n = TaxiDriverHomeController.maybe?.load.value.valueOrNull?.numbers;
              return IconRow3D(
                art: ListingArt.star,
                title: TaxiHubStrings.myRating,
                subtitle: ratingSub(n?.ratingAvg, n?.ratingCount),
                divider: true,
                onTap: () => Get.toNamed(AppRoutes.taxiRating),
                trailing: Icon(Icons.chevron_right_rounded, size: DS.s(22), color: DesignColors.textDisabled),
              );
            }),
          ],
        ),
      ),
    );
  }
}
