import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:flutter/services.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/contact_launcher.dart';
import '../../../utils/input_formatters.dart';
import '../../taxi/guest/taxi_browse_repository.dart';
import '../../taxi/models/taxi_browse_item.dart';
import '../../taxi/taxi_option_sets.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_journey_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_a3.dart';
import '../trip_strings_mcb_a3.dart';
import '../trip_strings_mcc_k2.dart';
import '../utils/trip_format.dart';
import '../utils/trip_stay_base.dart';
import '../screens/trip_taxi_enquiry_sheet.dart';
import 'trip_sheet_frame.dart';

class TripTaxiBookingSheet {
  static Future<bool> show(
    BuildContext context, {
    required TaxiBrowseItem? taxi,
    required int day,
    TripEnquiryModel? enquiry,
    int? initialFare,
  }) async {
    final saved = await SheetFrame.show<bool>(
      context,
      builder: (_) => _BookingBody(
        taxi: taxi,
        day: day,
        enquiry: enquiry,
        initialFare: initialFare,
      ),
    );
    return saved == true;
  }

  static Future<bool> showForJourneyCar(
    BuildContext context, {
    TripStepRole? role,
    int? legIndex,
    required String journeyId,
    required int carIndex,
    required TripJourneyLeg car,
    TripEnquiryModel? enquiry,
  }) async {
    final saved = await SheetFrame.show<bool>(
      context,
      builder: (_) => _JourneyCarBody(
        role: role,
        legIndex: legIndex,
        journeyId: journeyId,
        carIndex: carIndex,
        car: car,
        enquiry: enquiry,
      ),
    );
    return saved == true;
  }
}

class _BookingBody extends StatefulWidget {
  final TaxiBrowseItem? taxi;
  final int day;
  final TripEnquiryModel? enquiry;
  final int? initialFare;

  const _BookingBody({
    required this.taxi,
    required this.day,
    this.enquiry,
    this.initialFare,
  });

  @override
  State<_BookingBody> createState() => _BookingBodyState();
}

class _BookingBodyState extends State<_BookingBody> {
  static const _maxFareDigits = 7;

  late final TripPlanController _plan;
  late final Set<int> _days;
  late final Set<int> _pastDays;
  late final int _leg;
  late TimeOfDay _time;
  late final TextEditingController _place;
  late final TextEditingController _fare;
  bool _toll = false;
  bool _saving = false;
  String? _fareError;
  bool _phoneLoading = true;
  String? _phone;

  TripPlan get _tripPlan => _plan.plan.value!;

  late final TaxiBrowseItem _item;

  String get _taxiId => _item.id;

  @override
  void initState() {
    super.initState();
    _plan = TripPlanController.to;
    final plan = _tripPlan;
    final enq = widget.enquiry;
    _item = widget.taxi ?? _fromEnquiry(enq!);
    final server = enq?.taxi;
    final ahead = plan.days
        .map((d) => d.day)
        .where((d) => !_plan.isDayPast(d))
        .toSet();
    final enqDays = enq == null ? const <int>[] : _plan.planDaysOf(enq);
    final base = enqDays.isNotEmpty ? enqDays.toSet() : null;
    _days = base == null ? <int>{} : base.where(ahead.contains).toSet();
    if (_days.isEmpty && ahead.isNotEmpty) {
      _days.add(
        ahead.contains(widget.day)
            ? widget.day
            : (ahead.toList()..sort()).first,
      );
    }
    final row = enq != null && enq.isBooked ? enq : _bookedRow();
    _pastDays = row == null
        ? <int>{}
        : _plan.planDaysOf(row).where(_plan.isDayPast).toSet();
    final anchor = {..._pastDays, ..._days}.toList()..sort();
    _leg = plan.legIndexOf(anchor.isEmpty ? widget.day : anchor.first);
    _days.removeWhere((d) => plan.legIndexOf(d) != _leg);
    _pastDays.removeWhere((d) => plan.legIndexOf(d) != _leg);
    if (_days.isEmpty) {
      final inLeg = [
        for (final d in plan.daysOf(_leg))
          if (ahead.contains(d.day)) d.day,
      ]..sort();
      if (inLeg.isNotEmpty)
        _days.add(inLeg.contains(widget.day) ? widget.day : inLeg.first);
    }
    _time = _parseTime(server?.pickupTime) ?? TripTaxiEnquirySheet.defaultTime;
    final startDay = _days.isEmpty
        ? widget.day
        : (_days.toList()..sort()).first;
    _place = TextEditingController(
      text:
          server?.pickupPlace ??
          TripStayBase.nameOf(
            plan,
            plan.legIndexOf(startDay),
            _plan.enquiryList,
          ) ??
          '',
    );
    final rate = _item.localDayRate;
    final fare =
        server?.agreedFare ??
        widget.initialFare ??
        server?.driverFare ??
        (rate == null || rate <= 0 || _days.isEmpty
            ? null
            : rate * _days.length);
    _fare = TextEditingController(text: fare == null ? '' : '$fare');
    _toll = server?.tollExtra ?? false;
    final phone = enq?.owner.phone;
    if (phone != null && ContactLauncher.tenDigits(phone).isNotEmpty) {
      _phone = phone;
      _phoneLoading = false;
    } else {
      _loadPhone();
    }
  }

