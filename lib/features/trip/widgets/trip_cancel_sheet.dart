import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
import 'package:flutter/services.dart';
import '../../../models/browse_item.dart';
import '../../../utils/input_formatters.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../utils/trip_enquiry_rules.dart';
import 'trip_payment_line.dart';
import 'trip_sheet_frame.dart';
import 'trip_withdraw_sheet.dart';

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
    return TripSheetFrame(
      title: TripStrings.cancelBookingQuestion,
      description: owner
          ? TripStrings.cancelGuestTold
          : (e.isTaxi ? TripStrings.cancelDriverTold : TripStrings.cancelHostTold),
      footer: TripPaymentLine(text: owner ? _Copy.ownerPayLine : TripStrings.noPaymentLine),
      children: [
        TemplateStagger(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        _summary(e, owner),
        if (owner) ...[
          const SizedBox(height: 14),
          const Text(TripStrings.reasonOptional,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, fontWeight: FontWeight.w600, color: FitnessAppTheme.lightText)),
          const SizedBox(height: 6),
          TextField(
            controller: _reason,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.cancelReasonMax)],
            style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 14, color: FitnessAppTheme.darkerText),
            decoration: InputDecoration(
              filled: true,
              fillColor: FitnessAppTheme.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              enabledBorder:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.transparent)),
              focusedBorder:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: RepliesTone.accent, width: 1.5)),
            ),
          ),
        ],
        if (_pastCheckIn) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: RepliesTone.warnSurface, borderRadius: BorderRadius.circular(8)),
            child: Text(owner ? _Copy.tellGuest : TripStrings.tellHostBeforeLeaving,
                style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, color: RepliesTone.warn)),
          ),
        ],
        const SizedBox(height: 18),
        TripTwoButtons(
          secondaryLabel: TripStrings.keepBooking,
          primaryLabel: TripStrings.cancelBooking,
          busy: _saving,
          onSecondary: () => Navigator.pop(context, false),
          onPrimary: _cancel,
        ),
          ],
        ),
      ],
    );
  }

  Widget _summary(TripEnquiryModel e, bool owner) {
    final who = owner ? (e.traveller.name ?? '') : e.listingName;
    final total = e.agreedTotal;
    final line = [
      if (e.datesLabel.isNotEmpty) e.datesLabel,
      e.countLabel,
      if (total != null && total > 0) BrowseItem.inr(total),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: FitnessAppTheme.background, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (who.isNotEmpty)
            Text(who,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 14, fontWeight: FontWeight.w700, color: FitnessAppTheme.darkerText)),
          Text(line,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, color: FitnessAppTheme.lightText)),
        ],
      ),
    );
  }
}
