import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/gradient_button.dart';
import '../../taxi/ways/widgets/travel_confirm_sheet.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_constants.dart';
import '../trip_strings_mca_a3.dart';
import '../utils/trip_format.dart';
import 'trip_filter_chips.dart';
import 'trip_going_home_row.dart';
import 'trip_sheet_frame.dart';

typedef TripBeforeOwn = Future<bool> Function();

class TripOwnTravelSheet {
  static Future<bool> show(
    BuildContext context,
    int legIndex, {
    TripTravelHow? initialHow,
    String? hubName,
    TripBeforeOwn? beforeSave,
  }) async {
    final c = TripPlanController.to;
    if (legIndex < 2 || c.isReadOnly || c.plan.value?.legAt(legIndex) == null) return false;
    final ok = await TripSheetFrame.show<bool>(
      context,
      _OwnTravelBody(legIndex: legIndex, initialHow: initialHow, hubName: hubName, beforeSave: beforeSave),
    );
    return ok == true;
  }

  static Future<bool> showForRole(BuildContext context, TripStepRole role, {TripBeforeOwn? beforeSave}) async {
    final c = TripPlanController.to;
    if (c.isReadOnly || c.plan.value == null) return false;
    final ok = await TripSheetFrame.show<bool>(context, _OwnTravelBody(role: role, beforeSave: beforeSave));
    return ok == true;
  }

  static String howLabel(TripTravelHow how) => switch (how) {
        TripTravelHow.car => TripStringsMcaA3.car,
        TripTravelHow.bus => TripStringsMcaA3.bus,
        TripTravelHow.train => TripStringsMcaA3.train,
        TripTravelHow.other => TripStringsMcaA3.other,
      };

  static IconData howIcon(TripTravelHow? how) => switch (how) {
        TripTravelHow.bus => Iconsax.bus,
        TripTravelHow.train => Iconsax.driving,
        TripTravelHow.car => Iconsax.car,
        _ => Iconsax.routing,
      };
}

// One sheet for all journey roles: a city change (legIndex) or Getting there / Coming back (role).
class _OwnTravelBody extends StatefulWidget {
  const _OwnTravelBody({this.legIndex, this.role, this.initialHow, this.hubName, this.beforeSave});

  final int? legIndex;
  final TripStepRole? role;
  final TripTravelHow? initialHow;
  final String? hubName;
  final TripBeforeOwn? beforeSave;

  @override
  State<_OwnTravelBody> createState() => _OwnTravelBodyState();
}

class _OwnTravelBodyState extends State<_OwnTravelBody> {
  static final _phonePattern = RegExp(r'^[6-9]\d{9}$');
  final _c = TripPlanController.to;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _note;
  TripTravelHow? _how;
  String? _leavesAt;
  int? _roadMinutes;
  String? _hubName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final role = widget.role;
    if (role != null) {
      final s = _c.stepOf(role);
      final own = s.status == TripStepStatus.own;
      _how = own ? s.how : widget.initialHow;
      _leavesAt = own ? s.leavesAt : null;
      _name = TextEditingController(text: own ? (s.ownName ?? '') : '');
      _phone = TextEditingController(text: own ? (s.ownPhone ?? '') : '');
      _note = TextEditingController(text: own ? (s.note ?? '') : '');
      return;
    }
    final current = _c.plan.value?.legAt(widget.legIndex!)?.arrival;
    final a = current != null && current.isOwn ? current : null;
    _how = a?.how ?? widget.initialHow;
    _hubName = widget.hubName ?? a?.hubName;
    _leavesAt = a?.leavesAt;
    _roadMinutes = a?.roadMinutes;
    _name = TextEditingController(text: a?.ownName ?? '');
    _phone = TextEditingController(text: a?.ownPhone ?? '');
    _note = TextEditingController(text: a?.note ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _phoneOk {
    final p = _phone.text.trim();
    return p.isEmpty || _phonePattern.hasMatch(p);
  }

  TimeOfDay? _parse(String? hhmm) {
    final m = hhmm == null ? null : RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(hhmm);
    if (m == null) return null;
    return TimeOfDay(hour: int.parse(m.group(1)!), minute: int.parse(m.group(2)!));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _parse(_leavesAt) ?? _parse(TripConstants.defaultPickupTime)!,
    );
    if (t != null && mounted) setState(() => _leavesAt = TripFormat.hhmm(t));
  }

  String? _text(TextEditingController t) => t.text.trim().isEmpty ? null : t.text.trim();

  Future<void> _save() async {
    if (!_phoneOk || _saving) return;
    final before = widget.beforeSave;
    if (before != null) {
      setState(() => _saving = true);
      final ok = await before();
      if (!mounted) return;
      setState(() => _saving = false);
      if (!ok) return;
    }
    final role = widget.role;
    if (role != null) {
      _c.markStepOwn(role,
          note: _text(_note), how: _how, ownName: _text(_name), ownPhone: _text(_phone), leavesAt: _leavesAt);
      Navigator.pop(context, true);
      return;
    }
    final k = widget.legIndex!;
    if (_c.plan.value?.legAt(k)?.arrival?.isJourney ?? false) {
      final impact = _c.travelImpact(k);
      if (impact.hasBooked && !await TravelConfirmSheet.replaceTravel(context, impact.bookedRows)) return;
      if (!mounted) return;
      setState(() => _saving = true);
      final removed = await _c.removeTravel(k, cancelBooked: impact.hasBooked);
      if (!mounted) return;
      setState(() => _saving = false);
      if (!removed) return;
    }
    final p = _c.plan.value;
    final prev = p?.legAt(k - 1)?.cityName ?? '';
    String? text(TextEditingController t) => _text(t);
    _c.setOwnTravel(
      k,
      TripTravel.own(
        fromName: prev,
        how: _how,
        ownName: text(_name),
        ownPhone: text(_phone),
        leavesAt: _leavesAt,
        roadMinutes: _roadMinutes,
        note: text(_note),
        hubName: _hubName,
      ),
    );
    _c.clearTravelGap(k);
    Navigator.pop(context, true);
  }

