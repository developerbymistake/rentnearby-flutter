import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../widgets/pulse_once.dart';
import '../trip_colors.dart';
import '../trip_strings_wizard.dart';
import '../utils/trip_wizard_rules.dart';
import 'trip_step_dot.dart';

class TripStepRow extends StatelessWidget {
  final TripStepInfo info;
  final int number;
  final String title;
  final bool isNext;
  final bool readOnly;
  final VoidCallback? onTap;

  const TripStepRow({
    super.key,
    required this.info,
    required this.number,
    required this.title,
    this.isNext = false,
    this.readOnly = false,
    this.onTap,
  });

  static String trailingOf(TripStepInfo info, {required bool isNext}) => switch (info.state) {
        TripStepState.todo => isNext ? TripStringsWizard.start : '',
        TripStepState.waiting => info.needsYou ? TripStringsWizard.yourTurn : TripStringsWizard.seeReplies,
        TripStepState.attention => TripStringsWizard.fix,
        TripStepState.done || TripStepState.own || TripStepState.skipped => TripStringsWizard.edit,
      };

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final mark = TripStepMark.of(info.state);
    final current = isNext && !readOnly;
    final grey = info.state == TripStepState.own || info.state == TripStepState.skipped;
    final trailing = trailingOf(info, isNext: isNext);
    final tone = switch (info.state) {
      TripStepState.waiting => AppColors.warningText,
      TripStepState.attention => AppColors.errorText,
      TripStepState.done => AppColors.successText,
      _ => TripColors.accentDark,
    };
    Widget badge = mark.badge(
      number: '$number',
      pop: info.state == TripStepState.done,
      reduceMotion: reduceMotion,
    );
    if (current && info.state == TripStepState.todo) {
      badge = PulseOnce(key: ValueKey('next-${info.key.id}'), pulseCount: 1, child: badge);
    }
    return Opacity(
      opacity: readOnly ? 0.45 : 1,
      child: Semantics(
        button: onTap != null,
        label: '$title. ${info.line}',
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            constraints: const BoxConstraints(minHeight: 64),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: current
                    ? TripColors.accent
                    : (info.state == TripStepState.attention
                        ? TripStatusColors.failed.withValues(alpha: 0.5)
                        : AppColors.divider),
                width: current ? 1.5 : 1,
              ),
              boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                badge,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: grey ? AppColors.textMedium : AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        info.line,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: switch (info.state) {
                            TripStepState.waiting => AppColors.warningText,
                            TripStepState.attention => AppColors.errorText,
                            _ => AppColors.textLight,
                          },
                        ),
                      ),
                      if (info.note case final note? when note.isNotEmpty)
                        Text(
                          note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: info.state == TripStepState.todo ||
                                    info.state == TripStepState.own ||
                                    info.state == TripStepState.skipped
                                ? AppColors.textLight
                                : AppColors.warningText,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (current && info.state == TripStepState.todo)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: TripColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(trailing,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: TripColors.accentDark)),
                  )
                else if (trailing.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 96),
                    child: Text(trailing,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: tone)),
                  ),
                Icon(Icons.chevron_right_rounded, size: 20, color: current ? TripColors.accent : AppColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
