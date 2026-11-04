import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/gradient_button.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_colors.dart';
import '../trip_constants.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
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
    final first = batch.items.isEmpty ? null : batch.items.first;
    if (batch.skipped.isEmpty && batch.items.length == 1 && first?.conversationId != null) {
      TripBackToPlanBar.backToPlan();
      TripNavigation.openChatForEnquiry(first!);
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

  int get _day => widget.day;

  bool _canAllNights(List<String> ids) {
    final last = _c.dayCount - 1;
    if (_day >= last) return false;
    for (var d = _day + 1; d <= last; d++) {
      final have = {for (final s in _c.plan.value?.dayAt(d)?.stayShortlist ?? const []) s.stayId};
      if (!ids.every(have.contains)) return false;
    }
    return true;
  }

  Future<void> _send(List<String> ids, bool allNights) async {
    if (_sending || ids.isEmpty) return;
    setState(() => _sending = true);
    final batch = await TripEnquiryController.to.sendEnquiry(day: _day, stayIds: ids, allNights: allNights);
    if (!mounted) return;
    setState(() => _sending = false);
    if (batch != null) Navigator.pop(context, batch);
  }

  Widget _row(String label, String value) => InkWell(
        onTap: () => TripDetailsSheet.edit(context),
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
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
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
      final canAll = _canAllNights(ids);
      final allNights = canAll && (_allNights ?? true);
      final nights = TripEnquiryRules.nightsFor(_c.dayCount, _day, allNights);
      final checkOut = DateTime(checkIn.year, checkIn.month, checkIn.day + nights);
      final now = DateTime.now().toUtc();
      final start = s.startDate ?? checkIn;
      final short = TripEnquiryRules.enquiryExpiry(start, checkIn, now).veryShortNotice;
      final daysLeft = TripEnquiryRules.daysUntil(start, now);
      final preview = TripEnquiryRules.previewText(
        city: _c.cityName,
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
          ],
        ),
        children: [
          _row(TripStrings.checkIn, TripFormat.shortDate(checkIn)),
          _row(TripStrings.checkOut, TripFormat.shortDate(checkOut)),
          _row(TripStrings.people, s.peopleSummary ?? TripStrings.addPeople),
          if (s.roomsSummary != null) _row(TripStrings.rooms, s.roomsSummary!),
          if (s.needs.isNotEmpty) _row(TripStrings.needs, s.needs.map(TripNeeds.label).join(' · ')),
          if (canAll)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: allNights,
              activeTrackColor: TripColors.accent,
              onChanged: _sending ? null : (v) => setState(() => _allNights = v),
              title: Text(TripStrings.allNights,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              subtitle: Text(TripStrings.nights(TripEnquiryRules.nightsFor(_c.dayCount, _day, true)),
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(12)),
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
          const SizedBox(height: 16),
          GradientButton(
            label: TripStrings.sendToStays(ids.length),
            height: 52,
            isLoading: _sending,
            gradient: TripColors.gradient,
            shadowColor: TripColors.accent,
            onPressed: ids.isEmpty ? null : () => _send(ids, allNights),
          ),
        ],
      );
    });
  }
}
