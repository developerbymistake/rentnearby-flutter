import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../controllers/trip_plan_controller.dart';
import '../../controllers/trip_plan_guide.dart';
import '../../models/trip_plan_model.dart';
import '../../utils/trip_guide_rules.dart';
import '../../trip_navigation.dart';
import '../../trip_strings_guide.dart';
import '../trip_sheet_frame.dart';
import '../trip_ui.dart';

class TripGuideOverviewSheet extends StatelessWidget {
  const TripGuideOverviewSheet({super.key, required this.controller});

  final TripPlanController controller;

  static Future<void> show(BuildContext context, TripPlanController c) =>
      TripSheetFrame.show<void>(context, TripGuideOverviewSheet(controller: c));

  static ({String label, Color color}) statusOf(TripGuideChoice? choice, TripRowState? row) {
    if (choice == TripGuideChoice.skip || row == TripRowState.skipped) {
      return (label: TripStringsGuide.statusSkipped, color: DesignColors.statusSkipped);
    }
    if (choice == TripGuideChoice.own || row == TripRowState.own) {
      return (label: TripStringsGuide.statusOwn, color: DesignColors.statusOwn);
    }
    if (row != null && row.isDone) return (label: TripStringsGuide.statusDone, color: DesignColors.statusBooked);
    if (row == TripRowState.offer || row == TripRowState.asked || choice == TripGuideChoice.find) {
      return (label: TripStringsGuide.statusLooking, color: DesignColors.statusOffer);
    }
    return (label: TripStringsGuide.statusToDo, color: DesignColors.statusTodo);
  }

  @override
  Widget build(BuildContext context) {
    final g = controller.guideState;
    final steps = List<TripGuideStep>.of(g.steps);
    return TripSheetFrame(
      title: TripStringsGuide.overviewTitle,
      description: TripStringsGuide.percent(g.percent.value),
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _Row(
            step: steps[i],
            status: statusOf(g.choices[steps[i].key], controller.easyRowOf(steps[i].row)?.state),
            current: i == g.index.value,
            onTap: () {
              Navigator.pop(context);
              controller.guideJumpTo(steps[i].key, persist: true);
            },
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        TripButton(
          label: TripStringsGuide.openSummary,
          outlined: true,
          onPressed: () {
            final id = controller.trip.value?.id;
            Navigator.pop(context);
            if (id != null) TripNavigation.openSummary(id);
          },
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.step, required this.status, required this.current, required this.onTap});

  final TripGuideStep step;
  final ({String label, Color color}) status;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const tone = KitTone.trip;
    final asset = switch (step.row.kind) {
      TripEasyRowKind.stay => TravelIcon.stay,
      TripEasyRowKind.taxi => TravelIcon.route,
      _ => TravelIcon.taxi,
    };
    return TripSurface(
      key: ValueKey('overview-${step.key}'),
      onTap: onTap,
      color: current ? tone.tint : DesignColors.surface,
      borderColor: current ? tone.accentDark : DesignColors.borderSoft,
      shadow: const [],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          children: [
            TravelIcon(asset, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(step.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TypeTokens.style(14, FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: DecoratedBox(
                decoration: BoxDecoration(color: DesignColors.tint(status.color, Alpha.tint), borderRadius: CardRadius.pill),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(status.label,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.style(12, FontWeight.w700, color: DesignColors.textPrimary)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