  static TaxiBrowseItem _fromEnquiry(TripEnquiryModel e) => TaxiBrowseItem(
    id: e.listingId,
    driverName: (e.owner.name ?? '').trim().isEmpty
        ? e.listingName
        : e.owner.name!,
    vehicleTypeName: '',
    plateDisplay: '',
    routeCount: 0,
    matchReversed: false,
    createdAt: e.createdAt ?? DateTime.now(),
  );

  @override
  void dispose() {
    _place.dispose();
    _fare.dispose();
    super.dispose();
  }

  TripEnquiryModel? _bookedRow() {
    for (final e in _plan.enquiries) {
      if (e.isTaxi && e.listingId == _taxiId && e.isBooked) return e;
    }
    return null;
  }

  TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59)
      return null;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _loadPhone() async {
    try {
      final d = await const TaxiBrowseRepository().getById(_taxiId);
      if (!mounted) return;
      setState(() {
        _phone = d.contactPhone;
        _phoneLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _phoneLoading = false);
    }
  }

  String _dayLabel(int d) {
    final date = _plan.dateOf(d);
    return date == null
        ? TripStrings.dayN(d)
        : '${TripStrings.dayN(d)} · ${TripFormat.shortDate(date)}';
  }

  void _toggleDay(int d) {
    if (_saving || _plan.isDayPast(d)) return;
    if (_tripPlan.legIndexOf(d) != _leg) {
      AppToast.warning(TripStringsMccK2.pickInOneCity);
      return;
    }
    if (_days.contains(d)) {
      if (_days.length == 1) {
        AppToast.warning(TripStrings.errPickDay);
        return;
      }
      setState(() => _days.remove(d));
    } else {
      setState(() => _days.add(d));
    }
  }

  Future<void> _pickTime() async {
    final t = await TemplateTimePopup.pick(
      context,
      initial: _time,
      label: TripStrings.pickupTime,
      tone: KitTone.taxi,
    );
    if (t != null && mounted) setState(() => _time = t);
  }

  Future<bool> _confirmReplace(int day, String other) async {
    return _replaceDialog(context, TripStrings.replaceDriver(TripStrings.dayN(day), other), TripStrings.replaceDriverTold(other));
  }

  int _conflictDay(TripNightConflict c, List<int> days) {
    for (final d in days) {
      if (_plan.taxiEnquiriesForDay(d).any((e) => e.id == c.enquiryId))
        return d;
    }
    return days.first;
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (_days.isEmpty) {
      AppToast.warning(TripStrings.errPickDay);
      return;
    }
    final fareText = _fare.text.trim();
    final fare = int.tryParse(fareText);
    if (fareText.isNotEmpty &&
        (fare == null ||
            fare < TaxiOptionSets.minFare ||
            fare > TaxiOptionSets.maxFare)) {
      setState(() => _fareError = TripStrings.errFareRange);
      return;
    }
    final typed = _place.text.trim();
    final place = typed.isEmpty ? _plan.cityNameOf(_days.first) : typed;
    setState(() {
      _fareError = null;
      _saving = true;
    });
    final days = {..._pastDays, ..._days}.toList()..sort();
    final ctrl = TripEnquiryController.to;
    final time = TripFormat.hhmm(_time);
    final replaceIds = <String>[];
    Future<TripEnquiryModel?> submit() => ctrl.bookTaxi(
      taxiId: _taxiId,
      days: days,
      agreedFare: fare,
      tollExtra: _toll,
      pickupTime: time,
      pickupPlace: place,
      replaceEnquiryId: replaceIds.isEmpty ? null : replaceIds.first,
      replaceEnquiryIds: replaceIds.isEmpty ? null : List.of(replaceIds),
    );
    var saved = await submit();
    if (!mounted) return;
    while (saved == null) {
      final conflict = ctrl.lastConflict;
      if (conflict == null || replaceIds.contains(conflict.enquiryId)) break;
      final replace = await _confirmReplace(
        _conflictDay(conflict, days),
        conflict.listingName,
      );
      if (!mounted) return;
      if (!replace) {
        setState(() => _saving = false);
        return;
      }
      replaceIds.add(conflict.enquiryId);
      saved = await submit();
      if (!mounted) return;
    }
    if (saved == null) {
      if (ctrl.lastConflict != null)
        AppToast.error(ctrl.lastErrorMessage ?? TripStrings.couldNotLoad);
      setState(() => _saving = false);
      return;
    }
    AppToast.success(TripStrings.bookingSaved);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_days.isEmpty) return _passedSheet(context);
    final multi = _tripPlan.isMultiCity;
    final t = _item;
    final vehicle = [
      t.vehicleTypeName,
      if (t.seats != null) '${TaxiOptionSets.seatsLabel(t.seats!)} seats',
    ].join(' · ');
    return TripSheetFrame(
      tone: _bookTone,
      art: ListingArt.taxi,
      size: SheetSize.form,
      title: TripStrings.iBookedTitle,
      description: TripStrings.iBookedSubtitle,
      footnote: TripStrings.taxiPayLine,
      footer: GradientPillButton(tone: _bookTone, label: TripStrings.saveBooking, loading: _saving, onTap: _saving ? null : _save),
      children: [
        _BookDriverRow(name: t.driverName, line: vehicle, phone: _phone, loading: _phoneLoading),
        Padding(padding: const EdgeInsets.only(top: 16, bottom: 10), child: Text(TripStrings.days.toUpperCase(), style: RepliesLook.section)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in _tripPlan.days.map((d) => d.day))
              ChoicePill(
                tone: _bookTone,
                label: _dayLabel(d),
                selected: _days.contains(d) || _pastDays.contains(d),
                outlined: _plan.isDayPast(d) || _tripPlan.legIndexOf(d) != _leg,
                height: 40,
                onTap: () => _toggleDay(d),
              ),
          ],
        ),
        if (multi) Padding(padding: const EdgeInsets.only(top: 6), child: Text(TripStringsMccK2.pickInOneCity, style: RepliesLook.foot)),
        const SizedBox(height: 4),
        _BookPickup(
          time: TripFormat.time12(TripFormat.hhmm(_time)),
          onTime: _pickTime,
          place: _place,
        ),
        PillField(
          tone: _bookTone,
          controller: _fare,
          label: TripStrings.agreedFare,
          firstLabel: false,
          leadingArt: ListingArt.moneyBag,
          prefixText: '₹ ',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(_maxFareDigits)],
          helperText: TripStrings.agreedFareHelp,
          errorText: _fareError,
          onChanged: (_) {
            if (_fareError != null) setState(() => _fareError = null);
          },
        ),
        const SizedBox(height: 6),
        CheckRow(tone: _bookTone, value: _toll, label: TripStrings.tollExtra, onChanged: (v) => setState(() => _toll = v)),
      ],
    );
  }
}

