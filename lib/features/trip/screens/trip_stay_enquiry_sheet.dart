import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/gradient_button.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_supply_controller.dart';
import '../data/trip_enquiry_repository.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_constants.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_mca_a3.dart';
import '../utils/trip_enquiry_rules.dart';
import '../utils/trip_format.dart';
import '../widgets/trip_back_to_plan_bar.dart';
import '../widgets/trip_payment_line.dart';
import '../widgets/trip_send_result_sheet.dart';
import '../widgets/trip_sheet_frame.dart';
import 'trip_details_sheet.dart';

class TripStayEnquirySheet {
  static Future<TripEnquiryBatch?> show(BuildContext context, {required int day}) async {
    final c = TripPlanController.to;
    if (c.sendableShortlist(day).isEmpty) return null;
    final names = <String, String>{
      for (final s in c.plan.value?.dayAt(day)?.stayShortlist ?? const []) s.stayId: s.name,
    };
    final batch = await TripSheetFrame.show<TripEnquiryBatch>(context, _EnquiryBody(day: day));
    if (batch == null) return null;
    final left = batch.asksLeft;
    if (left != null) TripSupplyController.to.asksLeft.value = left;
    if (batch.items.isEmpty) {
      if (context.mounted) await TripSendResultSheet.show(context, batch: batch, names: names);
      return batch;
    }
    final first = batch.items.first;
    if (batch.skipped.isEmpty && batch.items.length == 1 && first.conversationId != null) {
      TripBackToPlanBar.backToPlan();
      TripNavigation.openChatForEnquiry(first);
      return batch;
    }
    if (batch.skipped.isEmpty) {
      AppToast.success(TripStrings.sentTo(batch.items.length));
    } else if (context.mounted) {
      await TripSendResultSheet.show(context, batch: batch, names: names);
    }
    TripBackToPlanBar.backToPlan();
    return batch;
  }
}

class _EnquiryBody extends StatefulWidget {
  const _EnquiryBody({required this.day});

  final int day;

  @override
  State<_EnquiryBody> createState() => _EnquiryBodyState();
}

class _EnquiryBodyState extends State<_EnquiryBody> {
  final _c = TripPlanController.to;
  bool? _allNights;
  bool _sending = false;
  int? _limitMinutes;

  int get _day => widget.day;

  Future<void> _send(List<String> ids, int nights) async {
    if (_sending || ids.isEmpty) return;
    setState(() {
      _sending = true;
      _limitMinutes = null;
    });
    final enquiries = TripEnquiryController.to;
    final batch = await enquiries.sendEnquiry(day: _day, stayIds: ids, nights: nights);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (batch == null && enquiries.lastErrorType == TripEnquiryErrorTypes.enquiryLimit) {
        _limitMinutes = enquiries.lastRetryAfterMinutes ?? 1;
      }
    });
    if (batch != null) Navigator.pop(context, batch);
  }

  Widget _limitCard(int minutes) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Iconsax.timer_1, size: 16, color: AppColors.warningText),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(TripStrings.askLimitTitle,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.warningText)),
                  const SizedBox(height: 2),
                  Text(TripStrings.askLimitBody(minutes),
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.warningText, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _row(String label, String value, {bool editable = true}) => InkWell(
        onTap: editable ? () => TripDetailsSheet.edit(context) : null,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                ),
                Expanded(
                  child: Text(value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                ),
                if (editable) const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final p = _c.plan.value;
      _c.enquiryList.length;
      final stays = _c.sendableShortlist(_day);
      final ids = stays.map((s) => s.stayId).toList();
      final s = _c.settings;
      final checkIn = _c.dateOf(_day);
      if (p == null || checkIn == null) {
        return const TripSheetFrame(title: TripStrings.enquiryTitle, children: [SizedBox(height: 24)]);
      }
      final run = _c.enquiryNightsRun(_day).length;
      final canAll = run > 1;
      final allNights = canAll && (_allNights ?? true);
      final nights = allNights ? run : 1;
      final checkOut = DateTime(checkIn.year, checkIn.month, checkIn.day + nights);
      final now = DateTime.now().toUtc();
      final start = s.startDate ?? checkIn;
      final short = TripEnquiryRules.enquiryExpiry(start, checkIn, now).veryShortNotice;
      final daysLeft = TripEnquiryRules.daysUntil(start, now);
      final preview = TripEnquiryRules.previewText(
        city: p.isMultiCity ? p.cityNameOf(_day) : _c.cityName,
        checkIn: checkIn,
        checkOut: checkOut,
        allNights: allNights,
        adults: s.adults,
        kids: s.kids,
        rooms: s.rooms,
        needs: s.needs,
        days: [
          for (var d = _day; d < _day + nights; d++)
            TripPreviewDay(day: d, spots: p.dayAt(d)?.spots.map((x) => x.name).toList() ?? const []),
        ],
      );
      final asksLeft = TripSupplyController.to.asksLeft.value;
      final limit = _limitMinutes;
      final reply = short
          ? TripStrings.replyExpectedToday('${TripConstants.floorHours} h')
          : (daysLeft <= 0
              ? TripStrings.replyExpectedToday('24 h')
              : TripStrings.replyExpected('24 h', daysLeft));
      return TripSheetFrame(
        title: TripStrings.enquiryTitle,
        description: stays.map((x) => x.name).join(', '),
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TripPaymentLine(text: TripStrings.noPaymentLine),
            const SizedBox(height: 4),
            Text(reply,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, height: 1.35)),
            if (asksLeft != null) ...[
              const SizedBox(height: 4),
              Text(TripStrings.asksLeft(asksLeft),
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
            ],
          ],
        ),
        children: [
          _row(TripStrings.checkIn, TripFormat.shortDate(checkIn), editable: false),
          _row(TripStrings.checkOut, TripFormat.shortDate(checkOut), editable: false),
          _row(TripStrings.people, s.peopleSummary ?? TripStrings.addPeople),
          if (s.roomsSummary != null) _row(TripStrings.rooms, s.roomsSummary!),
          if (s.needs.isNotEmpty) _row(TripStrings.needs, s.needs.map(TripNeeds.label).join(' · ')),
          if (canAll)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: allNights,
              activeTrackColor: StayColors.accent,
              onChanged: _sending ? null : (v) => setState(() => _allNights = v),
              title: Text(
                  p.isMultiCity ? TripStringsMcaA3.allNightsIn(p.cityNameOf(_day), run) : TripStrings.allNights,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              subtitle: p.isMultiCity
                  ? null
                  : Text(TripStrings.nights(run),
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: StayColors.surface, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(TripStrings.sentToOwners,
                    style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textLight)),
                const SizedBox(height: 4),
                Text(preview,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textDark, height: 1.4)),
              ],
            ),
          ),
          if (short) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Iconsax.warning_2, size: 16, color: AppColors.warningText),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(TripStrings.veryShortNotice,
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warningText)),
                  ),
                ],
              ),
            ),
          ],
          if (limit != null) _limitCard(limit),
          const SizedBox(height: 16),
          GradientButton(
            label: TripStrings.sendToStays(ids.length),
            height: 52,
            isLoading: _sending,
            gradient: StayColors.gradient,
            shadowColor: StayColors.accent,
            onPressed: ids.isEmpty || limit != null ? null : () => _send(ids, nights),
          ),
        ],
      );
    });
  }
}
