import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_supply_controller.dart';
import '../screens/trip_details_sheet.dart';
import '../screens/trip_stay_enquiry_sheet.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_a2.dart';
import '../trip_strings_fin_b1.dart';
import 'trip_night_chooser.dart';
import 'trip_own_booking_sheet.dart';
import 'trip_page_bottom_bar.dart';

class TripShortlistBar extends StatelessWidget {
  const TripShortlistBar({super.key, required this.day, this.fromStep});

  final int day;
  final String? fromStep;

  static Future<void> openOwn(BuildContext context, int day) async {
    final stay = TripPlanController.to.plan.value?.dayAt(day)?.stay;
    await TripOwnBookingSheet.show(context, day: day, existingStay: stay?.isOwn == true ? stay : null);
  }

  static Future<void> send(BuildContext context, int day, {String? fromStep}) async {
    final c = TripPlanController.to;
    if (!c.hasDates) {
      await TripDetailsSheet.edit(context, heading: TripStrings.addYourDates, description: TripStrings.addYourDatesOwners);
      if (!c.hasDates || !context.mounted) return;
    }
    await TripStayEnquirySheet.show(context, day: day, fromStep: fromStep);
  }

  static Set<String> askedIds(TripPlanController c, int day) => {
        for (final e in c.enquiriesForNight(day))
          if (e.isOpen) e.listingId,
      };

  static int usedCount(TripPlanController c, int day) => {
        ...askedIds(c, day),
        for (final s in c.plan.value?.dayAt(day)?.stayShortlist ?? const []) s.stayId,
      }.length;

  static bool isFull(TripPlanController c, int day) => usedCount(c, day) >= TripConstants.maxShortlist;

  Widget _locked(BuildContext context, String text) => Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, AppInsets.bottomViewPadding(context) + 12),
        color: Colors.white,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Row(
              children: [
                const Icon(Iconsax.lock_1, size: 16, color: AppColors.textLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(text,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textLight)),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      c.plan.value;
      c.enquiryList.length;
      if (c.isReadOnly) return _locked(context, TripStringsA2.tripLocked);
      if (c.isDayPast(day)) return _locked(context, TripStringsA2.nightPassed);
      final supply = Get.isRegistered<TripSupplyController>() ? Get.find<TripSupplyController>() : null;
      final n = c.shortlistCount(day);
      final emptyList = supply != null &&
          !supply.stayLoading.value &&
          !supply.stayFailed.value &&
          supply.stays.isEmpty &&
          !supply.canWidenRadius;
      final noSupply = c.stayTabOff.value || (!c.supplyAvailableFor(day) && !c.supplyPendingFor(day)) || (emptyList && n == 0);
      final mode = TripNightChooser.modeOf(c, day);
      final ownOnly = noSupply || mode != TripNightMode.nightByNight;
      final asked = askedIds(c, day);
      final used = usedCount(c, day);
      final sendable = c.sendableShortlist(day).length;
      return TripPageBottomBar(
        counterText: ownOnly || used == 0
            ? TripStringsFinB1.nothingShortlisted
            : TripStringsA2.counter(used, withAsked: asked.isNotEmpty),
        secondaryLabel: TripStrings.haveStay,
        secondaryIcon: Iconsax.home_hashtag,
        onSecondary: () => openOwn(context, day),
        primaryLabel: ownOnly || sendable == 0 ? TripStringsA2.sendEnquiry : TripStrings.sendToStays(sendable),
        onPrimary: ownOnly || sendable == 0 ? null : () => send(context, day, fromStep: fromStep),
        hint: !ownOnly && used >= TripConstants.maxShortlist ? TripStrings.shortlistFull : null,
        showPrimary: !noSupply,
        accent: StayColors.accent,
        gradient: StayColors.gradient,
      );
    });
  }
}
