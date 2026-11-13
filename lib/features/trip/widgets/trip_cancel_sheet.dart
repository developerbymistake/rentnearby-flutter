import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:flutter/services.dart';
import '../../../models/browse_item.dart';
import '../utils/trip_format.dart';
import '../../../utils/input_formatters.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../utils/trip_enquiry_rules.dart';
import 'trip_sheet_frame.dart';

class _Copy {
  static const String tellGuest = 'Check-in is today or past. Call the guest too.';
  static const String ownerPayLine = 'Payment is between you and the guest. Bakhli does not take payment.';
}

class TripCancelSheet {
  static Future<bool> show(BuildContext context, {required TripEnquiryModel enquiry, required bool ownerSide}) async {
    final done = await TripSheetFrame.show<bool>(context, _CancelBody(enquiry: enquiry, ownerSide: ownerSide));
    return done == true;
  }
}

class _CancelBody extends StatefulWidget {
  final TripEnquiryModel enquiry;
  final bool ownerSide;

  const _CancelBody({required this.enquiry, required this.ownerSide});

  @override
  State<_CancelBody> createState() => _CancelBodyState();
}

class _CancelBodyState extends State<_CancelBody> {
  final _reason = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _pastCheckIn {
    final c = widget.enquiry.checkIn;
    if (c == null) return false;
    final today = TripEnquiryRules.todayIst(DateTime.now().toUtc());
    return !c.isAfter(today);
  }

  Future<void> _cancel() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final ok = await TripEnquiryController.to.cancel(
      widget.enquiry.id,
      reason: widget.ownerSide ? _reason.text : null,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.enquiry;
    final owner = widget.ownerSide;
    final tone = e.isTaxi ? ListingTone.coral : ListingTone.forest;
    final who = owner ? (e.traveller.name ?? '') : e.listingName;
    final total = e.isTaxi ? (e.taxi?.agreedFare ?? e.agreedTotal) : e.agreedTotal;
    final a = e.checkIn;
    final b = e.checkOut;
    final dates = e.isTaxi || a == null || b == null ? e.datesLabel : TripFormat.dayMonthRange(a, b);
    return TripSheetFrame(
      tone: tone,
      art: ListingArt.calendar,
      size: owner ? SheetSize.confirm : SheetSize.hug,
      title: TripStrings.cancelBookingQuestion,
      description: owner ? TripStrings.cancelGuestTold : (e.isTaxi ? TripStrings.cancelDriverTold : TripStrings.cancelHostTold),
      footnote: owner ? _Copy.ownerPayLine : (e.isTaxi ? TripStrings.taxiPayLine : TripStrings.noPaymentLine),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientPillButton(tone: tone, label: TripStrings.cancelBooking, danger: true, loading: _saving, onTap: _saving ? null : _cancel),
          const SizedBox(height: 10),
          WhitePillButton(tone: tone, label: TripStrings.keepBooking, onTap: _saving ? null : () => Navigator.pop(context, false)),
        ],
      ),
      children: [
        ReplySummaryStrip(
          tone: tone,
          title: who.isEmpty ? e.listingName : who,
          subtitle: [if (dates.isNotEmpty) dates, e.countLabel].join(' · '),
          value: total != null && total > 0 ? BrowseItem.inr(total) : '',
        ),
        if (owner)
          PillField(
            tone: tone,
            controller: _reason,
            label: TripStrings.reasonOptional,
            firstLabel: false,
            leadingArt: ListingArt.clipboard,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.cancelReasonMax)],
          ),
        if (_pastCheckIn)
          RepliesBanner(art: ListingArt.roundPushpin, text: owner ? _Copy.tellGuest : TripStrings.tellHostBeforeLeaving, margin: const EdgeInsets.only(top: 14)),
      ],
    );
  }
}
