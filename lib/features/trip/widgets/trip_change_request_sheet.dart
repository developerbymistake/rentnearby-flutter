import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/input_formatters.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../utils/trip_format.dart';
import '../utils/trip_clock.dart';
import 'trip_sheet_frame.dart';

class TripChangeRequestSheet {
  static Future<bool> show(
    BuildContext context, {
    required TripEnquiryModel enquiry,
    TripSettings? prefill,
    DateTime? checkIn,
    DateTime? checkOut,
    String? title,
  }) async {
    final ok = await TripSheetFrame.show<bool>(
      context,
      _ChangeBody(enquiry: enquiry, prefill: prefill, checkIn: checkIn, checkOut: checkOut, title: title),
    );
    return ok == true;
  }
}

class _ChangeBody extends StatefulWidget {
  const _ChangeBody({required this.enquiry, this.prefill, this.checkIn, this.checkOut, this.title});

  final TripEnquiryModel enquiry;
  final TripSettings? prefill;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String? title;

  @override
  State<_ChangeBody> createState() => _ChangeBodyState();
}

class _ChangeBodyState extends State<_ChangeBody> {
  static const int _maxNights = TripConstants.maxDaysCap;
  static const int _maxRooms = 15;
  static const int _defaultRooms = 1;

  final _note = TextEditingController();
  late DateTime? _checkIn;
  late DateTime? _checkOut;
  late int _adults;
  late int _kids;
  late int _rooms;
  late final DateTime? _origIn;
  late final DateTime? _origOut;
  late final int _origAdults;
  late final int _origKids;
  late final int _origRooms;
  DateTime? _tripFirst;
  DateTime? _tripCheckOut;
  bool _busy = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    final e = widget.enquiry;
    final accepted = e.acceptedOffer;
    _origIn = _day(accepted?.checkIn ?? e.checkIn);
    _origOut = _day(accepted?.checkOut ?? e.checkOut);
    _origAdults = e.context.adults ?? TripConstants.defaultAdults;
    _origKids = e.context.kids ?? 0;
    final acceptedRooms = accepted?.rooms ?? 0;
    _origRooms = acceptedRooms > 0 ? acceptedRooms : (e.context.rooms ?? _defaultRooms);
    _checkIn = _day(widget.checkIn) ?? _origIn;
    _checkOut = _day(widget.checkOut) ?? _origOut;
    final want = widget.prefill;
    _adults = (want?.adults ?? _origAdults).clamp(1, TripConstants.maxAdults);
    _kids = (want?.kids ?? _origKids).clamp(0, TripConstants.maxKids);
    _rooms = _origRooms.clamp(1, _maxRooms);
    _tripFirst = _day(e.tripStartDate);
    _tripCheckOut = _day(e.tripCheckOutLimit);
    if ((_tripFirst == null || _tripCheckOut == null) && Get.isRegistered<TripPlanController>()) {
      final plan = Get.find<TripPlanController>();
      if (plan.trip.value?.id != null && plan.trip.value?.id == e.tripId) {
        _tripFirst = _day(plan.dateOf(1));
        final lastDay = _day(plan.settings.endDate(plan.dayCount));
        _tripCheckOut = lastDay == null ? null : DateTime(lastDay.year, lastDay.month, lastDay.day + 1);
      }
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  static DateTime? _day(DateTime? d) => d == null ? null : DateTime(d.year, d.month, d.day);

  DateTime get _today => TripClock.today();

  bool get _changed =>
      _checkIn != _origIn || _checkOut != _origOut || _adults != _origAdults || _kids != _origKids || _rooms != _origRooms;

  bool get _datesValid {
    final a = _checkIn;
    final b = _checkOut;
    if (a == null || b == null || !a.isBefore(b)) return false;
    return b.difference(a).inDays <= _maxNights;
  }

  bool get _canSend => _changed && _datesValid && !_busy;

  Future<DateTime?> _pick({required DateTime initial, required DateTime first, required DateTime last}) {
    var init = initial;
    if (init.isBefore(first)) init = first;
    if (init.isAfter(last)) init = last;
    return TemplateCalendarPopup.pickDate(context, initial: init, first: first, last: last, tone: KitTone.trip);
  }

  Future<void> _pickCheckIn() async {
    FocusScope.of(context).unfocus();
    final tripFirst = _tripFirst;
    final tripCheckOut = _tripCheckOut;
    var first = _today;
    if (tripFirst != null && tripFirst.isAfter(first)) first = tripFirst;
    final last = tripCheckOut != null
        ? DateTime(tripCheckOut.year, tripCheckOut.month, tripCheckOut.day - 1)
        : _today.add(const Duration(days: TripConstants.maxStartDaysAhead));
    if (last.isBefore(first)) return;
    final picked = await _pick(initial: _checkIn ?? first, first: first, last: last);
    if (picked == null || !mounted) return;
    final d = DateTime(picked.year, picked.month, picked.day);
    setState(() {
      _checkIn = d;
      final out = _checkOut;
      if (out == null || !d.isBefore(out) || out.difference(d).inDays > _maxNights) {
        _checkOut = DateTime(d.year, d.month, d.day + 1);
      }
      _serverError = null;
    });
  }

  Future<void> _pickCheckOut() async {
    FocusScope.of(context).unfocus();
    final cin = _checkIn;
    if (cin == null) return;
    final first = DateTime(cin.year, cin.month, cin.day + 1);
    var last = DateTime(cin.year, cin.month, cin.day + _maxNights);
    final tripCheckOut = _tripCheckOut;
    if (tripCheckOut != null && tripCheckOut.isBefore(last)) last = tripCheckOut;
    if (last.isBefore(first)) return;
    final picked = await _pick(initial: _checkOut ?? first, first: first, last: last);
    if (picked == null || !mounted) return;
    setState(() {
      _checkOut = DateTime(picked.year, picked.month, picked.day);
      _serverError = null;
    });
  }

  Future<void> _send() async {
    final cin = _checkIn;
    final cout = _checkOut;
    if (!_canSend || cin == null || cout == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _serverError = null;
    });
    final ctrl = TripEnquiryController.to;
    final res = await ctrl.changeRequest(
      widget.enquiry.id,
      checkIn: cin,
      checkOut: cout,
      adults: _adults,
      kids: _kids,
      rooms: _rooms,
      note: _note.text,
    );
    if (!mounted) return;
    if (res != null) {
      AppToast.success(TripStrings.changeRequestSent);
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _serverError = ctrl.lastErrorMessage;
    });
  }

  static final ListingTone _tone = ListingTone.forest;

  @override
  Widget build(BuildContext context) {
    final e = widget.enquiry;
    final cin = _checkIn;
    final cout = _checkOut;
    final oi = _origIn;
    final oo = _origOut;
    final now = oi == null || oo == null ? e.datesLabel : TripFormat.dayMonthRange(oi, oo);
    final total = e.agreedTotal;
    final sub = e.listingName;
    final message = _serverError ?? (_changed ? null : TripStrings.nothingChanged);
    final dates = [
      PillPickerField(
        tone: _tone,
        sublabel: TripStrings.checkIn,
        value: cin == null ? null : TripFormat.shortDate(cin),
        hint: TripStrings.pickDate,
        leadingArt: ListingArt.calendar,
        trailing: const SizedBox.shrink(),
        onTap: _busy ? null : _pickCheckIn,
      ),
      PillPickerField(
        tone: _tone,
        sublabel: TripStrings.checkOut,
        value: cout == null ? null : TripFormat.shortDate(cout),
        hint: TripStrings.pickDate,
        leadingArt: ListingArt.calendar,
        trailing: const SizedBox.shrink(),
        enabled: cin != null,
        onTap: _busy || cin == null ? null : _pickCheckOut,
      ),
    ];
    return TripSheetFrame(
      tone: _tone,
      art: ListingArt.calendar,
      size: SheetSize.form,
      title: widget.title ?? TripStrings.sendChangeRequest,
      description: sub.isEmpty ? null : sub,
      footnote: TripStrings.bookingStaysUntilHost,
      footer: GradientPillButton(tone: _tone, label: TripStrings.sendChangeRequest, loading: _busy, enabled: _canSend || _busy, onTap: _canSend ? _send : null),
      children: [
        ReplySummaryStrip(
          tone: _tone,
          title: '$_kNow: $now',
          subtitle: [TripStrings.peopleCount(_origAdults + _origKids), _origRooms == 1 ? '1 room' : '$_origRooms rooms'].join(' · '),
          value: total != null && total > 0 ? BrowseItem.inr(total) : '',
          margin: const EdgeInsets.only(top: 6, bottom: 12),
        ),
        LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 300
              ? Row(children: [Expanded(child: dates[0]), const SizedBox(width: 10), Expanded(child: dates[1])])
              : Column(children: [dates[0], const SizedBox(height: 10), dates[1]]),
        ),
        const SizedBox(height: 12),
        StepperField(tone: _tone, filled: true, leadingArt: ListingArt.guests, label: TripStrings.adults, value: _adults, min: 1, max: TripConstants.maxAdults, onChanged: _busy ? null : (v) => setState(() => _adults = v)),
        const SizedBox(height: 12),
        StepperField(tone: _tone, filled: true, leadingArt: ListingArt.star, label: TripStrings.kids, value: _kids, min: 0, max: TripConstants.maxKids, onChanged: _busy ? null : (v) => setState(() => _kids = v)),
        const SizedBox(height: 12),
        StepperField(tone: _tone, filled: true, leadingArt: ListingArt.bed, label: TripStrings.rooms, value: _rooms, min: 1, max: _maxRooms, onChanged: _busy ? null : (v) => setState(() => _rooms = v)),
        PillField(
          tone: _tone,
          controller: _note,
          enabled: !_busy,
          label: TripStrings.note,
          firstLabel: false,
          leadingArt: ListingArt.speechBalloon,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.noteMax)],
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: _serverError != null ? FieldMessage.errorStyle : RepliesLook.foot),
          ),
      ],
    );
  }
}

const String _kNow = 'Now';
