import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/input_formatters.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/models/trip_offer_model.dart';
import '../../trip/trip_constants.dart';
import '../../trip/trip_strings.dart';
import '../../trip/trip_strings_g3.dart';
import '../../trip/trip_strings_h4.dart';
import '../../trip/trip_strings_i5.dart';
import '../../trip/utils/trip_format.dart';
import '../../trip/widgets/trip_sheet_frame.dart';
import '../models/stay_owner_model.dart';
import 'stay_enquiries_controller.dart';
import 'stay_enquiry_format.dart';
import 'stay_enquiry_strings.dart';
import 'trip_strings_ad.dart';

class TripSendOfferSheet {
  static Future<bool> show(
    BuildContext context, {
    required TripEnquiryModel enquiry,
    required StayOwnerModel stay,
    TripOfferModel? counter,
    TripOfferModel? changeRequest,
    bool revised = false,
  }) async {
    final body = _OfferBody(enquiry: enquiry, stay: stay, counter: counter, changeRequest: changeRequest, revised: revised);
    final sent = await TripSheetFrame.show<bool>(context, body);
    return sent == true;
  }
}

class _Line {
  _Line({this.roomName, this.isOther = false, this.units = 1, this.guests = 2, String price = ''})
      : priceCtrl = TextEditingController(text: price),
        otherCtrl = TextEditingController();

  String? roomName;
  bool isOther;
  int units;
  int guests;
  final TextEditingController priceCtrl;
  final TextEditingController otherCtrl;

  int get price => int.tryParse(priceCtrl.text.trim()) ?? 0;

  String? get name {
    final v = isOther ? otherCtrl.text.trim() : roomName;
    return v == null || v.isEmpty ? null : v;
  }

  void dispose() {
    priceCtrl.dispose();
    otherCtrl.dispose();
  }
}

class _OfferBody extends StatefulWidget {
  const _OfferBody({required this.enquiry, required this.stay, this.counter, this.changeRequest, this.revised = false});

  final TripEnquiryModel enquiry;
  final StayOwnerModel stay;
  final TripOfferModel? counter;
  final TripOfferModel? changeRequest;
  final bool revised;

  @override
  State<_OfferBody> createState() => _OfferBodyState();
}

class _OfferBodyState extends State<_OfferBody> {
  static const _tone = KitTone.stay;

  static const int _maxLines = 5;

