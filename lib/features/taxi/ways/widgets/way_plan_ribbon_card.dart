import 'package:flutter/material.dart';
import '../models/taxi_ways_models.dart';
import 'way_plan_stack_card.dart';

class WayPlanRibbonCard extends StatelessWidget {
  final WayPlan plan;
  final int planIndex;
  final String? bestReason;
  final VoidCallback onOpen;
  final VoidCallback? onUse;
  final bool useBusy;
  final bool useNote;
  final VoidCallback? onAsk;
  final bool askBusy;

  const WayPlanRibbonCard({
    super.key,
    required this.plan,
    required this.planIndex,
    required this.onOpen,
    this.bestReason,
    this.onUse,
    this.useBusy = false,
    this.useNote = false,
    this.onAsk,
    this.askBusy = false,
  });

  @override
  Widget build(BuildContext context) => WayPlanStackCard(
        plan: plan,
        planIndex: planIndex,
        bestReason: bestReason,
        onOpen: onOpen,
        onUse: onUse,
        useBusy: useBusy,
        useNote: useNote,
        onAsk: onAsk,
        askBusy: askBusy,
      );
}
