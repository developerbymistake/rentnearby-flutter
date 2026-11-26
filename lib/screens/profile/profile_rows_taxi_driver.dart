import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/app_routes.dart';
import '../../design/design.dart';
import '../../features/owner_core/home/owner_home_models.dart';
import '../../features/taxi_driver/home/taxi_driver_home_controller.dart';
import '../../features/taxi_driver/strings/taxi_hub_strings.dart';

class TaxiDriverProfileRows extends StatelessWidget {
  const TaxiDriverProfileRows({super.key});

  static String ratingSub(double? avg, int? count) =>
      avg == null || (count ?? 0) <= 0 ? TaxiHubStrings.noRatingsYet : TaxiHubStrings.ratingSub(avg, count ?? 0);

  static Widget _ratingRow(OwnerNumbers? n) => IconRow3D(
        art: ListingArt.star,
        title: TaxiHubStrings.myRating,
        subtitle: ratingSub(n?.ratingAvg, n?.ratingCount),
        onTap: () => Get.toNamed(AppRoutes.taxiRating),
        trailing: Icon(Icons.chevron_right_rounded, size: DS.s(22), color: DesignColors.textDisabled),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(16)),
      child: WhiteCard3D(
        child: Column(
          children: [
            Builder(builder: (_) {
              final c = TaxiDriverHomeController.maybe;
              if (c == null) return _ratingRow(null);
              return Obx(() => _ratingRow(c.load.value.valueOrNull?.numbers));
            }),
          ],
        ),
      ),
    );
  }
}