  InputDecoration _decoration(String label, {String? error, String? prefix}) => InputDecoration(
        labelText: label,
        counterText: '',
        errorText: error,
        prefixText: prefix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
      );

  Widget _roadOption(int minutes, String label) {
    final on = _roadMinutes == minutes;
    return Expanded(
      child: Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _roadMinutes = on ? null : minutes),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: on ? TripColors.surface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? TripColors.accent : AppColors.divider, width: on ? 1.5 : 1),
            ),
            child: Text(label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: on ? TripColors.accentDark : AppColors.textMedium)),
          ),
        ),
      ),
    );
  }

  Widget _roleSheet(TripStepRole role) => Obx(() => _roleSheetBody(role));

  Widget _roleSheetBody(TripStepRole role) {
    final going = role == TripStepRole.gettingThere;
    final start = _c.startFrom?.name ?? '';
    final city = going ? _c.cityName : _c.lastCityName;
    final date = _c.stepDate(role);
    final end = _c.homeEndName.isEmpty ? start : _c.homeEndName;
    final route = going ? TripStringsMcaA3.fromTo(start, city) : TripStringsMcaA3.fromTo(city, end);
    return TripSheetFrame(
      title: TripStringsMcaA3.yourOwnTravel,
      description: date == null ? route : '$route · ${TripFormat.shortDate(date)}',
      children: [
        if (!going) const TripGoingHomeRow(),
        ..._fields(
          editing: _c.stepOf(role).status == TripStepStatus.own,
          onRemove: () => _c.resetStep(role),
          roadTime: false,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    if (role != null) return _roleSheet(role);
    final k = widget.legIndex!;
    final p = _c.plan.value;
    final leg = p?.legAt(k);
    if (p == null || leg == null) {
      return const TripSheetFrame(title: TripStringsMcaA3.yourOwnTravel, children: [SizedBox(height: 24)]);
    }
    final prev = p.legAt(k - 1)?.cityName ?? '';
    final travelDay = p.legStart(k);
    final date = _c.dateOf(travelDay);
    final route = TripStringsMcaA3.fromTo(prev, leg.cityName);
    return TripSheetFrame(
      title: TripStringsMcaA3.yourOwnTravel,
      description: date == null ? route : '$route · ${TripFormat.shortDate(date)}',
      footer: Text(
        TripStringsMcaA3.roadTimeHelper(travelDay),
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, height: 1.35),
      ),
      children: _fields(editing: leg.arrival?.isOwn ?? false, onRemove: () => _c.clearTravel(k), roadTime: true),
    );
  }

  List<Widget> _fields({required bool editing, required VoidCallback onRemove, required bool roadTime}) => [
        _label(TripStringsMcaA3.how),
        TripFilterChips(
          accent: TripColors.accent,
          items: [
            for (final h in TripTravelHow.values)
              TripFilterChip(
                label: TripOwnTravelSheet.howLabel(h),
                selected: _how == h,
                onTap: () => setState(() => _how = _how == h ? null : h),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          maxLength: TripConstants.ownTravelNameMax,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.ownTravelNameMax)],
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _decoration(TripStringsMcaA3.nameOrNumber),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickTime,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: _decoration(TripStringsMcaA3.leavesAt),
            child: Row(
              children: [
                const Icon(Iconsax.clock, size: 16, color: TripColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _leavesAt == null ? TripStringsMcaA3.pickTime : TripFormat.time12(_leavesAt!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: _leavesAt == null ? AppColors.textHint : AppColors.textDark),
                  ),
                ),
                if (_leavesAt != null)
                  IconButton(
                    onPressed: () => setState(() => _leavesAt = null),
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textLight),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _decoration(
            TripStringsMcaA3.phoneOptional,
            prefix: '+91 ',
            error: !_phoneOk ? TripStringsMcaA3.phoneInvalid : null,
          ),
        ),
        if (roadTime) ...[
          const SizedBox(height: 14),
          _label(TripStringsMcaA3.roadTime),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _roadOption(TripConstants.travelHalfDayMinutes, TripStringsMcaA3.halfDay),
                const SizedBox(width: 8),
                _roadOption(TripConstants.travelWholeDayMinutes, TripStringsMcaA3.wholeDay),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLength: TripConstants.noteMax,
          minLines: 1,
          maxLines: 3,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.noteMax)],
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _decoration(TripStringsMcaA3.noteOptional),
        ),
        const SizedBox(height: 16),
        GradientButton(
          label: TripStringsMcaA3.saveTravel,
          height: 52,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
          onPressed: _phoneOk && !_saving ? _save : null,
        ),
        if (editing) ...[
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () {
                onRemove();
                Navigator.pop(context, true);
              },
              style: TextButton.styleFrom(minimumSize: const Size(88, 44)),
              child: const Text(TripStringsMcaA3.removeTravel,
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.error)),
            ),
          ),
        ],
      ];
}
