import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/gradient_button.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../utils/trip_format.dart';
import '../utils/trip_clock.dart';
import 'trip_payment_line.dart';
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
    _origRooms = acceptedRooms > 0 ? acceptedRooms : (e.context.rooms ?? TripConstants.defaultRooms);
    _checkIn = _day(widget.checkIn) ?? _origIn;
    _checkOut = _day(widget.checkOut) ?? _origOut;
    final want = widget.prefill;
    _adults = (want?.adults ?? _origAdults).clamp(1, TripConstants.maxAdults);
    _kids = (want?.kids ?? _origKids).clamp(0, TripConstants.maxKids);
    _rooms = (want?.rooms ?? _origRooms).clamp(1, TripConstants.maxRooms);
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
    return showDatePicker(
      context: context,
      initialDate: init,
      firstDate: first,
      lastDate: last,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: TripColors.accent)),
        child: child!,
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return TripSheetFrame(
      title: widget.title ?? TripStrings.changeRequest,
      description: widget.enquiry.listingName.isEmpty ? null : widget.enquiry.listingName,
      footer: const TripPaymentLine(),
      children: [
        _datesRow(),
        const SizedBox(height: 14),
        _card(children: [
          _stepperRow(TripStrings.adults, _adults, 1, TripConstants.maxAdults, (v) => setState(() => _adults = v)),
          const Divider(height: 1, color: AppColors.divider),
          _stepperRow(TripStrings.kids, _kids, 0, TripConstants.maxKids, (v) => setState(() => _kids = v)),
          const Divider(height: 1, color: AppColors.divider),
          _stepperRow(TripStrings.rooms, _rooms, 1, TripConstants.maxRooms, (v) => setState(() => _rooms = v)),
        ]),
        const SizedBox(height: 14),
        _label(TripStrings.note),
        TextField(
          controller: _note,
          enabled: !_busy,
          minLines: 2,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.noteMax)],
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.scaffoldBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TripColors.accent, width: 1.5)),
          ),
        ),
        const SizedBox(height: 14),
        _info(TripStrings.bookingStaysUntilHost),
        const SizedBox(height: 16),
        GradientButton(
          onPressed: _canSend ? _send : null,
          label: TripStrings.sendChangeRequest,
          isLoading: _busy,
          height: 52,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
        ),
        if (_serverError != null || !_changed) ...[
          const SizedBox(height: 8),
          Text(
            _serverError ?? TripStrings.nothingChanged,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: _serverError != null ? FontWeight.w600 : FontWeight.w400,
              color: _serverError != null ? AppColors.error : AppColors.textLight,
            ),
          ),
        ],
      ],
    );
  }

  Widget _datesRow() {
    final cin = _checkIn;
    final cout = _checkOut;
    final inTile = _dateTile(
      label: TripStrings.checkIn,
      value: cin == null ? TripStrings.pickDate : TripFormat.shortDate(cin),
      changed: cin != _origIn,
      icon: Iconsax.calendar_1,
      onTap: _busy ? null : _pickCheckIn,
    );
    final outTile = _dateTile(
      label: TripStrings.checkOut,
      value: cout == null ? TripStrings.pickDate : TripFormat.shortDate(cout),
      changed: cout != _origOut,
      icon: Iconsax.calendar_tick,
      onTap: _busy || cin == null ? null : _pickCheckOut,
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= 340) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Expanded(child: inTile), const SizedBox(width: 12), Expanded(child: outTile)],
            ),
          );
        }
        return Column(children: [inTile, const SizedBox(height: 10), outTile]);
      },
    );
  }

  Widget _dateTile({
    required String label,
    required String value,
    required bool changed,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final active = onTap != null;
    return Material(
      color: active ? TripColors.surface : AppColors.neutralChip,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: active ? TripColors.accentDark : AppColors.textHint),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                      Text(value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: changed ? FontWeight.w700 : FontWeight.w600,
                            color: AppColors.textDark,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(children: children),
      );

  Widget _stepperRow(String label, int value, int min, int max, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          ),
          _stepButton(Icons.remove_rounded, !_busy && value > min ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 44,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('$value',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            ),
          ),
          _stepButton(Icons.add_rounded, !_busy && value < max ? () => onChanged(value + 1) : null),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return SizedBox(
      width: 44,
      height: 44,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? TripColors.surface : AppColors.neutralChip,
              border: Border.all(color: enabled ? TripColors.accent.withValues(alpha: 0.5) : AppColors.divider),
            ),
            child: Icon(icon, size: 18, color: enabled ? TripColors.accentDark : AppColors.textHint),
          ),
        ),
      ),
    );
  }

  Widget _info(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Iconsax.info_circle, size: 16, color: TripColors.accentDark),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium, height: 1.4)),
          ),
        ]),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
      );
}