final ListingTone _bookTone = ListingTone.coral;

Widget _passedSheet(BuildContext context) => TripSheetFrame(
  tone: _bookTone,
  art: ListingArt.calendar,
  title: TripStringsA3.daysPassedTitle,
  description: TripStringsA3.daysPassedBody,
  footer: WhitePillButton(tone: _bookTone, label: TripStringsA3.close, onTap: () => Navigator.pop(context)),
  children: const [],
);

Future<bool> _replaceDialog(BuildContext context, String title, String body) async {
  final ok = await Dialog3D.show<bool>(
    context,
    builder: (ctx) => Dialog3D(
      tone: _bookTone,
      art: ListingArt.taxi,
      title: title,
      body: body,
      secondaryLabel: TripStrings.keep,
      onSecondary: () => Navigator.pop(ctx, false),
      primaryLabel: TripStrings.replace,
      onPrimary: () => Navigator.pop(ctx, true),
    ),
  );
  return ok == true;
}

class _BookDriverRow extends StatelessWidget {
  const _BookDriverRow({required this.name, required this.line, required this.phone, this.loading = false});

  final String name;
  final String line;
  final String? phone;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = phone;
    return GreyPillBox(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      child: Row(
        children: [
          Image.asset(ListingArt.taxi, width: 40, height: 40, fit: BoxFit.contain),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w600, Ink3D.body, letterSpacing: 0)),
                if (line.isNotEmpty) Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w600, _bookTone.text, letterSpacing: 0)),
                if (p != null) Text(p, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
              ],
            ),
          ),
          if (loading)
            Padding(padding: const EdgeInsets.all(8), child: KitDots(color: _bookTone.g2))
          else if (p != null)
            Tooltip(
              message: TripStrings.call,
              child: Tap3D(
                onTap: () => ContactLauncher.call(p),
                label: TripStrings.call,
                exclude: true,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(gradient: _bookTone.gradient, shape: BoxShape.circle, boxShadow: _bookTone.glow(blur: 6, dy: 3)),
                  child: const Icon(Icons.call_rounded, size: 20, color: DesignColors.textInverse),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BookPickup extends StatelessWidget {
  const _BookPickup({required this.time, required this.onTime, required this.place});

  final String time;
  final VoidCallback onTime;
  final TextEditingController place;

  @override
  Widget build(BuildContext context) {
    final timeField = PillPickerField(
      tone: _bookTone,
      label: TripStrings.pickupTime,
      firstLabel: false,
      value: time,
      leadingArt: ListingArt.calendar,
      trailing: const SizedBox.shrink(),
      onTap: onTime,
    );
    final placeField = PillField(
      tone: _bookTone,
      controller: place,
      label: TripStrings.pickupPlace,
      firstLabel: false,
      leadingArt: ListingArt.roundPushpin,
      textCapitalization: TextCapitalization.words,
      inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripTaxiEnquirySheet.placeMax)],
    );
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 320
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: timeField), const SizedBox(width: 10), Expanded(child: placeField)])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [timeField, placeField]),
    );
  }
}

