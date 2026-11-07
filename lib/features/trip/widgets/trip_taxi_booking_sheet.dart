import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/contact_launcher.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/selectable_chip.dart';
import '../../taxi/guest/taxi_browse_repository.dart';
import '../../taxi/models/taxi_browse_item.dart';
import '../../taxi/taxi_option_sets.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_journey_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
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
    final size = MediaQuery.sizeOf(context);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      constraints: BoxConstraints(maxHeight: size.height * 0.9),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BookingBody(taxi: taxi, day: day, enquiry: enquiry, initialFare: initialFare),
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
    final size = MediaQuery.sizeOf(context);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      constraints: BoxConstraints(maxHeight: size.height * 0.9),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _JourneyCarBody(
          role: role, legIndex: legIndex, journeyId: journeyId, carIndex: carIndex, car: car, enquiry: enquiry),
    );
    return saved == true;
  }
}

class _BookingBody extends StatefulWidget {
  final TaxiBrowseItem? taxi;
  final int day;
  final TripEnquiryModel? enquiry;
  final int? initialFare;

  const _BookingBody({required this.taxi, required this.day, this.enquiry, this.initialFare});

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
    final ahead = plan.days.map((d) => d.day).where((d) => !_plan.isDayPast(d)).toSet();
    final enqDays = enq == null ? const <int>[] : _plan.planDaysOf(enq);
    final base = enqDays.isNotEmpty ? enqDays.toSet() : null;
    _days = base == null ? <int>{} : base.where(ahead.contains).toSet();
    if (_days.isEmpty && ahead.isNotEmpty) {
      _days.add(ahead.contains(widget.day) ? widget.day : (ahead.toList()..sort()).first);
    }
    final row = enq != null && enq.isBooked ? enq : _bookedRow();
    _pastDays = row == null ? <int>{} : _plan.planDaysOf(row).where(_plan.isDayPast).toSet();
    final anchor = {..._pastDays, ..._days}.toList()..sort();
    _leg = plan.legIndexOf(anchor.isEmpty ? widget.day : anchor.first);
    _days.removeWhere((d) => plan.legIndexOf(d) != _leg);
    _pastDays.removeWhere((d) => plan.legIndexOf(d) != _leg);
    if (_days.isEmpty) {
      final inLeg = [for (final d in plan.daysOf(_leg)) if (ahead.contains(d.day)) d.day]..sort();
      if (inLeg.isNotEmpty) _days.add(inLeg.contains(widget.day) ? widget.day : inLeg.first);
    }
    _time = _parseTime(server?.pickupTime) ?? TripTaxiEnquirySheet.defaultTime;
    final startDay = _days.isEmpty ? widget.day : (_days.toList()..sort()).first;
    _place = TextEditingController(
        text: server?.pickupPlace ?? TripStayBase.nameOf(plan, plan.legIndexOf(startDay), _plan.enquiryList) ?? '');
    final rate = _item.localDayRate;
    final fare = server?.agreedFare ??
        widget.initialFare ??
        server?.driverFare ??
        (rate == null || rate <= 0 || _days.isEmpty ? null : rate * _days.length);
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
        driverName: (e.owner.name ?? '').trim().isEmpty ? e.listingName : e.owner.name!,
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
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
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
    return date == null ? TripStrings.dayN(d) : '${TripStrings.dayN(d)} · ${TripFormat.shortDate(date)}';
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
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null && mounted) setState(() => _time = t);
  }

  Future<bool> _confirmReplace(int day, String other) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(TripStrings.replaceDriver(TripStrings.dayN(day), other),
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        content: Text(TripStrings.replaceDriverTold(other),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(TripStrings.keep,
                style: TextStyle(fontFamily: 'Poppins', color: AppColors.textMedium)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(TripStrings.replace,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  int _conflictDay(TripNightConflict c, List<int> days) {
    for (final d in days) {
      if (_plan.taxiEnquiriesForDay(d).any((e) => e.id == c.enquiryId)) return d;
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
    if (fareText.isNotEmpty && (fare == null || fare < TaxiOptionSets.minFare || fare > TaxiOptionSets.maxFare)) {
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
      final replace = await _confirmReplace(_conflictDay(conflict, days), conflict.listingName);
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
      if (ctrl.lastConflict != null) AppToast.error(ctrl.lastErrorMessage ?? TripStrings.couldNotLoad);
      setState(() => _saving = false);
      return;
    }
    AppToast.success(TripStrings.bookingSaved);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom + AppInsets.bottomViewPadding(context) + 16;
    if (_days.isEmpty) {
      return Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: TripSheetFrame(
            title: TripStringsA3.daysPassedTitle,
            description: TripStringsA3.daysPassedBody,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  side: const BorderSide(color: AppColors.divider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(TripStringsA3.close,
                    style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: TripColors.accentDark)),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text(TripStrings.iBookedTitle,
                  style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 2),
              const Text(TripStrings.iBookedSubtitle,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
              const SizedBox(height: 14),
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(_maxFareDigits)],
                style: _inputStyle,
                onChanged: (_) {
                  if (_fareError != null) setState(() => _fareError = null);
                },
                decoration: _decoration(prefix: '₹ ', helper: TripStrings.agreedFareHelp).copyWith(errorText: _fareError),
              ),
              const SizedBox(height: 6),
              _tollRow(),
              const SizedBox(height: 12),
              const SizedBox(height: 20),
              GradientButton(
                onPressed: _saving ? null : _save,
                label: TripStrings.saveBooking,
                isLoading: _saving,
                gradient: TripColors.gradient,
                shadowColor: TripColors.accent,
              ),
              const SizedBox(height: 12),
              const Text(TripStrings.taxiPayLine,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight)),
            ],
          ),
        ),
      ),
    );
  }

  static const _inputStyle = TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark);

  InputDecoration _decoration({String? prefix, String? helper}) => InputDecoration(
        prefixText: prefix,
        helperText: helper,
        helperMaxLines: 2,
        helperStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
        filled: true,
        fillColor: AppColors.scaffoldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TripColors.accent, width: 1.5)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
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
        color: TaxiColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TaxiColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: TaxiColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Iconsax.car, size: 20, color: TaxiColors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.driverName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                Text(vehicle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: TaxiColors.accent)),
                if (phone != null)
                  Text(phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight)),
              ],
            ),
          ),
          if (_phoneLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                  width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: TaxiColors.accent)),
            )
          else if (phone != null) ...[
            _iconButton(
              icon: const Icon(Iconsax.call, size: 18, color: TaxiColors.accentDark),
              tooltip: TripStrings.call,
              onTap: () => ContactLauncher.call(phone),
            ),
            _iconButton(
              icon: Image.asset('assets/images/whatsapp_icon.png',
                  width: 18,
                  height: 18,
                  errorBuilder: (_, _, _) => const Icon(Icons.chat, color: AppColors.whatsApp, size: 18)),
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

  Widget _iconButton({required Widget icon, required String tooltip, required VoidCallback onTap}) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
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
          Opacity(
            opacity: _plan.isDayPast(d) || _tripPlan.legIndexOf(d) != _leg ? 0.4 : 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: SelectableChip(
                label: _dayLabel(d),
                selected: _days.contains(d) || _pastDays.contains(d),
                onTap: () => _toggleDay(d),
                activeColor: TripColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              ),
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
        const Text(TripStringsMccK2.pickInOneCity,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
      ],
    );
  }

  Widget _pickupRow() {
    return LayoutBuilder(builder: (context, c) {
      final time = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(TripStrings.pickupTime),
          InkWell(
            onTap: _pickTime,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.clock, size: 16, color: TripColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(TripFormat.time12(TripFormat.hhmm(_time)),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: _inputStyle),
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
            inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripTaxiEnquirySheet.placeMax)],
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
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [time, const SizedBox(height: 12), place]);
    });
  }

  Widget _tollRow() => InkWell(
        onTap: () => setState(() => _toll = !_toll),
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Checkbox(
                  value: _toll,
                  activeColor: TripColors.accent,
                  onChanged: (v) => setState(() => _toll = v ?? false),
                ),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(TripStrings.tollExtra,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textDark)),
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

  const _JourneyCarBody(
      {this.role, this.legIndex, required this.journeyId, required this.carIndex, required this.car, this.enquiry})
      : assert((role == null) != (legIndex == null));

  @override
  State<_JourneyCarBody> createState() => _JourneyCarBodyState();
}

