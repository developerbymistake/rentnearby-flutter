import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../../../models/browse_item.dart';
import '../../../widgets/gradient_button.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_colors.dart';
import '../trip_strings_wizard.dart';
import '../utils/trip_clock.dart';
import '../utils/trip_format.dart';
import '../utils/trip_wizard_rules.dart';

class TripHeroCard extends StatelessWidget {
  final ValueChanged<String> onStep;
  final VoidCallback onWishlist;
  final VoidCallback onSummary;
  final VoidCallback onSeeAll;
  final String? pickUpKey;

  const TripHeroCard({
    super.key,
    required this.onStep,
    required this.onWishlist,
    required this.onSummary,
    required this.onSeeAll,
    this.pickUpKey,
  });

  String _datesLine(TripPlanController c) {
    final start = c.settings.startDate;
    final end = c.settings.endDate(c.dayCount);
    if (start == null || end == null) return TripStringsWizard.datesNotSet;
    final range = TripFormat.dateRange(start, end);
    final today = c.todayDay;
    if (today != null) return TripStringsWizard.todayDay(today);
    final left = TripClock.daysBetween(TripClock.today(), start);
    return left > 0 ? TripStringsWizard.startsIn(left, range) : range;
  }

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Obx(() {
      c.plan.value;
      c.trip.value;
      c.enquiryList.length;
      c.offline.value;
      final steps = c.wizardSteps;
      final p = TripWizardRules.progress(steps);
      final next = TripWizardRules.nextStep(steps);
      final cost = TripWizardRules.runningCost(steps);
      final readOnly = c.isReadOnly;
      final ready = p.total > 0 && p.counted == p.total && !readOnly;
      final remembered = pickUpKey == null ? null : steps.firstWhereOrNull((s) => s.key.id == pickUpKey);
      final pickUp = remembered != null && !remembered.counted && remembered.key != next?.key ? remembered : null;
      final accent = ready ? AppColors.success : TripColors.accent;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ready ? AppColors.successSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _ring(p.percent, accent, reduceMotion, c.offline.value),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ready ? TripStringsWizard.tripReady : c.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: ready ? AppColors.successText : AppColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _datesLine(c),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
                      ),
                      Text(
                        ready
                            ? (cost > 0 ? TripStringsWizard.aboutTotal(BrowseItem.inr(cost)) : TripStringsWizard.allSorted)
                            : TripStringsWizard.stepsLine(
                                p.counted, p.total, cost > 0 ? BrowseItem.inr(cost) : null),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (p.waitingForReply > 0 || p.needYou > 0) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (p.needYou > 0)
                    _badge(TripStringsWizard.needYou(p.needYou), AppColors.errorSurface, AppColors.errorText),
                  if (p.waitingForReply > 0)
                    _badge(TripStringsWizard.waitingForReply(p.waitingForReply), AppColors.warningSurface,
                        AppColors.warningText),
                ],
              ),
            ],
            if (pickUp != null && !ready && !readOnly) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => onStep(pickUp.key.id),
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 36),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      TripStringsWizard.pickUp(pickUp.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: TripColors.accentDark),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (readOnly)
              _outlined(TripStringsWizard.summary, onSummary)
            else if (ready)
              Row(
                children: [
                  Expanded(child: _outlined(TripStringsWizard.seeAll, onSeeAll)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GradientButton(
                      label: TripStringsWizard.shareSummary,
                      height: 48,
                      gradient: TripColors.gradient,
                      shadowColor: TripColors.accent,
                      onPressed: onSummary,
                    ),
                  ),
                ],
              )
            else if (next != null)
              GradientButton(
                label: p.decided == 0 ? TripStringsWizard.startNext(next.title) : TripStringsWizard.continueNext(next.title),
                height: 50,
                gradient: TripColors.gradient,
                shadowColor: TripColors.accent,
                onPressed: () => onStep(next.key.id),
              ),
          ],
        ),
      );
    });
  }

  Widget _ring(int percent, Color accent, bool reduceMotion, bool offline) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percent / 100),
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (_, value, _) => Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  strokeWidth: 6,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
                Center(
                  child: Text(
                    '${(value * 100).round()}%',
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (offline) ...[
          const SizedBox(height: 4),
          const Text(
            TripStringsWizard.offlineCopy,
            maxLines: 1,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textLight),
          ),
        ],
      ],
    );
  }

  Widget _badge(String text, Color bg, Color fg) => GestureDetector(
        onTap: onWishlist,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
            child: Text(text,
                maxLines: 1,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
          ),
        ),
      );

  Widget _outlined(String label, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          side: BorderSide(color: TripColors.accent.withValues(alpha: 0.6)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            maxLines: 1,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: TripColors.accentDark)),
      );
}
