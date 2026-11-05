import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_colors.dart';
import '../../../models/browse_item.dart';
import '../../../utils/input_formatters.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../utils/trip_enquiry_rules.dart';
import 'trip_payment_line.dart';
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
    return TripSheetFrame(
      title: TripStrings.cancelBookingQuestion,
      description: owner
          ? TripStrings.cancelGuestTold
          : (e.isTaxi ? TripStrings.cancelDriverTold : TripStrings.cancelHostTold),
      footer: TripPaymentLine(text: owner ? _Copy.ownerPayLine : TripStrings.noPaymentLine),
      children: [
        _summary(e, owner),
        if (owner) ...[
          const SizedBox(height: 14),
          const Text(TripStrings.reasonOptional,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
          const SizedBox(height: 6),
          TextField(
            controller: _reason,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.cancelReasonMax)],
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.scaffoldBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              enabledBorder:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
              focusedBorder:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.stay, width: 1.5)),
            ),
          ),
        ],
        if (_pastCheckIn) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
            child: Text(owner ? _Copy.tellGuest : TripStrings.tellHostBeforeLeaving,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.warningText)),
          ),
        ],
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, c) {
          final keep = _button(TripStrings.keepBooking, outlined: true, onTap: _saving ? null : () => Navigator.pop(context, false));
          final cancel = _button(TripStrings.cancelBooking, onTap: _saving ? null : _cancel, loading: _saving);
          if (c.maxWidth >= 340) {
            return Row(children: [Expanded(child: keep), const SizedBox(width: 12), Expanded(child: cancel)]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [cancel, const SizedBox(height: 10), keep]);
        }),
      ],
    );
  }

  Widget _summary(TripEnquiryModel e, bool owner) {
    final who = owner ? (e.traveller.name ?? '') : e.listingName;
    final total = e.agreedTotal;
    final line = [
      if (e.datesLabel.isNotEmpty) e.datesLabel,
      e.countLabel,
      if (total != null) BrowseItem.inr(total),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.scaffoldBg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (who.isNotEmpty)
            Text(who,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          Text(line,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textMedium)),
        ],
      ),
    );
  }

  Widget _button(String label, {required VoidCallback? onTap, bool outlined = false, bool loading = false}) {
    final child = loading
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: outlined ? AppColors.textMedium : Colors.white));
    return SizedBox(
      height: 48,
      child: outlined
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 48),
                side: const BorderSide(color: AppColors.divider),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: child,
            )
          : ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(64, 48),
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.error.withValues(alpha: 0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: child,
            ),
    );
  }
}
