import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/auth_controller.dart';
import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../shared/buddy_look.dart';
import '../shared/widgets/buddy_confirm_box.dart';
import 'expense_queue_service.dart';
import 'offline_strings.dart';

enum SyncBoxResult { closed, logOutAnyway, saved }

abstract final class LogoutGuard {
  static const Key syncNowKey = ValueKey('logout_guard_sync_now');
  static const Key anywayKey = ValueKey('logout_guard_anyway');
  static const Key logOutKey = ValueKey('logout_guard_log_out');
  static const Key cancelKey = ValueKey('logout_guard_cancel');

  static Future<bool> check(BuildContext context) async {
    final queue = ExpenseQueueService.maybe;
    if (queue == null || queue.count == 0) return true;
    final first = await Dialog3D.show<SyncBoxResult>(context, builder: (_) => SyncNowBox(queue: queue));
    if (first != SyncBoxResult.logOutAnyway || !context.mounted) return false;
    final ok = await Dialog3D.show<bool>(
      context,
      builder: (ctx) => LogOutAnywayBox(
        count: queue.count,
        onCancel: () => Navigator.of(ctx).pop(false),
        onLogOut: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (ok != true) return false;
    await queue.clearAccount(queue.userId);
    await OfflineHooks.logout();
    return false;
  }
}

class SyncNowBox extends StatefulWidget {
  const SyncNowBox({super.key, required this.queue});

  final ExpenseQueueService queue;

  @override
  State<SyncNowBox> createState() => _SyncNowBoxState();
}

class _SyncNowBoxState extends State<SyncNowBox> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _sync() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    await widget.queue.sync();
    if (!mounted) return;
    if (widget.queue.count == 0) {
      Navigator.of(context).pop(SyncBoxResult.saved);
      AppToast.success(OfflineStrings.expensesSaved);
      return;
    }
    setState(() {
      _busy = false;
      _failed = true;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: Obx(() {
          widget.queue.version.value;
          return Dialog3D(
            tone: BuddyLook.indigo,
            art: BuddyArt.antenna,
            title: OfflineStrings.notSavedTitle(widget.queue.count),
            content: _Lines(note: OfflineStrings.notSavedBody, danger: _failed ? OfflineStrings.couldNotSync : null),
            secondaryLabel: OfflineStrings.logOutAnyway,
            secondaryKey: LogoutGuard.anywayKey,
            onSecondary: _busy ? null : () => Navigator.of(context).pop(SyncBoxResult.logOutAnyway),
            primaryLabel: OfflineStrings.syncNow,
            primaryKey: LogoutGuard.syncNowKey,
            onPrimary: _busy ? null : _sync,
            primaryLoading: _busy,
            tight: true,
          );
        }),
      );
}

class LogOutAnywayBox extends StatelessWidget {
  const LogOutAnywayBox({super.key, required this.count, required this.onCancel, required this.onLogOut});

  static const double _pillHeight = 50;
  static const double _pillFont = 15;

  final int count;
  final VoidCallback onCancel;
  final VoidCallback onLogOut;

  @override
  Widget build(BuildContext context) => Dialog3D(
        tone: BuddyLook.danger,
        art: BuddyArt.warning,
        artDanger: true,
        title: OfflineStrings.logOutAnywayTitle,
        content: _Lines(reason: OfflineStrings.willBeLost(count), note: OfflineStrings.syncFirst),
        actionsHorizontal: true,
        actions: [
          WhitePillButton(key: LogoutGuard.cancelKey, tone: BuddyLook.indigo, label: OfflineStrings.cancel, onTap: onCancel, height: _pillHeight, fontSize: _pillFont),
          GradientPillButton(key: LogoutGuard.logOutKey, tone: BuddyLook.danger, label: OfflineStrings.logOut, onTap: onLogOut, height: _pillHeight, fontSize: _pillFont),
        ],
        tight: true,
      );
}

class _Lines extends StatelessWidget {
  const _Lines({this.reason, this.note, this.danger});

  final String? reason;
  final String? note;
  final String? danger;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reason != null)
            Container(
              padding: DS.sym(h: 16, v: 12),
              decoration: BoxDecoration(color: BuddyLook.reasonBg, borderRadius: DS.circular(16)),
              child: Text(reason!, style: Ink3D.text(13, FontWeight.w500, BuddyLook.dangerText, height: 1.5, letterSpacing: 0)),
            ),
          if (note != null)
            Padding(
              padding: EdgeInsets.only(top: DS.s(reason == null ? 0 : 8)),
              child: Text(note!, textAlign: TextAlign.center, style: Ink3D.text(13.5, FontWeight.w400, BuddyLook.subText, height: 1.5, letterSpacing: 0)),
            ),
          if (danger != null)
            Padding(
              padding: EdgeInsets.only(top: DS.s(8)),
              child: Text(danger!, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w600, BuddyLook.dangerText, height: 1.45, letterSpacing: 0)),
            ),
        ],
      );
}

abstract final class SessionEndedNotice {
  static const Key logInKey = ValueKey('session_ended_log_in');

  static Future<void> onLogout(LogoutReason reason, String? userId) async {
    final queue = ExpenseQueueService.maybe;
    if (queue == null || userId == null) return;
    switch (reason) {
      case LogoutReason.accountDeleted:
        await queue.clearAccount(userId);
      case LogoutReason.sessionExpired || LogoutReason.roleChanged || LogoutReason.accountSuspended:
        final n = queue.storedCount(userId);
        if (n == 0) return;
        final ctx = Get.overlayContext ?? Get.context;
        if (ctx == null || !ctx.mounted) return;
        await show(ctx, n);
      case LogoutReason.explicitLogout:
        break;
    }
  }

  static Future<void> show(BuildContext context, int count) => Dialog3D.show<void>(
        context,
        barrierDismissible: false,
        builder: (ctx) => SessionEndedBox(count: count, onLogIn: () => Navigator.of(ctx).pop()),
      );
}

class SessionEndedBox extends StatelessWidget {
  const SessionEndedBox({super.key, required this.count, required this.onLogIn});

  final int count;
  final VoidCallback onLogIn;

  @override
  Widget build(BuildContext context) => BuddyConfirmBox.box(
        art: BuddyArt.locked,
        title: OfflineStrings.logInAgain,
        content: _Lines(note: OfflineStrings.savedOnPhone(count)),
        confirmLabel: OfflineStrings.logIn,
        confirmKind: ConfirmKind.indigo,
        onConfirm: onLogIn,
      );
}
