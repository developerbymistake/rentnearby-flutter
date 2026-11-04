import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_colors.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/gradient_button.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import 'trip_sheet_frame.dart';

class TripOwnBookingSheet {
  static Future<bool> show(BuildContext context, {required int day, TripStayChoice? existing}) async {
    final ok = await TripSheetFrame.show<bool>(context, _OwnBody(day: day, existing: existing));
    return ok == true;
  }
}

class _OwnBody extends StatefulWidget {
  const _OwnBody({required this.day, this.existing});

  final int day;
  final TripStayChoice? existing;

  @override
  State<_OwnBody> createState() => _OwnBodyState();
}

class _OwnBodyState extends State<_OwnBody> {
  static const _nameMax = 80;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.isOwn == true ? e!.name : '');
    _phone = TextEditingController(text: e?.ownPhone ?? '');
    _note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _valid {
    final phone = _phone.text.trim();
    return _name.text.trim().isNotEmpty && (phone.isEmpty || phone.length == 10);
  }

  void _save() {
    if (!_valid) return;
    TripPlanController.to.setOwnStay(widget.day, name: _name.text, phone: _phone.text, note: _note.text);
    Navigator.pop(context, true);
  }

  void _remove() {
    TripPlanController.to.clearOwnStay(widget.day);
    Navigator.pop(context, true);
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing?.isOwn == true;
    return TripSheetFrame(
      title: TripStrings.haveStay,
      footer: const Text(
        TripStrings.ownBookingFooter,
        style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, height: 1.35),
      ),
      children: [
        TextField(
          controller: _name,
          maxLength: _nameMax,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(_nameMax)],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _decoration(TripStrings.name),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _decoration(TripStrings.phoneOptional).copyWith(prefixText: '+91 '),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLength: TripConstants.noteMax,
          minLines: 1,
          maxLines: 3,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.noteMax)],
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _decoration(TripStrings.note),
        ),
        const SizedBox(height: 16),
        GradientButton(
          label: TripStrings.save,
          height: 52,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
          onPressed: _valid ? _save : null,
        ),
        if (editing) ...[
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: _remove,
              style: TextButton.styleFrom(minimumSize: const Size(88, 44)),
              child: const Text(TripStrings.remove,
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.error)),
            ),
          ),
        ],
      ],
    );
  }
}