class _JourneyCarBody extends StatefulWidget {
  final TripStepRole? role;
  final int? legIndex;
  final String journeyId;
  final int carIndex;
  final TripJourneyLeg car;
  final TripEnquiryModel? enquiry;

  const _JourneyCarBody({
    this.role,
    this.legIndex,
    required this.journeyId,
    required this.carIndex,
    required this.car,
    this.enquiry,
  }) : assert((role == null) != (legIndex == null));

  @override
  State<_JourneyCarBody> createState() => _JourneyCarBodyState();
}

class _JourneyCarBodyState extends State<_JourneyCarBody> {
  static const _maxFareDigits = 7;

  late final TripPlanController _plan;
  late final DateTime? _date;
  late final bool _past;
  late TimeOfDay _time;
  late final TextEditingController _place;
  late final TextEditingController _fare;
  late final TextEditingController _note;
  bool _toll = false;
  bool _saving = false;
  String? _fareError;

  TripJourneyLeg get _car => widget.car;

  @override
  void initState() {
    super.initState();
    _plan = TripPlanController.to;
    _date = _plan.journeyDateOf(role: widget.role, legIndex: widget.legIndex);
    _past = _plan.isDatePast(_date);
    final row = widget.enquiry ?? _carRow();
    final server = row?.taxi;
    _time = _parseTime(server?.pickupTime) ?? TripTaxiEnquirySheet.defaultTime;
    _place = TextEditingController(text: server?.pickupPlace ?? _car.fromName);
    final fare =
        server?.agreedFare ??
        server?.driverFare ??
        _car.lastQuotedFare ??
        _car.listedFare;
    _fare = TextEditingController(text: fare == null ? '' : '$fare');
    _note = TextEditingController();
    _toll = server?.tollExtra ?? false;
  }

  @override
  void dispose() {
    _place.dispose();
    _fare.dispose();
    _note.dispose();
    super.dispose();
  }

  String get _when {
    final date = _date;
    if (date != null) return TripFormat.shortDate(date);
    final k = widget.legIndex;
    return TripStrings.dayN(k == null ? 1 : _plan.plan.value?.legStart(k) ?? 1);
  }

  List<TripEnquiryModel> _rows() =>
      _plan.journeyRowsOf(role: widget.role, legIndex: widget.legIndex);

  TripEnquiryModel? _carRow() {
    TripEnquiryModel? quoted;
    for (final e in _rows()) {
      if (e.listingId != _car.taxiId ||
          e.context.journeyLegIndex != widget.carIndex)
        continue;
      if (e.isBooked) return e;
      if (e.taxi?.driverFare != null) quoted ??= e;
    }
    return quoted;
  }

  TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59)
      return null;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _pickTime() async {
    final t = await TemplateTimePopup.pick(
      context,
      initial: _time,
      label: TripStrings.pickupTime,
      tone: KitTone.taxi,
    );
    if (t != null && mounted) setState(() => _time = t);
  }

  Future<bool> _confirmReplace(String other) async {
    return _replaceDialog(context, TripStrings.replaceDriver(_when, other), TripStrings.replaceDriverTold(other));
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final taxiId = _car.taxiId;
    if (taxiId == null) return;
    final fareText = _fare.text.trim();
    final fare = int.tryParse(fareText);
    if (fareText.isNotEmpty &&
        (fare == null ||
            fare < TaxiOptionSets.minFare ||
            fare > TaxiOptionSets.maxFare)) {
      setState(() => _fareError = TripStrings.errFareRange);
      return;
    }
    final typed = _place.text.trim();
    final place = typed.isEmpty
        ? (_car.fromName.trim().isEmpty
              ? TripStrings.pickupPlace
              : _car.fromName)
        : typed;
    setState(() {
      _fareError = null;
      _saving = true;
    });
    final ctrl = TripEnquiryController.to;
    final time = TripFormat.hhmm(_time);
    final note = _note.text.trim();
    final replaceIds = <String>[];
    Future<TripEnquiryModel?> submit() => _plan.bookJourneyCar(
      role: widget.role,
      legIndex: widget.legIndex,
      journeyId: widget.journeyId,
      carIndex: widget.carIndex,
      taxiId: taxiId,
      agreedFare: fare,
      tollExtra: _toll,
      pickupTime: time,
      pickupPlace: place,
      note: note.isEmpty ? null : note,
      replaceEnquiryIds: List.of(replaceIds),
    );
    var saved = await submit();
    if (!mounted) return;
    while (saved == null) {
      final conflict = ctrl.lastConflict;
      if (conflict == null || replaceIds.contains(conflict.enquiryId)) break;
      final sameCar = _rows().any(
        (e) =>
            e.id == conflict.enquiryId &&
            e.context.journeyLegIndex == widget.carIndex,
      );
      if (!sameCar) break;
      final replace = await _confirmReplace(conflict.listingName);
      if (!mounted) return;
      if (!replace) {
        setState(() => _saving = false);
        return;
      }
      replaceIds.add(conflict.enquiryId);
      saved = await submit();
      if (!mounted) return;
    }
    if (saved == null) {
      if (ctrl.lastConflict != null)
        AppToast.error(ctrl.lastErrorMessage ?? TripStrings.couldNotLoad);
      setState(() => _saving = false);
      return;
    }
    AppToast.success(TripStrings.bookingSaved);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_past || _car.taxiId == null) return _passedSheet(context);
    final vehicle = [
      if ((_car.vehicleTypeName ?? '').isNotEmpty) _car.vehicleTypeName!,
      if (_car.seats != null) '${TaxiOptionSets.seatsLabel(_car.seats!)} seats',
    ].join(' · ');
    final date = _date;
    return TripSheetFrame(
      tone: _bookTone,
      art: ListingArt.taxi,
      size: SheetSize.form,
      title: TripStrings.iBookedTitle,
      description: TripStrings.iBookedSubtitle,
      footnote: TripStrings.taxiPayLine,
      footer: GradientPillButton(tone: _bookTone, label: TripStrings.saveBooking, loading: _saving, onTap: _saving ? null : _save),
      children: [
        _BookDriverRow(
          name: TripStringsMcbA3.carHeader(widget.carIndex, _car.driverName, vehicle),
          line: '${_car.fromName} → ${_car.toName}',
          phone: _car.phone,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ChoicePill(
              tone: _bookTone,
              label: date == null ? _when : TripStringsMcbA3.travelDay(TripFormat.shortDate(date)),
              selected: true,
              height: 40,
              onTap: () {},
            ),
          ),
        ),
        _BookPickup(time: TripFormat.time12(TripFormat.hhmm(_time)), onTime: _pickTime, place: _place),
        PillField(
          tone: _bookTone,
          controller: _fare,
          label: TripStringsMcbA3.fareForCar,
          firstLabel: false,
          leadingArt: ListingArt.moneyBag,
          prefixText: '₹ ',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(_maxFareDigits)],
          helperText: TripStrings.agreedFareHelp,
          errorText: _fareError,
          onChanged: (_) {
            if (_fareError != null) setState(() => _fareError = null);
          },
        ),
        const SizedBox(height: 6),
        CheckRow(tone: _bookTone, value: _toll, label: TripStrings.tollExtra, onChanged: (v) => setState(() => _toll = v)),
        PillField(
          tone: _bookTone,
          controller: _note,
          label: TripStrings.note,
          firstLabel: false,
          leadingArt: ListingArt.speechBalloon,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.noteMax)],
        ),
      ],
    );
  }
}
