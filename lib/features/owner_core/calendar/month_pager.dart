import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../json/owner_dates.dart';
import '../plan/plan_gate.dart';
import '../plan/soft_lock.dart';
import '../strings/owner_shared_strings.dart';
import 'models/calendar_models.dart';

class MonthPager extends StatelessWidget {
  const MonthPager({
    super.key,
    required this.month,
    required this.window,
    required this.today,
    required this.onMonth,
    this.onLockedNext,
  });

  final DateTime month;
  final CalendarWindow window;
  final DateTime today;
  final ValueChanged<DateTime> onMonth;
  final VoidCallback? onLockedNext;

  List<DateTime> get _months => window.months(today);

  @override
  Widget build(BuildContext context) {
    final months = _months;
    final current = OwnerDates.firstOfMonth(month);
    final index = months.indexWhere((m) => m.year == current.year && m.month == current.month);
    final canBack = index > 0;
    final canNext = index >= 0 && index < months.length - 1;
    final lockedNext = !canNext && window.locked && PlanGate.canUpgrade;
    final grey = Ink3D.hint;
    return Row(
      children: [
        IconButton(
          onPressed: canBack ? () => onMonth(months[index - 1]) : null,
          icon: Icon(Icons.chevron_left_rounded, size: DS.s(26), color: canBack ? Ink3D.title : grey),
        ),
        Expanded(
          child: Text(
            OwnerSharedStrings.monthTitle(current),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Ink3D.text(16, FontWeight.w700, Ink3D.title, letterSpacing: 0),
          ),
        ),
        SoftLock.arrow(
          locked: lockedNext,
          onLockedTap: onLockedNext,
          unlocked: IconButton(
            onPressed: canNext ? () => onMonth(months[index + 1]) : null,
            icon: Icon(Icons.chevron_right_rounded, size: DS.s(26), color: canNext ? Ink3D.title : grey),
          ),
        ),
      ],
    );
  }
}