class _JourneyCarBodyState extends State<_JourneyCarBody> {
  static const _maxFareDigits = 7;
  static const _inputStyle = TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark);

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
    final fare = server?.agreedFare ?? server?.driverFare ?? _car.lastQuotedFare ?? _car.listedFare;
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

  List<TripEnquiryModel> _rows() => _plan.journeyRowsOf(role: widget.role, legIndex: widget.legIndex);

  TripEnquiryModel? _carRow() {
    TripEnquiryModel? quoted;
    for (final e in _rows()) {
      if (e.listingId != _car.taxiId || e.context.journeyLegIndex != widget.carIndex) continue;
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
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null && mounted) setState(() => _time = t);
  }

  Future<bool> _confirmReplace(String other) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(TripStrings.replaceDriver(_when, other),
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        content: Text(TripStrings.replaceDriverTold(other),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(TripStrings.keep, style: TextStyle(fontFamily: 'Poppins', color: AppColors.textMedium)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(TripStrings.replace,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark)),
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
    if (fareText.isNotEmpty && (fare == null || fare < TaxiOptionSets.minFare || fare > TaxiOptionSets.maxFare)) {
      setState(() => _fareError = TripStrings.errFareRange);
      return;
    }
    final typed = _place.text.trim();
    final place = typed.isEmpty ? (_car.fromName.trim().isEmpty ? TripStrings.pickupPlace : _car.fromName) : typed;
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
      final sameCar = _rows().any((e) => e.id == conflict.enquiryId && e.context.journeyLegIndex == widget.carIndex);
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
      if (ctrl.lastConflict != null) AppToast.error(ctrl.lastErrorMessage ?? TripStrings.couldNotLoad);
      setState(() => _saving = false);
      return;
    }
    AppToast.success(TripStrings.bookingSaved);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom + AppInsets.bottomViewPadding(context) + 16;
    if (_past || _car.taxiId == null) {
      return Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: TripSheetFrame(
            title: TripStringsA3.daysPassedTitle,
            description: TripStringsA3.daysPassedBody,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  side: const BorderSide(color: AppColors.divider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(TripStringsA3.close,
                    style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: TripColors.accentDark)),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text(TripStrings.iBookedTitle,
                  style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 2),
              const Text(TripStrings.iBookedSubtitle,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
              const SizedBox(height: 14),
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(_maxFareDigits)],
                style: _inputStyle,
                onChanged: (_) {
                  if (_fareError != null) setState(() => _fareError = null);
                },
                decoration: _decoration(prefix: '₹ ', helper: TripStrings.agreedFareHelp).copyWith(errorText: _fareError),
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
                inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.noteMax)],
                style: _inputStyle,
                decoration: _decoration(),
              ),
              const SizedBox(height: 20),
              GradientButton(
                onPressed: _saving ? null : _save,
                label: TripStrings.saveBooking,
                isLoading: _saving,
                gradient: TripColors.gradient,
                shadowColor: TripColors.accent,
              ),
              const SizedBox(height: 12),
              const Text(TripStrings.taxiPayLine,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight)),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({String? prefix, String? helper}) => InputDecoration(
        prefixText: prefix,
        helperText: helper,
        helperMaxLines: 2,
        helperStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
        filled: true,
        fillColor: AppColors.scaffoldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TripColors.accent, width: 1.5)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
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
        color: TaxiColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TaxiColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: TaxiColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Iconsax.car, size: 20, color: TaxiColors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(TripStringsMcbA3.carHeader(widget.carIndex, _car.driverName, vehicle),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                Text('${_car.fromName} → ${_car.toName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: TaxiColors.accent)),
                if (phone != null)
                  Text(phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight)),
              ],
            ),
          ),
          if (phone != null)
            Tooltip(
              message: TripStrings.call,
              child: InkWell(
                onTap: () => ContactLauncher.call(phone),
                borderRadius: BorderRadius.circular(22),
                child: const SizedBox(
                    width: 44, height: 44, child: Center(child: Icon(Iconsax.call, size: 18, color: TaxiColors.accentDark))),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayChip() {
    final date = _date;
    final label = date == null ? _when : TripStringsMcbA3.travelDay(TripFormat.shortDate(date));
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: TripColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TripColors.accent.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Iconsax.calendar_1, size: 16, color: TripColors.accentDark),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: TripColors.accentDark)),
          ),
        ]),
      ),
    );
  }

  Widget _pickupRow() {
    return LayoutBuilder(builder: (context, c) {
      final time = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(TripStrings.pickupTime),
          InkWell(
            onTap: _pickTime,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.clock, size: 16, color: TripColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(TripFormat.time12(TripFormat.hhmm(_time)),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: _inputStyle),
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
            inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripTaxiEnquirySheet.placeMax)],
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
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [time, const SizedBox(height: 12), place]);
    });
  }

  Widget _tollRow() => InkWell(
        onTap: () => setState(() => _toll = !_toll),
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Checkbox(
                  value: _toll,
                  activeColor: TripColors.accent,
                  onChanged: (v) => setState(() => _toll = v ?? false),
                ),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(TripStrings.tollExtra,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textDark)),
              ),
            ],
          ),
        ),
      );
}
