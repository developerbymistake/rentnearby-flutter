import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_plan_result_model.dart';
import '../screens/trip_details_sheet.dart';
import '../screens/trip_edit_spot_sheet.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_a4.dart';
import '../trip_strings_fin_b1.dart';
import '../trip_strings_mca_a3.dart';
import '../utils/trip_format.dart';
import 'trip_cancel_sheet.dart';
import 'trip_day_actions.dart';
import 'trip_leg_menu_sheet.dart';
import 'trip_status.dart';
import 'trip_withdraw_sheet.dart';
import 'trip_wrong_city_strip.dart';

class TripDayTile extends StatelessWidget {
  final int day;

  const TripDayTile(this.day, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    final color = TripColors.dayColor(day);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: AppShadows.premium(color, alpha: 0.08, blur: 12, offset: const Offset(0, 4)),
      ),
      child: Obx(() {
        final plan = c.plan.value;
        c.result.value;
        c.trip.value;
        c.enquiryList.length;
        final d = plan?.dayAt(day);
        if (plan == null || d == null) return const SizedBox.shrink();
        final readOnly = c.isReadOnly || c.needsUpdate.value || c.isDayPast(day);
        final legIndex = plan.legIndexOf(day);
        final leg = plan.legOf(day);
        final travel = plan.isTravelDay(day);
        final prev = travel ? plan.legAt(legIndex - 1)?.cityName : null;
        final road = travel ? c.roadMinutesOf(legIndex) : null;
        final total = c.dayLoadMinutes(day);
        final over = c.isOverLimit(day);
        final closed = c
            .warningsFor(day)
            .where((w) => w.code == TripWarningCodes.closedDay)
            .map((w) => _closedText(plan, w))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(color, total, over, c.isEstimate(day), d.spots.isEmpty, plan.settings.dateOf(day), travel),
            if (prev != null) _travelLine(prev, leg.cityName, road),
            for (final text in closed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Iconsax.warning_2, size: 14, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.warningText),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            if (d.spots.isEmpty && leg.notReady && plan.isMultiCity) ...[
              _notReady(),
              if (!readOnly) ...[const SizedBox(height: 6), _addLegPlaces(legIndex)],
            ] else if (d.spots.isEmpty && plan.isMultiCity && plan.legSpotCount(legIndex) == 0 && !readOnly)
              _addLegPlaces(legIndex)
            else if (d.spots.isEmpty && c.spotCount == 0 && !readOnly)
              _addPlaces(c)
            else if (d.spots.isEmpty)
              Text(
                travel ? TripStringsFinB1.driveDay : TripStrings.freeDay,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: d.spots.length,
                onReorder: (oldIndex, newIndex) {
                  if (!readOnly) c.reorder(day, oldIndex, newIndex);
                },
                itemBuilder: (context, i) {
                  final s = d.spots[i];
                  final isLast = i == d.spots.length - 1;
                  return _StopItem(
                    key: ValueKey(s.id),
                    index: i,
                    spot: s,
                    color: color,
                    driveMinutes: isLast ? null : c.legFrom(day, s.id)?.minutes,
                    showDrive: !isLast,
                    readOnly: readOnly,
                    onTap: readOnly ? null : () => TripEditSpotSheet.show(context, s.id),
                  );
                },
              ),
            const SizedBox(height: 10),
            TripDayActions(day),
            _wrongCity(context, c, readOnly),
            if (!readOnly) ...[
              _taxiRedNote(c),
              _redNote(c, d),
            ],
          ],
        );
      }),
    );
  }

  Widget _wrongCity(BuildContext context, TripPlanController c, bool readOnly) {
    final e = c.wrongCityForDay(day);
    final info = e == null ? null : c.wrongCityOf(e);
    if (e == null || info == null) return const SizedBox.shrink();
    VoidCallback? cancel;
    if (!readOnly) {
      if (e.isWithdrawable) {
        cancel = () => TripWithdrawSheet.show(context, enquiry: e);
      } else if (e.isBooked) {
        cancel = () => TripCancelSheet.show(context, enquiry: e, ownerSide: false);
      }
    }
    final plan = c.plan.value;
    final changeDays = readOnly || plan == null
        ? null
        : () => plan.isMultiCity
            ? TripLegMenuSheet.changeDays(context, c.wrongCityHomeLeg(info) ?? plan.legIndexOf(day))
            : TripDetailsSheet.edit(context);
    return TripWrongCityStrip(enquiry: e, info: info, onCancel: cancel, onChangeDays: changeDays);
  }

  Widget _travelLine(String from, String to, int? road) {
    final line = TripStringsMcaA3.fromTo(from, to);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        road == null || road <= 0 ? line : '$line · ${TripStringsFinB1.onTheRoad(road)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
      ),
    );
  }

  Widget _notReady() {
    return Row(
      children: [
        const Icon(Iconsax.info_circle, size: 15, color: AppColors.textLight),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            TripStringsMcaA3.noPlacesYet,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight),
          ),
        ),
      ],
    );
  }

  Widget _addLegPlaces(int legIndex) => _addButton(() => TripLegMenuSheet.addPlaces(legIndex));

  Widget _addPlaces(TripPlanController c) => _addButton(() {
        final picked = c.picked;
        final plan = c.plan.value;
        if (picked == null || plan == null) return;
        TripNavigation.openSpots(picked, tripId: c.trip.value?.id, existingIds: plan.spotIds);
      });

  Widget _addButton(VoidCallback onPressed) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Iconsax.add_circle, size: 18, color: TripColors.accentDark),
        label: const Text(
          TripStringsA4.addPlaces,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: TripColors.accentDark),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          side: BorderSide(color: TripColors.accent.withValues(alpha: 0.6)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _redNote(TripPlanController c, TripDay d) {
    final e = c.primaryEnquiry(day);
    if (e == null || !e.isRed || !c.showStayOption || c.isCompleted || (d.stay?.isSkipped ?? false)) {
      return const SizedBox.shrink();
    }
    if (e.display == TripDisplayStatus.holdExpired) {
      final replied = c
          .enquiriesForNight(day)
          .where((x) => x.id != e.id && x.display == TripDisplayStatus.offered)
          .map((x) => x.listingName)
          .where((n) => n.isNotEmpty)
          .toList();
      return _note(
        text: '${e.listingName} · ${TripStrings.holdExpired}',
        detail: replied.isEmpty
            ? TripStrings.holdExpiredNote
            : TripStrings.otherStaysReplied(replied.length, replied.join(', ')),
        action: TripStrings.askOtherStays,
        onAction: () => replied.isEmpty ? TripNavigation.openStay(day) : TripNavigation.openReplies(day),
      );
    }
    final asked = {for (final x in c.enquiriesForNight(day)) x.listingId};
    final others = d.stayShortlist.where((s) => !asked.contains(s.stayId)).length;
    final label = e.display == TripDisplayStatus.cancelled && e.cancelledBy == 'owner'
        ? TripStrings.hostCancelled
        : TripStatusVisuals.label(e.display);
    final again = c.canAskAgain(TripEnquiryKinds.stay, day);
    return _note(
      text: '${e.listingName} · $label',
      action: again ? TripStrings.askAgain : (others > 0 ? TripStrings.askOther(others) : TripStrings.findAnother),
      onAction: again ? () => _askAgain(c, TripEnquiryKinds.stay) : () => TripNavigation.openStay(day),
      busy: again && c.askBusy.value,
    );
  }

  Widget _taxiRedNote(TripPlanController c) {
    final e = c.primaryTaxiEnquiry(day);
    if (e == null || !e.isRed || !c.showTaxiOption || c.isCompleted) return const SizedBox.shrink();
    final other = c
        .taxiEnquiriesForDay(day)
        .where((x) => x.id != e.id && x.listingId != e.listingId && x.display.isOpen)
        .map((x) => x.listingName)
        .where((n) => n.isNotEmpty)
        .firstOrNull;
    final label = e.display == TripDisplayStatus.cancelled && e.cancelledBy == 'owner'
        ? TripStrings.hostCancelled
        : TripStatusVisuals.label(e.display, taxi: true);
    final again = other == null && c.canAskAgain(TripEnquiryKinds.taxi, day);
    return _note(
      text: '${e.listingName} · $label',
      detail: other == null ? null : TripStrings.driverAlsoGot(other),
      action: again ? TripStrings.askAgain : (other == null ? TripStrings.findAnotherTaxi : TripStrings.askAnother),
      onAction: again
          ? () => _askAgain(c, TripEnquiryKinds.taxi)
          : () => other == null ? TripNavigation.openTaxi(day) : TripNavigation.openTaxiReplies(day),
      busy: again && c.askBusy.value,
    );
  }

  Future<void> _askAgain(TripPlanController c, String kind) async {
    final batch = await c.askAgain(kind: kind, day: day);
    if (batch == null) return;
    if (kind == TripEnquiryKinds.taxi) {
      TripNavigation.openTaxiReplies(day);
    } else {
      TripNavigation.openReplies(day);
    }
  }

  Widget _note({
    required String text,
    String? detail,
    required String action,
    required VoidCallback onAction,
    bool busy = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(color: TripStatusColors.failedSurface, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Iconsax.warning_2, size: 14, color: TripStatusColors.failed),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.errorText),
                  ),
                  if (detail != null)
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.errorText),
                    ),
                ],
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: TextButton(
              onPressed: busy ? null : onAction,
              style: TextButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 10)),
              child: Text(
                action,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: TripStatusColors.failed),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _closedText(TripPlan plan, TripWarning w) {
    final id = w.spotId;
    final name = id == null ? null : plan.spotById(id)?.name;
    return name == null ? w.message : '$name is closed on that day';
  }

  Widget _header(Color color, int total, bool over, bool estimate, bool free, DateTime? date, bool travel) {
    return Row(
      children: [
        Flexible(
          fit: travel ? FlexFit.loose : FlexFit.tight,
          child: Text(
            date == null ? 'Day $day' : 'Day $day · ${TripFormat.shortDate(date)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: color),
          ),
        ),
        const SizedBox(width: 8),
        if (travel) ...[
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(999)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.routing, size: 12, color: TripColors.accentDark),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      TripStringsMcaA3.travelDay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: TripColors.accentDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
        ],
        if (estimate) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(999)),
            child: const Text(
              TripStrings.estimate,
              style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.warningText),
            ),
          ),
          const SizedBox(width: 6),
        ],
        if (!free)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: over ? AppColors.errorSurface : AppColors.neutralChip,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              TripFormat.duration(total),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: over ? AppColors.error : AppColors.textMedium,
              ),
            ),
          ),
      ],
    );
  }
}

class _StopItem extends StatelessWidget {
  final int index;
  final TripSpotRef spot;
  final Color color;
  final int? driveMinutes;
  final bool showDrive;
  final bool readOnly;
  final VoidCallback? onTap;

  const _StopItem({
    super.key,
    required this.index,
    required this.spot,
    required this.color,
    required this.driveMinutes,
    required this.showDrive,
    required this.readOnly,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final drive = driveMinutes;
    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      spot.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    TripFormat.visit(spot.visitMinutes),
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
                  ),
                  if (!readOnly)
                    ReorderableDelayedDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.drag_indicator_rounded, size: 20, color: AppColors.textHint),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (showDrive)
            Padding(
              padding: const EdgeInsets.only(left: 11),
              child: Container(
                padding: const EdgeInsets.only(left: 19, top: 2, bottom: 2),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: color.withValues(alpha: 0.35), width: 2)),
                ),
                child: drive == null
                    ? const SizedBox(height: 14)
                    : Row(
                        children: [
                          const Icon(Iconsax.car, size: 12, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(
                            TripFormat.duration(drive),
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
