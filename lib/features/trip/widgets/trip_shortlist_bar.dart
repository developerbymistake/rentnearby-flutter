import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_shadows.dart';
import '../../../widgets/gradient_button.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_supply_controller.dart';
import '../screens/trip_details_sheet.dart';
import '../screens/trip_stay_enquiry_sheet.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import 'trip_own_booking_sheet.dart';

class TripShortlistBar extends StatelessWidget {
  const TripShortlistBar({super.key, required this.day});

  final int day;

  static Future<void> openOwn(BuildContext context, int day) {
    final stay = TripPlanController.to.plan.value?.dayAt(day)?.stay;
    return TripOwnBookingSheet.show(context, day: day, existing: stay?.isOwn == true ? stay : null);
  }

  static Future<void> send(BuildContext context, int day) async {
    final c = TripPlanController.to;
    if (!c.hasDates) {
      await TripDetailsSheet.edit(context, heading: TripStrings.addYourDates, description: TripStrings.addYourDatesOwners);
      if (!c.hasDates || !context.mounted) return;
    }
    await TripStayEnquirySheet.show(context, day: day);
  }

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      c.plan.value;
      c.enquiryList.length;
      final supply = Get.isRegistered<TripSupplyController>() ? Get.find<TripSupplyController>() : null;
      final noSupply = supply != null && !supply.stayLoading.value && supply.stays.isEmpty;
      final n = c.shortlistCount(day);
      final sendable = c.sendableShortlist(day).length;
      final link = TextButton(
        onPressed: () => openOwn(context, day),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.centerLeft,
        ),
        child: const Text(TripStrings.haveStay,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: TripColors.accentDark)),
      );
      final onlyLink = n == 0 && (noSupply || !c.supplyAvailable);
      return Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, AppInsets.bottomViewPadding(context) + 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: AppShadows.premium(TripColors.accent, alpha: 0.12, blur: 16, offset: const Offset(0, -4)),
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: onlyLink
                ? Align(alignment: Alignment.centerLeft, child: link)
                : LayoutBuilder(builder: (context, box) {
                    final info = Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(TripStrings.ofThree(n),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark)),
                        link,
                      ],
                    );
                    final button = GradientButton(
                      label: TripStrings.sendToStays(sendable),
                      height: 48,
                      gradient: TripColors.gradient,
                      shadowColor: TripColors.accent,
                      onPressed: sendable == 0 ? null : () => send(context, day),
                    );
                    if (box.maxWidth < 480) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [info, const SizedBox(height: 6), button],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(flex: 5, child: info),
                        const SizedBox(width: 10),
                        Expanded(flex: 6, child: button),
                      ],
                    );
                  }),
          ),
        ),
      );
    });
  }
}
