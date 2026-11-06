import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../services/storage_service.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings_wizard.dart';
import '../utils/trip_wizard_rules.dart';

class TripMilestoneCard extends StatefulWidget {
  final ValueChanged<String> onStep;

  const TripMilestoneCard({super.key, required this.onStep});

  static List<String> reached(List<TripStepInfo> steps) {
    final p = TripWizardRules.progress(steps);
    final out = <String>[];
    final days = <int>{for (final s in steps) if (s.day != null) s.day!};
    for (final d in days.toList()..sort()) {
      final of = steps.where((s) => s.day == d).toList();
      if (of.isNotEmpty && of.every((s) => s.counted)) out.add('day:$d');
    }
    for (final m in const [25, 50, 75, 100]) {
      if (p.percent >= m) out.add('p:$m');
    }
    return out;
  }

  @override
  State<TripMilestoneCard> createState() => _TripMilestoneCardState();
}

class _TripMilestoneCardState extends State<TripMilestoneCard> {
  final _c = TripPlanController.to;
  Set<String> _seen = {};
  String? _tripId;

  void _load(String id) {
    if (_tripId == id) return;
    _tripId = id;
    _seen = StorageService.getTripMilestones(id).toSet();
  }

  void _dismiss(String id, List<String> reached) {
    setState(() => _seen = {..._seen, ...reached});
    for (final m in reached) {
      StorageService.addTripMilestone(id, m);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      _c.plan.value;
      _c.enquiryList.length;
      final trip = _c.trip.value;
      if (trip == null || _c.isReadOnly || _c.needsUpdate.value) return const SizedBox.shrink();
      _load(trip.id);
      final steps = _c.wizardSteps;
      final p = TripWizardRules.progress(steps);
      if (p.total == 0) return const SizedBox.shrink();
      if (p.decided == 0) return _c.spotCount > 0 ? _planReady(steps) : const SizedBox.shrink();
      final reached = TripMilestoneCard.reached(steps);
      final fresh = reached.where((m) => !_seen.contains(m)).toList();
      if (fresh.isEmpty) return const SizedBox.shrink();
      final dayDone = fresh.where((m) => m.startsWith('day:')).lastOrNull;
      final heading = dayDone != null
          ? TripStringsWizard.daySorted(int.parse(dayDone.substring(4)))
          : TripStringsWizard.percentHeading(p.percent);
      final sub = TripStringsWizard.percentLine(p.percent);
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _frame(
          icon: Iconsax.medal_star,
          heading: heading,
          sub: sub,
          trailing: IconButton(
            onPressed: () => _dismiss(trip.id, reached),
            tooltip: TripStringsWizard.close,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textLight),
          ),
        ),
      );
    });
  }

  Widget _planReady(List<TripStepInfo> steps) {
    final next = TripWizardRules.nextStep(steps);
    final canAdd = !_c.isReadOnly;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _frame(
        icon: Iconsax.task_square,
        heading: TripStringsWizard.planReady,
        sub: TripStringsWizard.planReadyLine(_c.spotCount, _c.dayCount),
        footer: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (canAdd)
              _link(TripStringsWizard.addAnotherCity, () => TripNavigation.addCity(context)),
            if (next != null) _link(TripStringsWizard.startNext(next.title), () => widget.onStep(next.key.id)),
          ],
        ),
      ),
    );
  }

  Widget _link(String label, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 6)),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TripColors.accentDark)),
      );

  Widget _frame({required IconData icon, required String heading, required String sub, Widget? trailing, Widget? footer}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
      decoration: BoxDecoration(
        color: TripColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TripColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 20, color: TripColors.accentDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(heading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    Text(sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          ?footer,
        ],
      ),
    );
  }
}
