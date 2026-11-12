import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
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
  String? _whatsApp;

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
      _whatsApp = enq!.owner.whatsApp ?? phone;
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
        _whatsApp = d.whatsAppNumber ?? d.contactPhone;
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
      tone: KitTone.trip,
    );
    if (t != null && mounted) setState(() => _time = t);
  }

  Future<bool> _confirmReplace(int day, String other) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DesignColors.surface,
        shape: RoundedRectangleBorder(borderRadius: CardRadius.tile),
        title: Text(
          TripStrings.replaceDriver(TripStrings.dayN(day), other),
          style: const TextStyle(
            fontFamily: FitnessAppTheme.fontName,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: DesignColors.textStrong,
          ),
        ),
        content: Text(
          TripStrings.replaceDriverTold(other),
          style: const TextStyle(
            fontFamily: FitnessAppTheme.fontName,
            fontSize: 13,
            color: DesignColors.textSecondary,
          ),
        ),
        actions: [
          TextLink(
            label: TripStrings.keep,
            onTap: () => Navigator.pop(ctx, false),
            tone: KitTone.trip,
          ),
          TextLink(
            label: TripStrings.replace,
            onTap: () => Navigator.pop(ctx, true),
            tone: KitTone.trip,
          ),
        ],
      ),
    );
    return ok == true;
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
    if (_days.isEmpty) {
      return TripSheetFrame(
        title: TripStringsA3.daysPassedTitle,
        description: TripStringsA3.daysPassedBody,
        children: [
          SecondaryButton(
            label: TripStringsA3.close,
            tone: KitTone.trip,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      );
    }
    return SheetFrame(
      title: TripStrings.iBookedTitle,
      subtitle: TripStrings.iBookedSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _driverCard(),
          const SizedBox(height: 18),
          _label(TripStrings.days),
          _daysWrap(),
          const SizedBox(height: 18),
          _pickupRow(),
          const SizedBox(height: 18),
          _label(TripStrings.agreedFare),
          TextField(
            controller: _fare,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_maxFareDigits),
            ],
            style: _inputStyle,
            onChanged: (_) {
              if (_fareError != null) setState(() => _fareError = null);
            },
            decoration: _decoration(
              prefix: '₹ ',
              helper: TripStrings.agreedFareHelp,
            ).copyWith(errorText: _fareError),
          ),
          const SizedBox(height: 6),
          _tollRow(),
          const SizedBox(height: 12),
          const SizedBox(height: 20),
          TripButton(
            onPressed: _saving ? null : _save,
            label: TripStrings.saveBooking,
            isLoading: _saving,
            gradient: KitTone.trip.gradient,
            shadowColor: TripUi.trip,
          ),
          const SizedBox(height: 12),
          const Text(
            TripStrings.taxiPayLine,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: FitnessAppTheme.fontName,
              fontSize: 11.5,
              color: DesignColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static const _inputStyle = TextStyle(
    fontFamily: FitnessAppTheme.fontName,
    fontSize: 14,
    color: DesignColors.textStrong,
  );

  InputDecoration _decoration({String? prefix, String? helper}) =>
      InputDecoration(
        prefixText: prefix,
        helperText: helper,
        helperMaxLines: 2,
        helperStyle: const TextStyle(
          fontFamily: FitnessAppTheme.fontName,
          fontSize: 11,
          color: DesignColors.textSecondary,
        ),
        filled: true,
        fillColor: DesignColors.scaffold,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: CardRadius.chip,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: CardRadius.chip,
          borderSide: const BorderSide(color: FitnessAppTheme.spacer),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: CardRadius.chip,
          borderSide: const BorderSide(color: TripUi.trip, width: 1.5),
        ),
      );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: FitnessAppTheme.fontName,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: DesignColors.textPrimary,
      ),
    ),
  );

  Widget _driverCard() {
    final t = _item;
    final vehicle = [
      t.vehicleTypeName,
      if (t.seats != null) '${TaxiOptionSets.seatsLabel(t.seats!)} seats',
    ].join(' · ');
    final phone = _phone;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TripUi.taxiTint,
        borderRadius: CardRadius.tile,
        border: Border.all(color: TripUi.taxi.withValues(alpha: Alpha.soft)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: TripUi.taxi.withValues(alpha: Alpha.tint),
              borderRadius: CardRadius.chip,
            ),
            child: const TravelIcon(TravelIcon.taxi, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.driverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: FitnessAppTheme.fontName,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: DesignColors.textStrong,
                  ),
                ),
                Text(
                  vehicle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: FitnessAppTheme.fontName,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: TripUi.taxi,
                  ),
                ),
                if (phone != null)
                  Text(
                    phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: FitnessAppTheme.fontName,
                      fontSize: 11.5,
                      color: DesignColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (_phoneLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: KitDots(color: TripUi.taxi),
            )
          else if (phone != null) ...[
            _iconButton(
              icon: const Icon(
                Icons.call_rounded,
                size: 18,
                color: TripUi.taxiDark,
              ),
              tooltip: TripStrings.call,
              onTap: () => ContactLauncher.call(phone),
            ),
            _iconButton(
              icon: const WhatsAppGlyph(size: 20),
              tooltip: TripStrings.whatsApp,
              onTap: () => ContactLauncher.whatsApp(
                _whatsApp ?? phone,
                message: _plan.whatsAppMessage(widget.day, _item.driverName),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconButton({
    required Widget icon,
    required String tooltip,
    required VoidCallback onTap,
  }) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: CardRadius.pill,
      child: SizedBox(width: 44, height: 44, child: Center(child: icon)),
    ),
  );

  Widget _daysWrap() {
    final dayNumbers = _tripPlan.days.map((d) => d.day).toList();
    final multi = _tripPlan.isMultiCity;
    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final d in dayNumbers)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: TripChoiceChip(
              label: _dayLabel(d),
              selected: _days.contains(d) || _pastDays.contains(d),
              muted: _plan.isDayPast(d) || _tripPlan.legIndexOf(d) != _leg,
              onTap: () => _toggleDay(d),
              activeColor: TripUi.trip,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            ),
          ),
      ],
    );
    if (!multi) return chips;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chips,
        const SizedBox(height: 6),
        const Text(
          TripStringsMccK2.pickInOneCity,
          style: TextStyle(
            fontFamily: FitnessAppTheme.fontName,
            fontSize: 11,
            color: DesignColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _pickupRow() {
    return LayoutBuilder(
      builder: (context, c) {
        final time = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(TripStrings.pickupTime),
            InkWell(
              onTap: _pickTime,
              borderRadius: CardRadius.chip,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: DesignColors.scaffold,
                  borderRadius: CardRadius.chip,
                  border: Border.all(color: FitnessAppTheme.spacer),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: TripUi.taxiDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        TripFormat.time12(TripFormat.hhmm(_time)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _inputStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
        final place = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(TripStrings.pickupPlace),
            TextField(
              controller: _place,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                ...noEmojiInputFormatters,
                LengthLimitingTextInputFormatter(TripTaxiEnquirySheet.placeMax),
              ],
              style: _inputStyle,
              decoration: _decoration(),
            ),
          ],
        );
        if (c.maxWidth >= 340) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: time),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: place),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [time, const SizedBox(height: 12), place],
        );
      },
    );
  }

  Widget _tollRow() => InkWell(
    onTap: () => setState(() => _toll = !_toll),
    borderRadius: CardRadius.chip,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Checkbox(
              value: _toll,
              activeColor: TripUi.trip,
              onChanged: (v) => setState(() => _toll = v ?? false),
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              TripStrings.tollExtra,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: FitnessAppTheme.fontName,
                fontSize: 13,
                color: DesignColors.textStrong,
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
  static const _inputStyle = TextStyle(
    fontFamily: FitnessAppTheme.fontName,
    fontSize: 14,
    color: DesignColors.textStrong,
  );

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
      tone: KitTone.trip,
    );
    if (t != null && mounted) setState(() => _time = t);
  }

  Future<bool> _confirmReplace(String other) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DesignColors.surface,
        shape: RoundedRectangleBorder(borderRadius: CardRadius.tile),
        title: Text(
          TripStrings.replaceDriver(_when, other),
          style: const TextStyle(
            fontFamily: FitnessAppTheme.fontName,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: DesignColors.textStrong,
          ),
        ),
        content: Text(
          TripStrings.replaceDriverTold(other),
          style: const TextStyle(
            fontFamily: FitnessAppTheme.fontName,
            fontSize: 13,
            color: DesignColors.textSecondary,
          ),
        ),
        actions: [
          TextLink(
            label: TripStrings.keep,
            onTap: () => Navigator.pop(ctx, false),
            tone: KitTone.trip,
          ),
          TextLink(
            label: TripStrings.replace,
            onTap: () => Navigator.pop(ctx, true),
            tone: KitTone.trip,
          ),
        ],
      ),
    );
    return ok == true;
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
    if (_past || _car.taxiId == null) {
      return TripSheetFrame(
        title: TripStringsA3.daysPassedTitle,
        description: TripStringsA3.daysPassedBody,
        children: [
          SecondaryButton(
            label: TripStringsA3.close,
            tone: KitTone.trip,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      );
    }
    return SheetFrame(
      title: TripStrings.iBookedTitle,
      subtitle: TripStrings.iBookedSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _carCard(),
          const SizedBox(height: 18),
          _dayChip(),
          const SizedBox(height: 18),
          _pickupRow(),
          const SizedBox(height: 18),
          _label(TripStringsMcbA3.fareForCar),
          TextField(
            controller: _fare,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_maxFareDigits),
            ],
            style: _inputStyle,
            onChanged: (_) {
              if (_fareError != null) setState(() => _fareError = null);
            },
            decoration: _decoration(
              prefix: '₹ ',
              helper: TripStrings.agreedFareHelp,
            ).copyWith(errorText: _fareError),
          ),
          const SizedBox(height: 6),
          _tollRow(),
          const SizedBox(height: 12),
          _label(TripStrings.note),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [
              ...noEmojiInputFormatters,
              LengthLimitingTextInputFormatter(TripConstants.noteMax),
            ],
            style: _inputStyle,
            decoration: _decoration(),
          ),
          const SizedBox(height: 20),
          TripButton(
            onPressed: _saving ? null : _save,
            label: TripStrings.saveBooking,
            isLoading: _saving,
            gradient: KitTone.trip.gradient,
            shadowColor: TripUi.trip,
          ),
          const SizedBox(height: 12),
          const Text(
            TripStrings.taxiPayLine,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: FitnessAppTheme.fontName,
              fontSize: 11.5,
              color: DesignColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration({String? prefix, String? helper}) =>
      InputDecoration(
        prefixText: prefix,
        helperText: helper,
        helperMaxLines: 2,
        helperStyle: const TextStyle(
          fontFamily: FitnessAppTheme.fontName,
          fontSize: 11,
          color: DesignColors.textSecondary,
        ),
        filled: true,
        fillColor: DesignColors.scaffold,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: CardRadius.chip,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: CardRadius.chip,
          borderSide: const BorderSide(color: FitnessAppTheme.spacer),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: CardRadius.chip,
          borderSide: const BorderSide(color: TripUi.trip, width: 1.5),
        ),
      );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: FitnessAppTheme.fontName,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: DesignColors.textPrimary,
      ),
    ),
  );

  Widget _carCard() {
    final vehicle = [
      if ((_car.vehicleTypeName ?? '').isNotEmpty) _car.vehicleTypeName!,
      if (_car.seats != null) '${TaxiOptionSets.seatsLabel(_car.seats!)} seats',
    ].join(' · ');
    final phone = _car.phone;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TripUi.taxiTint,
        borderRadius: CardRadius.tile,
        border: Border.all(color: TripUi.taxi.withValues(alpha: Alpha.soft)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: TripUi.taxi.withValues(alpha: Alpha.tint),
              borderRadius: CardRadius.chip,
            ),
            child: const TravelIcon(TravelIcon.taxi, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TripStringsMcbA3.carHeader(
                    widget.carIndex,
                    _car.driverName,
                    vehicle,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: FitnessAppTheme.fontName,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: DesignColors.textStrong,
                  ),
                ),
                Text(
                  '${_car.fromName} → ${_car.toName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: FitnessAppTheme.fontName,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: TripUi.taxi,
                  ),
                ),
                if (phone != null)
                  Text(
                    phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: FitnessAppTheme.fontName,
                      fontSize: 11.5,
                      color: DesignColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (phone != null)
            Tooltip(
              message: TripStrings.call,
              child: InkWell(
                onTap: () => ContactLauncher.call(phone),
                borderRadius: CardRadius.pill,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Icon(
                      Icons.call_rounded,
                      size: 18,
                      color: TripUi.taxiDark,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayChip() {
    final date = _date;
    final label = date == null
        ? _when
        : TripStringsMcbA3.travelDay(TripFormat.shortDate(date));
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: TripUi.tripTint,
          borderRadius: CardRadius.chip,
          border: Border.all(color: TripUi.trip.withValues(alpha: Alpha.half)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TravelIcon(TravelIcon.calendar, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: FitnessAppTheme.fontName,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: TripUi.tripDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickupRow() {
    return LayoutBuilder(
      builder: (context, c) {
        final time = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(TripStrings.pickupTime),
            InkWell(
              onTap: _pickTime,
              borderRadius: CardRadius.chip,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: DesignColors.scaffold,
                  borderRadius: CardRadius.chip,
                  border: Border.all(color: FitnessAppTheme.spacer),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: TripUi.taxiDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        TripFormat.time12(TripFormat.hhmm(_time)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _inputStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
        final place = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(TripStrings.pickupPlace),
            TextField(
              controller: _place,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                ...noEmojiInputFormatters,
                LengthLimitingTextInputFormatter(TripTaxiEnquirySheet.placeMax),
              ],
              style: _inputStyle,
              decoration: _decoration(),
            ),
          ],
        );
        if (c.maxWidth >= 340) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: time),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: place),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [time, const SizedBox(height: 12), place],
        );
      },
    );
  }

  Widget _tollRow() => InkWell(
    onTap: () => setState(() => _toll = !_toll),
    borderRadius: CardRadius.chip,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Checkbox(
              value: _toll,
              activeColor: TripUi.trip,
              onChanged: (v) => setState(() => _toll = v ?? false),
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              TripStrings.tollExtra,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: FitnessAppTheme.fontName,
                fontSize: 13,
                color: DesignColors.textStrong,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
