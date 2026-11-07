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

class _Copy {
  static const String flight = 'Flight';
  static const String allOptional = 'All optional';
  static const String phoneHint = 'Needs a 10 digit number';
}

class TripOwnTravelSheet {
  static Future<bool> show(
    BuildContext context,
    int legIndex, {
    TripTravelHow? initialHow,
    String? hubName,
  }) async {
    final c = TripPlanController.to;
    if (legIndex < 2 || c.isReadOnly || c.plan.value?.legAt(legIndex) == null) return false;
    final ok = await TripSheetFrame.show<bool>(
      context,
      _OwnTravelBody(legIndex: legIndex, initialHow: initialHow, hubName: hubName),
    );
    return ok == true;
  }

  static Future<bool> showForRole(BuildContext context, TripStepRole role) async {
    final c = TripPlanController.to;
    if (c.isReadOnly || c.plan.value == null) return false;
    final ok = await TripSheetFrame.show<bool>(context, _OwnTravelBody(role: role));
    return ok == true;
  }

  static String howLabel(TripTravelHow how) => switch (how) {
        TripTravelHow.car => TripStringsMcaA3.car,
        TripTravelHow.bus => TripStringsMcaA3.bus,
        TripTravelHow.train => TripStringsMcaA3.train,
        TripTravelHow.flight => _Copy.flight,
        TripTravelHow.other => TripStringsMcaA3.other,
      };

  static IconData howIcon(TripTravelHow? how) => switch (how) {
        TripTravelHow.bus => Iconsax.bus,
        TripTravelHow.train => Iconsax.driving,
        TripTravelHow.car => Iconsax.car,
        TripTravelHow.flight => Iconsax.airplane,
        _ => Iconsax.routing,
      };
}

// One sheet for all journey roles: a city change (legIndex) or Getting there / Coming back (role).
class _OwnTravelBody extends StatefulWidget {
  const _OwnTravelBody({this.legIndex, this.role, this.initialHow, this.hubName});

  final int? legIndex;
  final TripStepRole? role;
  final TripTravelHow? initialHow;
  final String? hubName;

  @override
  State<_OwnTravelBody> createState() => _OwnTravelBodyState();
}

class _OwnTravelBodyState extends State<_OwnTravelBody> {
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

  bool get _phoneHint => _phone.text.trim().isNotEmpty && TripOwnPhone.normalise(_phone.text) == null;

  String? _text(TextEditingController t) => t.text.trim().isEmpty ? null : t.text.trim();

  Future<void> _save() async {
    if (_saving) return;
    final phone = TripOwnPhone.normalise(_phone.text);
    final role = widget.role;
    if (role != null) {
      _c.markStepOwn(role, note: _text(_note), how: _how, ownName: _text(_name), ownPhone: phone, leavesAt: _leavesAt);
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
    final prev = _c.plan.value?.legAt(k - 1)?.cityName ?? '';
    _c.setOwnTravel(
      k,
      TripTravel.own(
        fromName: prev,
        how: _how,
        ownName: _text(_name),
        ownPhone: phone,
        leavesAt: _leavesAt,
        roadMinutes: _roadMinutes ?? TripConstants.travelHalfDayMinutes,
        note: _text(_note),
        hubName: _hubName,
      ),
    );
    _c.clearTravelGap(k);
    Navigator.pop(context, true);
  }

  InputDecoration _decoration(String label, {String? helper, String? prefix}) => InputDecoration(
        labelText: label,
        counterText: '',
        helperText: helper,
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

  Widget _optionalLine() => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text(_Copy.allOptional,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
      );

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
        _optionalLine(),
        if (!going) const TripGoingHomeRow(),
        ..._fields(
          editing: _c.stepOf(role).status == TripStepStatus.own,
          onRemove: () => _c.resetStep(role),
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
    final date = _c.dateOf(p.legStart(k));
    final route = TripStringsMcaA3.fromTo(prev, leg.cityName);
    return TripSheetFrame(
      title: TripStringsMcaA3.yourOwnTravel,
      description: date == null ? route : '$route · ${TripFormat.shortDate(date)}',
      children: [
        _optionalLine(),
        ..._fields(editing: leg.arrival?.isOwn ?? false, onRemove: () => _c.clearTravel(k)),
      ],
    );
  }

  List<Widget> _fields({required bool editing, required VoidCallback onRemove}) => [
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
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          maxLength: 12,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _decoration(TripStringsMcaA3.phoneOptional, prefix: '+91 ', helper: _phoneHint ? _Copy.phoneHint : null),
        ),
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
          onPressed: _saving ? null : _save,
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
