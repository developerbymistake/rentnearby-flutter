import 'package:flutter/material.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../../taxi/leads/trip_lead_format.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../screens/trip_dates_sheet.dart';
import '../trip_strings.dart';
import 'trip_payment_line.dart';
import 'trip_sheet_frame.dart';
import 'trip_taxi_booking_sheet.dart';

class TripDriverReplySheet {
  static Future<void> show(BuildContext context, {required TripEnquiryModel enquiry}) async {
    final book = await TripSheetFrame.show<bool>(context, _ReplyBody(enquiry: enquiry));
    if (book != true || !context.mounted) return;
    final plan = TripPlanController.to;
    if (!plan.hasDates) {
      await TripDatesSheet.ensure(context, heading: TripStrings.addYourDates);
      if (!context.mounted || !plan.hasDates) return;
    }
    await TripTaxiBookingSheet.show(
      context,
      taxi: null,
      day: plan.firstPlanDayOf(enquiry) ?? (enquiry.days.isNotEmpty ? enquiry.days.first : 1),
      enquiry: enquiry,
      initialFare: enquiry.taxi?.driverFare,
    );
  }
}

class _ReplyBody extends StatelessWidget {
  const _ReplyBody({required this.enquiry});

  final TripEnquiryModel enquiry;

  String? get _phone {
    final p = enquiry.owner.phone;
    return p != null && ContactLauncher.tenDigits(p).isNotEmpty ? p : null;
  }

  @override
  Widget build(BuildContext context) {
    final e = enquiry;
    final t = e.taxi;
    final name = TripLeadFormat.driver(e);
    final phone = _phone;
    final whatsApp = e.owner.whatsApp ?? phone;
    final rate = t?.listedRate;
    final total = TripLeadFormat.listedTotal(e);
    final note = t?.driverNote?.trim() ?? '';
    final day = TripPlanController.to.firstPlanDayOf(e) ?? (e.days.isNotEmpty ? e.days.first : 1);
    return TripSheetFrame(
      title: TripStrings.driverReplied(name),
      description: TripLeadFormat.dates(e),
      footer: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(TripStrings.driverReplyFooter,
              style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11, color: FitnessAppTheme.deactivatedText, height: 1.35)),
          SizedBox(height: 4),
          TripPaymentLine(text: TripStrings.taxiPayLine),
        ],
      ),
      children: [
        TemplateStagger(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        _fareBox(t?.driverFare, rate, total, e),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(TripStrings.noteFromDriver,
              style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11.5, fontWeight: FontWeight.w600, color: FitnessAppTheme.deactivatedText)),
          const SizedBox(height: 4),
          Text(note, style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, color: FitnessAppTheme.darkerText, height: 1.4)),
        ],
        const SizedBox(height: 16),
        if (phone != null)
          LayoutBuilder(builder: (context, c) {
            final callBtn = TripActionChip(height: 48, fontSize: 13, icon: Icons.call_rounded, label: TripStrings.call, onTap: () => ContactLauncher.call(phone));
            final waBtn = TripActionChip(
                height: 48,
                fontSize: 13,
                iconAsset: TravelIcon.chat,
                color: RepliesTone.good,
                label: TripStrings.whatsApp,
                onTap: () => ContactLauncher.whatsApp(whatsApp!, message: _message(day, name)));
            if (c.maxWidth >= 340) {
              return Row(children: [Expanded(child: callBtn), const SizedBox(width: 10), Expanded(child: waBtn)]);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [callBtn, const SizedBox(height: 8), waBtn]);
          }),
        if (phone != null) const SizedBox(height: 12),
        TripButton(
          height: 52,
          label: TripStrings.iBooked,
          onPressed: () => Navigator.pop(context, true),
        ),
          ],
        ),
      ],
    );
  }

  String _message(int day, String name) {
    try {
      return TripPlanController.to.whatsAppMessage(day, name);
    } catch (_) {
      return '';
    }
  }

  Widget _fareBox(int? fare, int? rate, int? total, TripEnquiryModel e) {
    Widget cell(String label, Widget value, CrossAxisAlignment align) => Column(
          crossAxisAlignment: align,
          children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11, fontWeight: FontWeight.w600, color: DesignColors.whiteHigh)),
            const SizedBox(height: 2),
            value,
          ],
        );
    final fareText = fare == null ? '' : BrowseItem.inr(fare);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: KitTone.trip.gradient,
        borderRadius: CardRadius.tile,
        boxShadow: ShadowTokens.glow(KitTone.trip.glow),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final fareCell = cell(
          TripStrings.driversFare,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(fareText,
                maxLines: 1,
                style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 26, fontWeight: FontWeight.w800, color: FitnessAppTheme.white)),
          ),
          CrossAxisAlignment.start,
        );
        final listedCell = rate == null || total == null
            ? null
            : cell(
                TripStrings.listedRate,
                Text(TripStrings.listedTimes(BrowseItem.inr(rate), TripLeadFormat.dayCount(e), BrowseItem.inr(total)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w600, color: FitnessAppTheme.white)),
                CrossAxisAlignment.start,
              );
        if (listedCell == null) return fareCell;
        if (c.maxWidth >= 300) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: fareCell),
            const SizedBox(width: 12),
            Expanded(child: listedCell),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [fareCell, const SizedBox(height: 10), listedCell]);
      }),
    );
  }
}
