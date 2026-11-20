import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/models/person_models.dart';
import '../../shared/widgets/section_label.dart';
import '../data/expense_write_gateway.dart';
import '../expense_look.dart';
import '../expense_rules.dart';
import '../models/expense_models.dart';
import 'expense_form_parts.dart';
import 'expense_row.dart';

typedef PendingExtras = Widget? Function(BuildContext context, PendingExpense pending);

class ExpenseDayList extends StatelessWidget {
  const ExpenseDayList({
    super.key,
    required this.days,
    required this.items,
    required this.travellers,
    required this.callerIsOwner,
    this.fold = false,
    this.expanded = false,
    this.onShowAll,
    this.onTap,
    this.pending = const [],
    this.rowExtras,
    this.startDate,
  });

  static const Key showAllKey = ValueKey('expense_show_all');

  final List<ExpenseDayTotal> days;
  final List<ExpenseItem> items;
  final List<MoneyPerson> travellers;
  final bool callerIsOwner;
  final bool fold;
  final bool expanded;
  final VoidCallback? onShowAll;
  final ValueChanged<ExpenseItem>? onTap;
  final List<PendingExpense> pending;
  final PendingExtras? rowExtras;
  final DateTime? startDate;

  @override
  Widget build(BuildContext context) {
    final byId = <String, PendingExpense>{for (final p in pending) p.expenseId: p};
    final rows = <({ExpenseItem item, PendingExpense? pending})>[
      for (final i in items) (item: byId[i.id]?.kind == PendingKind.edit ? byId[i.id]!.shown : i, pending: byId[i.id]),
      for (final p in pending)
        if (p.kind == PendingKind.create && !items.any((i) => i.id == p.expenseId)) (item: p.shown, pending: p),
    ];
    final perDay = <int, List<({ExpenseItem item, PendingExpense? pending})>>{};
    for (final r in rows) {
      perDay.putIfAbsent(r.item.dayNumber, () => []).add(r);
    }
    final dayInfo = {for (final d in days) d.day: d};
    final extraTotal = <int, int>{};
    for (final p in pending) {
      if (p.kind == PendingKind.create && !items.any((i) => i.id == p.expenseId)) {
        extraTotal[p.shown.dayNumber] = (extraTotal[p.shown.dayNumber] ?? 0) + p.shown.amount;
      }
    }
    final f = ExpenseFold.of(days: days, rowsPerDay: {for (final e in perDay.entries) e.key: e.value.length}, fold: fold && !expanded);
    final children = <Widget>[];
    for (final d in f.shownDays) {
      final list = perDay[d];
      if (list == null || list.isEmpty) continue;
      final info = dayInfo[d];
      final total = info == null ? list.fold<int>(0, (a, r) => a + r.item.amount) : info.total + (extraTotal[d] ?? 0);
      final start = startDate;
      final date = info?.date ?? (start == null ? null : DateTime(start.year, start.month, start.day + d - 1));
      children.add(SectionLabel(BuddyFormat.dayHeader(d, date), trailing: BuddyFormat.rupees(total), padding: DS.insets(l: 22, t: 16, r: 22)));
      children.add(Container(
        margin: DS.insets(l: 18, t: 8, r: 18),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: ExpenseShape.corner(28), boxShadow: ExpenseShape.card()),
        child: Column(
          children: [
            for (var i = 0; i < list.length; i++)
              ExpenseRow(
                item: list[i].item,
                first: i == 0,
                payerLabel: ExpenseRules.payerLabel(payerId: list[i].item.paidByUserId, travellers: travellers, callerIsOwner: callerIsOwner),
                onTap: onTap == null ? null : () => onTap!(list[i].item),
                extras: list[i].pending == null || rowExtras == null ? null : rowExtras!(context, list[i].pending!),
              ),
          ],
        ),
      ));
    }
    if (f.folded) {
      children.add(Tap3D(
        tapKey: showAllKey,
        onTap: onShowAll,
        label: f.linkText,
        exclude: true,
        child: Padding(
          padding: DS.insets(l: 18, t: 12, r: 18),
          child: CustomPaint(
            painter: _DashedBox(color: ExpenseLook.roseDash, radius: DS.s(12), width: DS.s(2), dash: DS.s(5)),
            child: Container(
              constraints: BoxConstraints(minHeight: DS.s(44)),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: ExpenseLook.roseFill, borderRadius: DS.circular(12)),
              child: Text(f.linkText, style: Ink3D.text(12.5, FontWeight.w700, BuddyLook.roseEnd, letterSpacing: 0)),
            ),
          ),
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

class _DashedBox extends CustomPainter {
  const _DashedBox({required this.color, required this.radius, required this.width, required this.dash});

  final Color color;
  final double radius;
  final double width;
  final double dash;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + dash), paint);
        d += dash * 2;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBox old) => old.color != color || old.radius != radius;
}
