import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/buddy_confirm_box.dart';
import '../../shared/widgets/small_pill.dart';
import '../controllers/expense_detail_controller.dart';
import '../expense_look.dart';
import '../expense_rules.dart';
import '../expense_strings.dart';
import 'expense_form_parts.dart';

class ExpenseDeleteDialog extends StatefulWidget {
  const ExpenseDeleteDialog({super.key, required this.c});

  static const Key deleteKey = ValueKey('expense_delete_confirm');
  static const Key cancelKey = ValueKey('expense_delete_cancel');
  static const Key refreshKey = ValueKey('expense_delete_refresh');

  final ExpenseDetailController c;

  static Future<DeleteEnd?> show(BuildContext context, ExpenseDetailController c) =>
      Dialog3D.show<DeleteEnd>(context, barrierDismissible: false, builder: (_) => ExpenseDeleteDialog(c: c));

  @override
  State<ExpenseDeleteDialog> createState() => _ExpenseDeleteDialogState();
}

class _ExpenseDeleteDialogState extends State<ExpenseDeleteDialog> {
  bool _payments = false;
  bool _conflict = false;
  bool _refreshing = false;

  ExpenseDetailController get c => widget.c;

  Future<void> _delete() async {
    final end = await c.delete(ack: _payments);
    if (!mounted) return;
    switch (end) {
      case DeleteEnd.needsAck:
        setState(() => _payments = true);
      case DeleteEnd.conflict:
        setState(() => _conflict = true);
      case DeleteEnd.none:
        return;
      default:
        Navigator.of(context).pop(end);
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await c.reload();
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _conflict = false;
    });
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final e = c.page.value?.expense;
        final busy = c.deleting.value;
        final extra = <Widget>[
          if (_payments)
            Container(
              padding: DS.sym(h: 16, v: 12),
              decoration: BoxDecoration(color: ExpenseLook.reasonBg, borderRadius: DS.circular(16)),
              child: Text(ExpenseStrings.deletePayments, style: Ink3D.text(13, FontWeight.w500, BuddyLook.dangerText, height: 1.5, letterSpacing: 0)),
            ),
          if (_conflict)
            ExpenseStrip(
              action: SmallPill(key: ExpenseDeleteDialog.refreshKey, label: ExpenseStrings.refresh, onTap: _refresh, kind: SmallPillKind.rose, busy: _refreshing),
              child: Text(ExpenseStrings.conflict, style: Ink3D.text(13, FontWeight.w700, BuddyLook.dangerText, height: 1.35, letterSpacing: 0)),
            ),
        ];
        final off = busy || _refreshing;
        return Dialog3D(
          tone: BuddyConfirmBox.toneOf(ConfirmKind.danger),
          art: ExpenseLook.warning,
          artDanger: true,
          tight: true,
          title: ExpenseStrings.deleteTitle,
          body: e == null ? null : ExpenseStrings.deleteBody(e.amount, ExpenseRules.shortTitle(e.title)),
          content: extra.isEmpty ? null : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: extra),
          secondaryKey: ExpenseDeleteDialog.cancelKey,
          secondaryLabel: ExpenseStrings.cancel,
          onSecondary: off ? null : () => Navigator.of(context).pop(),
          primaryKey: ExpenseDeleteDialog.deleteKey,
          primaryLabel: ExpenseStrings.delete,
          onPrimary: off || _conflict ? null : _delete,
          primaryLoading: busy,
        );
      });
}
