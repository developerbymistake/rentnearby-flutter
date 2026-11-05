import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/gradient_button.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_constants.dart';
import '../trip_strings_steps_a2.dart';
import 'trip_own_booking_sheet.dart';
import 'trip_sheet_frame.dart';

enum _SkipChoice { arranged, skip }

class TripStepSkipSheet {
  static Future<bool> show(BuildContext context, {required TripStepKind step}) async {
    if (!Get.isRegistered<TripPlanController>()) return false;
    final c = TripPlanController.to;
    if (c.plan.value == null || c.isReadOnly || step == TripStepKind.itinerary) return false;
    final role = switch (step) {
      TripStepKind.gettingThere => TripStepRole.gettingThere,
      TripStepKind.comingBack => TripStepRole.comingBack,
      _ => null,
    };
    final res = await TripSheetFrame.show<(_SkipChoice, String?)>(
      context,
      _SkipBody(withNote: role != null, initialNote: role == null ? null : c.stepOf(role).note),
    );
    if (res == null) return false;
    final (choice, note) = res;
    if (role != null) {
      if (choice == _SkipChoice.arranged) {
        c.markStepOwn(role, note: note);
      } else {
        c.skipStep(role);
      }
      return true;
    }
    if (choice == _SkipChoice.skip) {
      if (step == TripStepKind.stay) {
        c.skipRemainingNights();
      } else {
        c.skipRemainingTaxiDays();
      }
      return true;
    }
    if (!context.mounted) return false;
    final stay = step == TripStepKind.stay;
    final first = (stay ? c.stayStep.firstUnsorted : c.taxiStep.firstUnsorted) ?? 1;
    return TripOwnBookingSheet.show(context, day: first, kind: stay ? TripOwnKind.stay : TripOwnKind.taxi);
  }
}

class _SkipBody extends StatefulWidget {
  final bool withNote;
  final String? initialNote;

  const _SkipBody({required this.withNote, this.initialNote});

  @override
  State<_SkipBody> createState() => _SkipBodyState();
}

class _SkipBodyState extends State<_SkipBody> {
  late final TextEditingController _note = TextEditingController(text: widget.initialNote ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String? get _noteValue {
    final t = _note.text.trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    return TripSheetFrame(
      title: TripStringsStepsA2.arrangeTitle,
      description: TripStringsStepsA2.arrangeBody,
      children: [
        if (widget.withNote) ...[
          TextField(
            controller: _note,
            maxLength: TripConstants.noteMax,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.noteMax)],
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            decoration: InputDecoration(
              labelText: TripStringsStepsA2.noteOptional,
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
        ],
        GradientButton(
          label: TripStringsStepsA2.markArranged,
          height: 48,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
          onPressed: () => Navigator.pop(context, (_SkipChoice.arranged, _noteValue)),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, (_SkipChoice.skip, null)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            backgroundColor: Colors.white,
            side: BorderSide(color: TripColors.accentLight.withValues(alpha: 0.7), width: 1.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text(
            TripStringsStepsA2.skipForNow,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: TripColors.accentDark),
          ),
        ),
      ],
    );
  }
}
