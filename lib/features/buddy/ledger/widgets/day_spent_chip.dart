import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../controllers/money_summary_controller.dart';
import '../ledger_deps.dart';
import '../ledger_strings.dart';

class DaySpentChip extends StatefulWidget {
  const DaySpentChip({super.key, required this.tripId, required this.day});

  final String tripId;
  final int day;

  static Key keyOf(int day) => ValueKey('day_spent_$day');

  @override
  State<DaySpentChip> createState() => _DaySpentChipState();
}

class _DaySpentChipState extends State<DaySpentChip> {
  MoneySummaryController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.tripId.isNotEmpty) _c = MoneySummaryController.acquire(widget.tripId);
  }

  @override
  void dispose() {
    if (_c != null) MoneySummaryController.release(widget.tripId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return const SizedBox.shrink();
    return Obx(() {
      final total = c.summary.value?.dayTotal(widget.day) ?? 0;
      if (total <= 0) return const SizedBox.shrink();
      final label = LedgerStrings.spent(total);
      return Tap3D(
        tapKey: DaySpentChip.keyOf(widget.day),
        onTap: () => LedgerDeps.openExpenses(widget.tripId, day: widget.day),
        label: label,
        exclude: true,
        child: Container(
          height: DS.s(28),
          padding: DS.sym(h: 10),
          decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(10)),
          child: Center(
            widthFactor: 1,
            child: Text(label, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w700, BuddyLook.roseEnd, letterSpacing: 0)),
          ),
        ),
      );
    });
  }
}
