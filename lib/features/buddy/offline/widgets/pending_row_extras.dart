import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../../utils/app_toast.dart';
import '../../expenses/data/expense_write_gateway.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/buddy_badge.dart';
import '../../shared/widgets/small_pill.dart';
import '../expense_queue_service.dart';
import '../offline_strings.dart';

abstract final class PendingRowExtras {
  static Key actionKey(String opId) => ValueKey('pending_action_$opId');

  static Widget tag(PendingExpense pending) => pending.state == PendingState.waiting
      ? const BuddyBadge(OfflineStrings.waitingToSync, tone: BuddyBadgeTone.pending)
      : const BuddyBadge(OfflineStrings.notSaved, tone: BuddyBadgeTone.danger);

  static void onTap(BuildContext context, PendingExpense pending) {
    if (pending.state == PendingState.waiting) AppToast.info(OfflineStrings.waitingToSync);
  }

  static String label(PendingAction a) => switch (a) {
        PendingAction.refresh => OfflineStrings.refresh,
        PendingAction.edit => OfflineStrings.edit,
        PendingAction.remove => OfflineStrings.remove,
      };

  static Future<void> act(BuildContext context, PendingExpense pending) async {
    final queue = ExpenseQueueService.maybe;
    final action = pending.action;
    if (queue == null || action == null) return;
    switch (action) {
      case PendingAction.refresh:
        await queue.refresh(pending.opId);
      case PendingAction.remove:
        await queue.drop(pending.opId);
      case PendingAction.edit:
        if (await OfflineHooks.openEdit(context, pending)) await queue.refresh(pending.opId);
    }
  }

  static Widget? of(BuildContext context, PendingExpense pending) {
    final line = pending.line;
    final action = pending.action;
    final notSaved = pending.state == PendingState.notSaved && line != null && action != null;
    return Padding(
      padding: DS.insets(l: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(padding: DS.insets(t: 3), child: tag(pending)),
          if (notSaved) _NotSavedLine(line: line, label: label(action), buttonKey: actionKey(pending.opId), onTap: () => act(context, pending)),
        ],
      ),
    );
  }
}

class _NotSavedLine extends StatefulWidget {
  const _NotSavedLine({required this.line, required this.label, required this.buttonKey, required this.onTap});

  final String line;
  final String label;
  final Key buttonKey;
  final Future<void> Function() onTap;

  @override
  State<_NotSavedLine> createState() => _NotSavedLineState();
}

class _NotSavedLineState extends State<_NotSavedLine> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onTap();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.insets(t: 6),
        child: Row(
          children: [
            Expanded(child: Text(widget.line, style: Ink3D.text(12, FontWeight.w600, BuddyLook.dangerText, height: 1.35, letterSpacing: 0))),
            Gap.h(10),
            SmallPill(key: widget.buttonKey, label: widget.label, onTap: _tap, kind: SmallPillKind.dangerOutline, busy: _busy),
          ],
        ),
      );
}
