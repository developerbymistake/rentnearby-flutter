import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../../utils/app_toast.dart';
import '../../../trip/controllers/my_trips_controller.dart';
import '../../../trip/models/trip_model.dart';
import '../../../trip/trip_navigation.dart';
import '../../../trip/widgets/trip_lifecycle_actions.dart';
import '../../buddy_error_types.dart';
import '../../buddy_navigation.dart';
import '../../ledger/models/ledger_models.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/buddy_result.dart';
import '../../shared/models/person_models.dart';
import '../../shared/strings_shared.dart';
import '../../shared/widgets/buddy_confirm_box.dart';
import '../models/sharing_models.dart';
import '../sharing_deps.dart';
import '../sharing_strings.dart';

abstract final class TripDeleteFlow {
  static bool _busy = false;

  @visibleForTesting
  static VoidCallback? debugOpenTrips;

  @visibleForTesting
  static void debugReset() {
    _busy = false;
    debugOpenTrips = null;
  }

  static bool usesPlainDelete(TripSharingBlock? s) => s == null || (s.viewerCount == 0 && s.pendingInvites == 0 && !s.expenses.hasExpenses);

  static Future<void> start(BuildContext context, TripModel trip, TripSharingBlock? sharing) async {
    if (_busy) return;
    if (usesPlainDelete(sharing)) {
      await TripLifecycleActions.deleteFromPlan(context);
      return;
    }
    _busy = true;
    try {
      if (sharing!.expenses.openPayments > 0) {
        final r = await SharingDeps.ledger.balances(trip.id);
        if (!context.mounted) return;
        if (r is BuddyOk<TripBalances>) {
          final lines = openLinesOf(r.value);
          if (lines.isNotEmpty) {
            await settleFirst(context, trip.id, lines);
            return;
          }
        } else {
          SharingDeps.toastError(r);
          return;
        }
      }
      if (!context.mounted) return;
      await confirm(context, trip.id);
    } finally {
      _busy = false;
    }
  }

  static List<OpenPaymentLine> openLinesOf(TripBalances b) => [
        for (final p in b.payments)
          if (p.state != 'Received')
            OpenPaymentLine(
              from: b.person(p.fromUserId) ?? _unknown(p.fromUserId),
              to: b.person(p.toUserId) ?? _unknown(p.toUserId),
              amount: p.amount,
              state: p.state,
            ),
      ];

  static MoneyPerson _unknown(String id) =>
      MoneyPerson(userId: id, name: BuddySharedStrings.someone, last4: '', initial: '', isMe: false, status: MoneyPersonStatus.joined);

  static Future<void> settleFirst(BuildContext context, String tripId, List<OpenPaymentLine> lines) async {
    final open = await BuddyConfirmBox.ask(
      context,
      art: BuddyArt.moneyBag,
      title: SharingStrings.settleFirstTitle,
      body: SharingStrings.settleFirstBody,
      cancelLabel: SharingStrings.close,
      confirmLabel: SharingStrings.openExpenses,
      confirmKind: ConfirmKind.rose,
      content: OpenPaymentsBox(lines: lines),
    );
    if (open) BuddyNavigation.openExpenses(tripId, tab: 'balances');
  }

  static Future<void> confirm(BuildContext context, String tripId) async {
    final result = await Dialog3D.show<_DeleteOutcome>(context, builder: (_) => _DeleteBox(tripId: tripId));
    if (!context.mounted || result == null) return;
    switch (result) {
      case _Deleted():
        (debugOpenTrips ?? TripNavigation.openTripsTab)();
        if (Get.isRegistered<MyTripsController>()) MyTripsController.to.load();
        AppToast.success(SharingStrings.tripDeleted);
      case _OpenBalances(:final lines):
        await settleFirst(context, tripId, lines);
    }
  }
}

sealed class _DeleteOutcome {
  const _DeleteOutcome();
}

class _Deleted extends _DeleteOutcome {
  const _Deleted();
}

class _OpenBalances extends _DeleteOutcome {
  const _OpenBalances(this.lines);

  final List<OpenPaymentLine> lines;
}

class OpenPaymentsBox extends StatelessWidget {
  const OpenPaymentsBox({super.key, required this.lines});

  final List<OpenPaymentLine> lines;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('open_payments_box'),
        width: double.infinity,
        padding: DS.sym(h: 16, v: 12),
        decoration: BoxDecoration(color: BuddyLook.reasonBg, borderRadius: DS.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final l in lines)
              Text(
                SharingStrings.paysLine(BuddyFormat.moneyName(l.from), BuddyFormat.moneyName(l.to), BuddyFormat.rupees(l.amount)),
                style: Ink3D.text(13, FontWeight.w500, BuddyLook.dangerText, height: 1.5, letterSpacing: 0),
              ),
          ],
        ),
      );
}

class _DeleteBox extends StatefulWidget {
  const _DeleteBox({required this.tripId});

  final String tripId;

  @override
  State<_DeleteBox> createState() => _DeleteBoxState();
}

class _DeleteBoxState extends State<_DeleteBox> {
  List<String>? _names;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  Future<void> _loadNames() async {
    final r = await SharingDeps.members.members(widget.tripId);
    if (!mounted) return;
    setState(() => _names = r is BuddyOk<TripMembers> ? [for (final m in r.value.joined) if (!m.isOwner) m.name] : const []);
  }

  Future<void> _delete() async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await SharingDeps.members.deleteTrip(widget.tripId);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case BuddyOk<void>():
        Navigator.of(context).pop(const _Deleted());
      case BuddyRefused<void>(:final type, :final data) when type == BuddyErrorTypes.tripHasOpenBalances:
        Navigator.of(context).pop(_OpenBalances(OpenPaymentLine.fromRefusal(data)));
      default:
        SharingDeps.toastError(r);
    }
  }

  @override
  Widget build(BuildContext context) => BuddyConfirmBox.box(
        art: BuddyArt.warning,
        title: SharingStrings.deleteTitle,
        body: _names == null ? null : SharingStrings.deleteBody(_names!),
        cancelLabel: BuddySharedStrings.cancel,
        confirmLabel: SharingStrings.delete,
        confirmKind: ConfirmKind.danger,
        busy: _busy,
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _names == null ? null : _delete,
      );
}