  late DateTime _checkIn;
  late DateTime _checkOut;
  final _lines = <_Line>[];
  final _advance = TextEditingController();
  final _balance = TextEditingController(text: TripStrings.atCheckIn);
  final _cancel = TextEditingController();
  final _inclusions = TextEditingController();
  final _reason = TextEditingController();
  bool _gst = false;
  bool _saving = false;
  String? _serverError;
  bool _clamped = false;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    final e = widget.enquiry;
    final today = _dateOnly(DateTime.now());
    final src = widget.revised ? (widget.changeRequest ?? e.acceptedOffer) : null;
    final dates = src ?? widget.counter;
    _checkIn = dates?.checkIn ?? e.checkIn ?? today;
    _checkOut = dates?.checkOut ?? e.checkOut ?? _checkIn.add(const Duration(days: 1));
    _clampIntoTrip();
    // A change request carries only dates, people and lines; terms come from the accepted offer.
    final terms = widget.revised ? (e.acceptedOffer ?? src) : null;
    _cancel.text = terms?.cancellationText ?? widget.stay.rules?.cancellationPolicy ?? '';
    final seed = src ?? widget.counter;
    if (seed != null && seed.lines.isNotEmpty) {
      for (final l in seed.lines) {
        _lines.add(_lineFrom(l));
      }
    } else {
      _lines.add(_newLine());
    }
    if (terms != null) {
      final adv = terms.advanceAmount;
      if (adv != null) _advance.text = '$adv';
      final bal = terms.balanceNote;
      if (bal != null && bal.isNotEmpty) _balance.text = bal;
      _inclusions.text = terms.inclusions ?? '';
      _gst = terms.gstInvoice ?? false;
    }
    for (final c in [_advance, _balance, _cancel, _inclusions, _reason]) {
      c.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    for (final c in [_advance, _balance, _cancel, _inclusions, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime? get _tripStart {
    final s = widget.enquiry.tripStartDate;
    return s == null ? null : _dateOnly(s);
  }

  DateTime? get _tripLimit {
    final l = widget.enquiry.tripCheckOutLimit;
    return l == null ? null : _dateOnly(l);
  }

  bool _outsideTrip(DateTime checkIn, DateTime checkOut) {
    final start = _tripStart;
    final limit = _tripLimit;
    if (start == null || limit == null || !start.isBefore(limit)) return false;
    return checkIn.isBefore(start) || checkOut.isAfter(limit);
  }

  void _clampIntoTrip() {
    final start = _tripStart;
    final limit = _tripLimit;
    _checkIn = _dateOnly(_checkIn);
    _checkOut = _dateOnly(_checkOut);
    if (start == null || limit == null || !_outsideTrip(_checkIn, _checkOut)) return;
    final nights = _checkOut.difference(_checkIn).inDays.clamp(1, limit.difference(start).inDays);
    final lastIn = limit.subtract(const Duration(days: 1));
    var checkIn = _checkIn.isBefore(start) ? start : _checkIn;
    if (checkIn.isAfter(lastIn)) checkIn = lastIn;
    var checkOut = checkIn.add(Duration(days: nights));
    if (checkOut.isAfter(limit)) checkOut = limit;
    _checkIn = checkIn;
    _checkOut = checkOut;
    _clamped = true;
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  _Line _newLine() {
    final rooms = widget.stay.rooms;
    final used = _lines.map((l) => l.roomName).toSet();
    final room = rooms.firstWhereOrNull((r) => !used.contains(r.label)) ?? (rooms.isNotEmpty ? rooms.first : null);
    final c = widget.enquiry.context;
    final units = _lines.isEmpty ? (c.rooms ?? 1).clamp(1, 10) : 1;
    final party = (c.adults ?? 0) + (c.kids ?? 0);
    final guests = (party > 0 ? (party / units).ceil() : (room?.maxGuests ?? 2)).clamp(1, 40);
    final line = _Line(
      roomName: room?.label,
      isOther: room == null,
      units: units,
      guests: guests,
      price: room == null ? '' : '${room.pricePerNight}',
    );
    line.priceCtrl.addListener(_refresh);
    line.otherCtrl.addListener(_refresh);
    return line;
  }

  _Line _lineFrom(TripOfferLine src) {
    final rooms = widget.stay.rooms;
    final name = src.roomName;
    final match = name == null ? null : rooms.firstWhereOrNull((r) => r.label == name);
    final fallback = name == null && rooms.isNotEmpty ? rooms.first : null;
    final line = _Line(
      roomName: match?.label ?? fallback?.label,
      isOther: match == null && fallback == null,
      units: src.units.clamp(1, 10),
      guests: src.guests.clamp(1, 40),
      price: '${src.pricePerNight}',
    );
    if (match == null && name != null) line.otherCtrl.text = name;
    line.priceCtrl.addListener(_refresh);
    line.otherCtrl.addListener(_refresh);
    return line;
  }

  int get _nights => _checkOut.difference(_checkIn).inDays;

  DateTime get _lastCheckOut {
    final e = widget.enquiry;
    var last = _checkIn.add(const Duration(days: 1));
    for (final d in [e.checkOut, widget.changeRequest?.checkOut, e.acceptedOffer?.checkOut]) {
      if (d != null && _dateOnly(d).isAfter(last)) last = _dateOnly(d);
    }
    final limit = e.tripCheckOutLimit;
    if (limit != null && last.isAfter(limit)) {
      final floor = _checkIn.add(const Duration(days: 1));
      last = limit.isAfter(floor) ? limit : floor;
    }
    return last;
  }

  DateTime get _firstCheckIn {
    final today = _dateOnly(DateTime.now());
    final start = _tripStart;
    final lower = start != null && start.isAfter(today) ? start : today;
    final first = _checkIn.isBefore(lower) ? _checkIn : lower;
    return start != null && first.isBefore(start) ? start : first;
  }

  String? get _tripHint {
    final a = widget.enquiry.tripStartDate;
    final b = widget.enquiry.tripCheckOutLimit;
    return a == null || b == null ? null : TripStringsG3.insideTrip(TripFormat.dayMonthRange(a, b));
  }

  int get _perNight => _lines.fold(0, (sum, l) => sum + l.units * l.price);

  int get _total => _nights > 0 ? _nights * _perNight : 0;

  Future<void> _pickDate({required bool isCheckIn}) async {
    final initial = isCheckIn ? _checkIn : _checkOut;
    final lastOut = _lastCheckOut;
    final firstIn = _firstCheckIn;
    final lastDate = isCheckIn ? lastOut.subtract(const Duration(days: 1)) : lastOut;
    final firstDate = isCheckIn ? firstIn : _checkIn.add(const Duration(days: 1));
    final picked = await TemplateCalendarPopup.pickDate(
      context,
      initial: initial.isBefore(firstDate) ? firstDate : (initial.isAfter(lastDate) ? lastDate : initial),
      first: firstDate,
      last: lastDate,
      label: isCheckIn ? TripStrings.checkIn : TripStrings.checkOut,
      tone: _tone,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isCheckIn) {
        _checkIn = picked;
        if (!_checkOut.isAfter(_checkIn)) _checkOut = _checkIn.add(const Duration(days: 1));
      } else {
        _checkOut = picked;
      }
    });
  }

  String? _validate() {
    if (_nights < 1) return StayEnquiryStrings.datesInvalid;
    if (_nights > TripConstants.maxDaysCap) return StayEnquiryStrings.datesInvalid;
    if (_outsideTrip(_checkIn, _checkOut)) return _tripHint ?? StayEnquiryStrings.datesInvalid;
    for (final l in _lines) {
      if (l.price < 1) return StayEnquiryStrings.enterPrice;
      if (l.price > TripConstants.maxAmount) return TripStringsAD.priceTooHigh(TripConstants.maxAmount);
    }
    if (_total > TripConstants.maxAmount) return TripStringsAD.totalTooHigh(TripConstants.maxAmount);
    final adv = int.tryParse(_advance.text.trim());
    if (adv != null && adv > _total) return StayEnquiryStrings.advanceTooHigh;
    if (widget.revised && _reason.text.trim().isEmpty) return StayEnquiryStrings.reasonRequired;
    return null;
  }

  Future<void> _submit() async {
    if (_saving) return;
    final error = _validate();
    if (error != null) {
      setState(() => _tried = true);
      AppToast.error(error);
      return;
    }
    final adv = int.tryParse(_advance.text.trim());
    final balance = _balance.text.trim();
    final cancel = _cancel.text.trim();
    final inclusions = _inclusions.text.trim();
    final body = <String, dynamic>{
      'checkIn': StayEnquiryFormat.iso(_checkIn),
      'checkOut': StayEnquiryFormat.iso(_checkOut),
      'lines': [
        for (final l in _lines)
          TripOfferLine(roomName: l.name, units: l.units, guests: l.guests, pricePerNight: l.price).toJson(),
      ],
      'advanceAmount': ?adv,
      'balanceNote': balance.isEmpty ? null : balance,
      'cancellationText': cancel.isEmpty ? null : cancel,
      'gstInvoice': _gst,
      'inclusions': inclusions.isEmpty ? null : inclusions,
    };
    if (widget.revised) {
      body['reason'] = _reason.text.trim();
      body['changeRequestId'] = widget.changeRequest?.id;
    } else {
      if (widget.counter != null) body['counterOfferId'] = widget.counter!.id;
    }
    setState(() {
      _saving = true;
      _serverError = null;
    });
    final ctrl = StayEnquiriesController.ensure();
    final ok = widget.revised ? await ctrl.revisedOffer(widget.enquiry, body) : await ctrl.sendOffer(widget.enquiry, body);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _serverError = ctrl.lastErrorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.enquiry;
    final revised = widget.revised;
    final counter = widget.counter;
    final counterPrice = counter?.pricePerNight;
    final guest = StayEnquiryFormat.guest(e);
    final description = revised
        ? (e.listingName.isEmpty ? null : e.listingName)
        : counterPrice != null
            ? TripStringsH4.proposesPerRoom(guest, BrowseItem.inr(counterPrice))
            : StayEnquiryStrings.offerTo(guest);
    final t = _look;
    return TripSheetFrame(
      tone: t,
      art: ListingArt.moneyBag,
      size: SheetSize.form,
      title: revised ? TripStrings.revisedOffer : TripStrings.sendOffer,
      description: description,
      footnote: revised ? TripStrings.revisedFooter : TripStrings.sendOfferFooter,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SummaryBar3D(tone: t, label: '${TripStrings.total} · ${TripStrings.nights(_nights < 0 ? 0 : _nights)}', value: BrowseItem.inr(_total)),
          if (_serverError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_serverError!, style: FieldMessage.errorStyle)),
          const SizedBox(height: 8),
          GradientPillButton(
            tone: t,
            label: revised ? TripStrings.sendRevisedOffer : TripStrings.sendOffer,
            loading: _saving,
            onTap: _saving ? null : _submit,
          ),
        ],
      ),
      children: [
        if (counter != null && counterPrice != null) _counterSummary(counter, counterPrice),
        const SizedBox(height: 4),
        _twoUp(
          _dateField(TripStrings.checkIn, _checkIn, () => _pickDate(isCheckIn: true)),
          _dateField(TripStrings.checkOut, _checkOut, () => _pickDate(isCheckIn: false)),
        ),
        if (_tripHint != null) Padding(padding: const EdgeInsets.fromLTRB(6, 6, 6, 0), child: Text(_tripHint!, style: RepliesLook.foot)),
        if (_clamped)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
            child: Text(TripStringsI5.datesMovedInside, style: Ink3D.text(12, FontWeight.w600, Ink3D.body, letterSpacing: 0)),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              Expanded(child: Text(TripStrings.roomLines.toUpperCase(), style: RepliesLook.section)),
              if (_lines.length < _maxLines)
                Tap3D(
                  onTap: _saving ? null : () => setState(() => _lines.add(_newLine())),
                  label: TripStrings.addRoomLine,
                  exclude: true,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: t.tint, borderRadius: BorderRadius.circular(16)),
                    child: Text('+ ${TripStrings.addRoomLine}', style: Ink3D.text(13, FontWeight.w700, t.text, letterSpacing: 0)),
                  ),
                ),
            ],
          ),
        ),
        for (var i = 0; i < _lines.length; i++) _lineCard(i),
        if (revised)
          _field(_reason, TripStrings.reasonLabel, art: ListingArt.clipboard, maxLength: TripConstants.noteMax, lines: 2, hint: TripStrings.reasonHint, error: _tried && _reason.text.trim().isEmpty ? StayEnquiryStrings.reasonRequired : null),
        _twoUp(
          _field(_advance, TripStrings.advance, art: ListingArt.moneyBag, digits: true, maxLength: 7, prefix: '₹ ', hint: StayEnquiryStrings.optional),
          _field(_balance, TripStrings.balanceNote, art: ListingArt.clipboard, maxLength: 120),
        ),
        _field(_cancel, TripStrings.cancellationTerms, art: ListingArt.clipboard, maxLength: 300, lines: 2),
        _field(_inclusions, StayEnquiryStrings.inclusions, art: ListingArt.star, maxLength: 200, hint: StayEnquiryStrings.optional),
        const SizedBox(height: 12),
        ToggleRow(tone: t, label: TripStrings.gstInvoice, value: _gst, filled: true, onChanged: _saving ? null : (v) => setState(() => _gst = v)),
        if (!revised) KeyValueRow(label: TripStrings.validForLabel, value: StayEnquiryStrings.offerValid(e.isUrgent), divider: false),
        const SizedBox(height: 8),
      ],
    );
  }

  static final ListingTone _look = ListingTone.forest;

  Widget _counterSummary(TripOfferModel counter, int price) {
    final nights = counter.nights > 0 ? counter.nights : _nights;
    final rooms = counter.rooms > 0 ? counter.rooms : 1;
    final total = counter.total > 0 ? counter.total : price * rooms * nights;
    final listed = counter.listedPerNight;
    return ReplySummaryStrip(
      tone: _look,
      title: TripStringsAD.perRoomPerNight(price),
      subtitle: [TripStringsAD.roomsNightsTotal(rooms, nights, total), if (listed != null) TripStringsAD.listedPerNight(listed)].join('\n'),
      value: BrowseItem.inr(total),
      margin: const EdgeInsets.only(bottom: 8),
    );
  }

  Widget _twoUp(Widget a, Widget b) => LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 300) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: a),
              const SizedBox(width: 10),
              Expanded(child: b),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, b]);
        },
      );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    required String art,
    bool digits = false,
    int maxLength = 100,
    int lines = 1,
    String? prefix,
    String? hint,
    String? error,
    bool ring = false,
  }) {
    return PillField(
      tone: _look,
      controller: ctrl,
      enabled: !_saving,
      label: label,
      firstLabel: false,
      leadingArt: art,
      hint: hint,
      prefixText: prefix,
      maxLength: maxLength,
      counterText: '',
      minLines: 1,
      maxLines: lines,
      errorText: error,
      errorRing: ring,
      keyboardType: digits ? TextInputType.number : TextInputType.text,
      inputFormatters: digits ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(maxLength)] : noEmojiInputFormatters,
    );
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) => PillPickerField(
        tone: _look,
        sublabel: label,
        value: TripFormat.shortDate(value),
        leadingArt: ListingArt.calendar,
        trailing: const SizedBox.shrink(),
        enabled: !_saving,
        onTap: _saving ? null : onTap,
      );

  Widget _lineCard(int i) {
    final l = _lines[i];
    final rooms = widget.stay.rooms;
    final t = _look;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (i > 0) const Padding(padding: EdgeInsets.only(top: 14), child: Divider(height: 1, color: RepliesLook.rule)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in rooms)
                  ChoicePill(
                    tone: t,
                    label: r.label,
                    selected: !l.isOther && l.roomName == r.label,
                    onTap: () => setState(() {
                      l.isOther = false;
                      l.roomName = r.label;
                      l.priceCtrl.text = '${r.pricePerNight}';
                    }),
                  ),
                ChoicePill(tone: t, label: TripStrings.other, selected: l.isOther, onTap: () => setState(() => l.isOther = true)),
              ]),
            ),
            if (_lines.length > 1)
              IconButton(
                tooltip: StayEnquiryStrings.removeRoom,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () => setState(() {
                  _lines.removeAt(i).dispose();
                }),
                icon: const Icon(Icons.delete_outline_rounded, size: 22, color: Form3D.error),
              ),
          ],
        ),
        if (l.isOther) _field(l.otherCtrl, StayEnquiryStrings.roomName, art: ListingArt.bed, maxLength: TripConstants.roomNameMax),
        const SizedBox(height: 12),
        StepperField(tone: t, filled: true, leadingArt: ListingArt.bed, label: TripStrings.units, value: l.units, min: 1, max: 10, onChanged: (v) => setState(() => l.units = v)),
        const SizedBox(height: 12),
        StepperField(tone: t, filled: true, leadingArt: ListingArt.guests, label: TripStrings.guests, value: l.guests, min: 1, max: 40, onChanged: (v) => setState(() => l.guests = v)),
        _field(l.priceCtrl, TripStrings.pricePerNight, art: ListingArt.moneyBag, digits: true, maxLength: 7, prefix: '₹ ', ring: _tried && l.price < 1),
      ],
    );
  }
}
