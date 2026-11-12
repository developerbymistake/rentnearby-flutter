import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/input_formatters.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/trip_constants.dart';
import '../../trip/trip_strings.dart';
import '../../trip/utils/trip_format.dart';
import '../../trip/widgets/trip_payment_line.dart';
import '../../trip/widgets/trip_sheet_frame.dart';
import '../taxi_option_sets.dart';
import 'trip_lead_format.dart';
import 'trip_leads_controller.dart';

class TripFareSheet {
  static Future<bool> show(BuildContext context, {required TripEnquiryModel lead}) async {
    final done = await TripSheetFrame.show<bool>(context, _FareBody(lead: lead));
    return done == true;
  }
}

class _FareBody extends StatefulWidget {
  const _FareBody({required this.lead});

  final TripEnquiryModel lead;

  @override
  State<_FareBody> createState() => _FareBodyState();
}

class _FareBodyState extends State<_FareBody> with SingleTickerProviderStateMixin {
  static const int _blocks = 6;
  late final AnimationController _anim = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);

  Widget _enter(int i, Widget child) => TemplateEntrance(
        animation: templateInterval(_anim, i, _blocks),
        animationController: _anim,
        child: child,
      );

  late final TextEditingController _fare;
  late final TextEditingController _note;
  bool _sending = false;

  TripEnquiryModel get _lead => widget.lead;

  @override
  void initState() {
    super.initState();
    _anim.forward();
    final t = _lead.taxi;
    final start = t?.driverFare ?? TripLeadFormat.listedTotal(_lead);
    _fare = TextEditingController(text: start == null || start <= 0 ? '' : '$start');
    _note = TextEditingController(text: t?.driverNote ?? '');
  }

  @override
  void dispose() {
    _anim.dispose();
    _fare.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    FocusScope.of(context).unfocus();
    final fare = int.tryParse(_fare.text.trim());
    if (fare == null || fare < TaxiOptionSets.minFare || fare > TaxiOptionSets.maxFare) {
      AppToast.warning(TripStrings.errFareRange);
      return;
    }
    setState(() => _sending = true);
    final ok = await TripLeadsController.ensure().fare(_lead.id, fare, _note.text);
    if (!mounted) return;
    if (ok) {
      AppToast.success(TripStrings.replySent);
      Navigator.pop(context, true);
    } else {
      setState(() => _sending = false);
    }
  }

  static const _inputStyle = TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 14, color: DesignColors.textStrong);

  InputDecoration _decoration({String? prefix}) => InputDecoration(
        prefixText: prefix,
        filled: true,
        fillColor: DesignColors.scaffold,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: FitnessAppTheme.spacer)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DesignColors.primary, width: 1.5)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TripKit.text(12.5, weight: FontWeight.w600, color: DesignColors.textGrey)),
      );

  Widget _itinerary() {
    final days = _lead.context.days;
    if (days.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: TripLook.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final d in days)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(TripStrings.dayLine(d.day, TripFormat.duration(d.minutes), d.spots.join(' → ')),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TripKit.text(12.5).copyWith(height: 1.35)),
            ),
        ],
      ),
    );
  }

  Widget _rateRow() {
    final rate = _lead.taxi?.listedRate;
    final total = TripLeadFormat.listedTotal(_lead);
    if (rate == null || total == null) return const SizedBox.shrink();
    Widget cell(String top, String bottom, CrossAxisAlignment align) => Column(
          crossAxisAlignment: align,
          children: [
            Text(top,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FitnessAppTheme.caption.copyWith(fontSize: 11)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: align == CrossAxisAlignment.end ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(bottom,
                  maxLines: 1,
                  style: FitnessAppTheme.title.copyWith(fontSize: 14)),
            ),
          ],
        );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(child: cell(TripStrings.yourListedRate, TripStrings.perDay(BrowseItem.inr(rate)), CrossAxisAlignment.start)),
          const SizedBox(width: 12),
          Expanded(
              child: cell(TripStrings.nDays(TripLeadFormat.dayCount(_lead)), BrowseItem.inr(total), CrossAxisAlignment.end)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final left = _lead.taxi?.fareEditsLeft ?? TripConstants.maxFareEdits;
    final replied = _lead.status == TripEnquiryStatuses.fareSent;
    return TripSheetFrame(
      title: TripStrings.fareForTrip,
      description: [TripLeadFormat.guest(_lead), TripLeadFormat.dates(_lead)].where((s) => s.isNotEmpty).join(' · '),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(TripStrings.fareFooter,
              style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11, color: DesignColors.textSecondary, height: 1.35)),
          const SizedBox(height: 4),
          const TripPaymentLine(text: TripStrings.taxiPayLine),
        ],
      ),
      children: [
        _enter(0, _itinerary()),
        _enter(1, _rateRow()),
        const SizedBox(height: 16),
        _enter(2, _label(TripStrings.yourFare)),
        _enter(2, TextField(
          controller: _fare,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
          style: _inputStyle,
          decoration: _decoration(prefix: '₹ '),
        )),
        const SizedBox(height: 14),
        _enter(3, _label(TripStrings.note)),
        _enter(3, TextField(
          controller: _note,
          minLines: 2,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.driverNoteMax)],
          style: _inputStyle,
          decoration: _decoration(),
        )),
        if (replied) ...[
          const SizedBox(height: 8),
          _enter(4, Text(TripStrings.changesLeft(left), style: FitnessAppTheme.caption.copyWith(fontSize: 11.5))),
        ],
        const SizedBox(height: 18),
        _enter(
          5,
          TripPlanButton(
            label: TripStrings.sendReply,
            height: 52,
            isLoading: _sending,
            onPressed: _sending ? null : _send,
          ),
        ),
      ],
    );
  }
}
