import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../utils/contact_launcher.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_strings_mca_a3.dart';
import 'trip_own_travel_sheet.dart';

enum _TravelAction { edit, remove }

class TripTravelTile extends StatelessWidget {
  const TripTravelTile({super.key, required this.legIndex});

  final int legIndex;

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final p = c.plan.value;
      c.trip.value;
      final leg = p?.legAt(legIndex);
      if (p == null || leg == null || legIndex < 2) return const SizedBox.shrink();
      final day = p.legStart(legIndex);
      final readOnly = c.isReadOnly || c.needsUpdate.value || !c.canEditDay(day);
      final a = leg.arrival;
      return a == null ? _notPlanned(context, leg, day, readOnly) : _own(context, a, readOnly);
    });
  }

  Widget _frame({required Color fill, required Color edge, required Color bar, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: edge),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: bar),
              Expanded(
                child: Padding(padding: const EdgeInsets.fromLTRB(10, 10, 4, 10), child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon(IconData icon, Color color) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 16, color: color),
      );

  Widget _texts(String title, String? subtitle, Color subColor) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          if (subtitle != null && subtitle.isNotEmpty)
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: subColor)),
        ],
      );

  Widget _notPlanned(BuildContext context, TripCityLeg leg, int day, bool readOnly) {
    final date = TripPlanController.to.dateOf(day);
    return _frame(
      fill: Colors.white,
      edge: AppColors.divider,
      bar: AppColors.textHint,
      child: Builder(builder: (context) {
        final info = Row(
          children: [
            _icon(Iconsax.car, AppColors.textLight),
            const SizedBox(width: 10),
            Expanded(
              child: _texts(TripStringsMcaA3.travelToLine(leg.cityName, day, date), TripStringsMcaA3.notPlannedYet,
                  AppColors.textLight),
            ),
          ],
        );
        if (readOnly) return Padding(padding: const EdgeInsets.only(right: 6), child: info);
        final action = TextButton(
          onPressed: () => TripOwnTravelSheet.show(context, legIndex),
          style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 10)),
          child: const Text(TripStringsMcaA3.arrangeMyself,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TripColors.accentDark)),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.only(right: 6), child: info),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        );
      }),
    );
  }

  Widget _own(BuildContext context, TripTravel a, bool readOnly) {
    final how = a.how == null ? null : TripOwnTravelSheet.howLabel(a.how!);
    final raw = a.ownPhone;
    final phone = raw != null && ContactLauncher.tenDigits(raw).isNotEmpty ? raw : null;
    return _frame(
      fill: TripStatusColors.bookedSurface,
      edge: TripStatusColors.booked.withValues(alpha: 0.5),
      bar: TripStatusColors.booked,
      child: Row(
        children: [
          _icon(TripOwnTravelSheet.howIcon(a.how), TripStatusColors.booked),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: readOnly ? null : () => TripOwnTravelSheet.show(context, legIndex),
              child: _texts(TripStringsMcaA3.ownTravelLine(how, a.leavesAt), a.ownName ?? a.note, TripStatusColors.booked),
            ),
          ),
          if (phone != null)
            TextButton.icon(
              onPressed: () => ContactLauncher.call(phone),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
              icon: const Icon(Iconsax.call, size: 16, color: TripStatusColors.booked),
              label: const Text(TripStringsMcaA3.call,
                  maxLines: 1,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: TripStatusColors.booked)),
            ),
          if (!readOnly)
            PopupMenuButton<_TravelAction>(
              icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMedium),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 140),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (v) {
                if (v == _TravelAction.edit) {
                  TripOwnTravelSheet.show(context, legIndex);
                } else {
                  TripPlanController.to.clearTravel(legIndex);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _TravelAction.edit,
                  child: Text(TripStringsMcaA3.edit, style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textDark)),
                ),
                PopupMenuItem(
                  value: _TravelAction.remove,
                  child: Text(TripStringsMcaA3.removeTravel,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.error)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
