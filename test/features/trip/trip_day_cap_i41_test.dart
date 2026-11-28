import 'dart:io';

import 'package:bakhli/features/stay/enquiries/stay_enquiry_strings.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/trip_constants.dart';
import 'package:bakhli/features/trip/trip_strings_mca_a1.dart';
import 'package:bakhli/features/trip/trip_strings_mca_a3.dart';
import 'package:bakhli/features/trip/trip_strings_v2_create.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/engine_rig.dart';

// I-41 (owner 2026-11-28): a day-wise itinerary has at most 5 days; stay nights keep 14.
void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  test('trip day cap is 5 and every copy says 5', () {
    expect(TripConstants.maxDaysCap, 5);
    expect(TripStringsMcaA1.noDaysLeft, 'No days left · 5 is the most');
    expect(TripStringsMcaA3.noDaysLeft, 'No days left · 5 is the most');
    expect(TripStringsV2Create.maxDaysNote, 'Up to 5 days');
  });

  test('add a day works at 4 days and is blocked at 5', () {
    final four = engineRig(enginePlan([[1, 1, 1, 1]]));
    expect(four.addDayBlock(), TripDayAddBlock.none);
    expect(four.addDay(), TripDayAddBlock.none);
    expect(four.plan.value!.days.length, 5);
    expect(four.addDayBlock(), TripDayAddBlock.maxDays);
    expect(four.canAddDay, isFalse);
  });

  test('saved settings over 5 days are dropped', () {
    expect(TripSettings.fromJson({'maxDays': 5}).maxDays, 5);
    expect(TripSettings.fromJson({'maxDays': 6}).maxDays, isNull);
  });

  test('stay offer nights keep their own 14 cap', () {
    expect(StayEnquiryStrings.maxNights, 14);
    final src = File('lib/features/stay/enquiries/trip_send_offer_sheet.dart').readAsStringSync();
    expect(src, contains('_nights > StayEnquiryStrings.maxNights'));
    expect(src, isNot(contains('maxDaysCap')));
  });
}
