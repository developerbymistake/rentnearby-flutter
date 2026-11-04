import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/report_controller.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/report_listing_sheet.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../../taxi/taxi_option_sets.dart';
import '../trip_strings.dart';

class TripReport {
  static const String alreadyReported = 'You already reported this stay';

  static ReportController _ctrl() =>
      Get.isRegistered<ReportController>() ? Get.find<ReportController>() : Get.put(ReportController());

  static Future<void> stay(BuildContext context, String stayId, {String? tripEnquiryId}) async {
    if (stayId.isEmpty) return;
    if (_ctrl().reportedListingIds.contains(stayId)) {
      AppToast.info(alreadyReported);
      return;
    }
    await ReportListingSheet.show(
      context,
      listingId: stayId,
      listingType: 'Stay',
      palette: StayColors.palette,
      tripEnquiryId: tripEnquiryId,
    );
  }

  static Future<void> taxi(BuildContext context, String taxiId, {String? tripEnquiryId}) async {
    if (taxiId.isEmpty) return;
    if (_ctrl().reportedListingIds.contains(taxiId)) {
      AppToast.info(TripStrings.alreadyReportedTaxi);
      return;
    }
    await ReportListingSheet.show(
      context,
      listingId: taxiId,
      listingType: 'Taxi',
      palette: TaxiColors.palette,
      tripEnquiryId: tripEnquiryId,
    );
  }
}
