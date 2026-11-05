import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/gradient_button.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_constants.dart';
import '../trip_strings_mca_a3.dart';
import '../utils/trip_format.dart';
import 'trip_filter_chips.dart';
import 'trip_sheet_frame.dart';

class TripOwnTravelSheet {
  static Future<bool> show(BuildContext context, int legIndex) async {
    final c = TripPlanController.to;
    if (legIndex < 2 || c.isReadOnly || c.plan.value?.legAt(legIndex) == null) return false;
    final ok = await TripSheetFrame.show<bool>(context, _OwnTravelBody(legIndex: legIndex));
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

class _OwnTravelBody extends StatefulWidget {
  const _OwnTravelBody({required this.legIndex});

  final int legIndex;

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

  @override
  void initState() {
    super.initState();
    final a = _c.plan.value?.legAt(widget.legIndex)?.arrival;
    _how = a?.how;
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

  void _save() {
    if (!_phoneOk) return;
    final p = _c.plan.value;
    final prev = p?.legAt(widget.legIndex - 1)?.cityName ?? '';
    String? text(TextEditingController t) => t.text.trim().isEmpty ? null : t.text.trim();
    _c.setOwnTravel(
      widget.legIndex,
      TripTravel.own(
        fromName: prev,
        how: _how,
        ownName: text(_name),
        ownPhone: text(_phone),
        leavesAt: _leavesAt,
        roadMinutes: _roadMinutes,
        note: text(_note),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final p = _c.plan.value;
    final leg = p?.legAt(widget.legIndex);
    if (p == null || leg == null) {
      return const TripSheetFrame(title: TripStringsMcaA3.yourOwnTravel, children: [SizedBox(height: 24)]);
    }
    final prev = p.legAt(widget.legIndex - 1)?.cityName ?? '';
    final travelDay = p.legStart(widget.legIndex);
    final date = _c.dateOf(travelDay);
    final route = TripStringsMcaA3.fromTo(prev, leg.cityName);
    final editing = leg.arrival != null;
    return TripSheetFrame(
      title: TripStringsMcaA3.yourOwnTravel,
      description: date == null ? route : '$route · ${TripFormat.shortDate(date)}',
      footer: Text(
        TripStringsMcaA3.roadTimeHelper(travelDay),
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, height: 1.35),
      ),
      children: [
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
            error: _phone.text.length == 10 && !_phoneOk ? TripStringsMcaA3.phoneInvalid : null,
          ),
        ),
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
          onPressed: _phoneOk ? _save : null,
        ),
        if (editing) ...[
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () {
                _c.clearTravel(widget.legIndex);
                Navigator.pop(context, true);
              },
              style: TextButton.styleFrom(minimumSize: const Size(88, 44)),
              child: const Text(TripStringsMcaA3.removeTravel,
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.error)),
            ),
          ),
        ],
      ],
    );
  }
}
