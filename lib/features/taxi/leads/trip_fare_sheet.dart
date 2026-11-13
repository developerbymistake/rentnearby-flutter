import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bakhli/design/design.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/input_formatters.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/trip_constants.dart';
import '../../trip/trip_strings.dart';
import '../../trip/utils/trip_format.dart';
import '../taxi_option_sets.dart';
import 'trip_lead_format.dart';
import 'trip_leads_controller.dart';

class TripFareSheet {
  static Future<bool> show(BuildContext context, {required TripEnquiryModel lead}) async {
    final done = await Sheet3D.show<bool>(context, builder: (_) => _FareBody(lead: lead));
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
  static const int _blocks = 4;
  late final AnimationController _anim = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);

  Widget _enter(int i, Widget child) => TemplateEntrance(
        animation: templateInterval(_anim, i, _blocks),
        animationController: _anim,
        child: child,
      );

  late final TextEditingController _fare;
  late final TextEditingController _note;
  bool _sending = false;
  bool _ring = false;
  static final ListingTone _tone = ListingTone.coral;

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
      setState(() => _ring = true);
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

  Widget _itinerary() {
    final days = _lead.context.days;
    if (days.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Form3D.fill, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final d in days)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(TripStrings.dayLine(d.day, TripFormat.duration(d.minutes), d.spots.join(' → ')),
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.body, height: 1.4, letterSpacing: 0)),
            ),
        ],
      ),
    );
  }

  Widget _rateRow() {
    final rate = _lead.taxi?.listedRate;
    final total = TripLeadFormat.listedTotal(_lead);
    if (rate == null || total == null) return const SizedBox.shrink();
    Widget cell(String top, String bottom, CrossAxisAlignment align) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: _tone.tint, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: align,
            children: [
              Text(top, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w400, Form3D.muted, letterSpacing: 0)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: align == CrossAxisAlignment.end ? Alignment.centerRight : Alignment.centerLeft,
                child: Text(bottom, maxLines: 1, style: Ink3D.text(16, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
              ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(child: cell(TripStrings.yourListedRate, TripStrings.perDay(BrowseItem.inr(rate)), CrossAxisAlignment.start)),
          const SizedBox(width: 12),
          Expanded(child: cell(TripStrings.nDays(TripLeadFormat.dayCount(_lead)), BrowseItem.inr(total), CrossAxisAlignment.end)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final left = _lead.taxi?.fareEditsLeft ?? TripConstants.maxFareEdits;
    final replied = _lead.status == TripEnquiryStatuses.fareSent;
    final cut = TripStrings.yourFare.indexOf(' (');
    final fareLabel = cut < 0 ? TripStrings.yourFare : TripStrings.yourFare.substring(0, cut);
    final fareHelp = cut < 0 ? null : TripStrings.yourFare.substring(cut + 2).replaceAll(')', '');
    return Sheet3D(
      tone: _tone,
      art: ListingArt.moneyBag,
      title: TripStrings.fareForTrip,
      subtitle: [TripLeadFormat.guest(_lead), TripLeadFormat.dates(_lead)].where((s) => s.isNotEmpty).join(' · '),
      centerTitle: false,
      artRight: true,
      size: SheetSize.list,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          GradientPillButton(
            tone: _tone,
            label: TripStrings.sendReply,
            loading: _sending,
            onTap: _sending ? null : _send,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _enter(0, _itinerary()),
          _enter(1, _rateRow()),
          _enter(
            2,
            PillField(
              tone: _tone,
              label: fareLabel,
              controller: _fare,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
              prefixText: '₹',
              helperText: fareHelp == null || fareHelp.isEmpty ? null : '${fareHelp[0].toUpperCase()}${fareHelp.substring(1)}.',
              errorRing: _ring,
              onChanged: (_) {
                if (_ring) setState(() => _ring = false);
              },
            ),
          ),
          _enter(
            3,
            PillField(
              tone: _tone,
              label: TripStrings.note,
              firstLabel: false,
              controller: _note,
              minLines: 2,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.driverNoteMax)],
            ),
          ),
          if (replied) Padding(padding: const EdgeInsets.only(top: 8, left: 4), child: Text(TripStrings.changesLeft(left), style: FieldMessage.helperStyle)),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Ink3D.line),
          const SizedBox(height: 10),
          Text(TripStrings.fareFooter, style: Ink3D.text(11.5, FontWeight.w400, Form3D.muted, height: 1.4, letterSpacing: 0)),
          const SizedBox(height: 6),
          Row(children: [
            Image.asset(ListingArt.moneyBag, width: 26, height: 26),
            const SizedBox(width: 8),
            Expanded(child: Text(TripStrings.taxiPayLine, style: Ink3D.text(11.5, FontWeight.w700, Ink3D.sub, height: 1.4, letterSpacing: 0))),
          ]),
        ],
      ),
    );
  }
}
