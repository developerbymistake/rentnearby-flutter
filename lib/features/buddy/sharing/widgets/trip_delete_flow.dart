import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../../utils/app_toast.dart';
import '../../../social/shared/post_removal.dart';
import '../../../trip/controllers/my_trips_controller.dart';
import '../../../trip/models/trip_model.dart';
import '../../../trip/models/trip_plan_model.dart';
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
import '../controllers/owner_sharing_controller.dart';
import '../models/sharing_models.dart';
import '../sharing_deps.dart';
import '../sharing_strings.dart';

abstract final class TripDeleteFlow {
  static bool _busy = false;

  @visibleForTesting
  static VoidCallback? debugOpenTrips;

  static Future<List<String>?> Function(String tripId) loadAsks = TripLifecycleActions.loadDeleteLines;

  @visibleForTesting
  static void debugReset() {
    _busy = false;
    debugOpenTrips = null;
    loadAsks = (_) async => const [];
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

  static Future<bool> startById(BuildContext context, String tripId) async {
    if (_busy) return false;
    _busy = true;
    try {
      final fetched = await OwnerSharingController.fetchSharing(tripId);
      if (!context.mounted) return false;
      if (fetched is! BuddyOk<TripSharingBlock?>) {
        SharingDeps.toastError(fetched);
        return false;
      }
      final sharing = fetched.value;
      if (usesPlainDelete(sharing)) return await _deletePlain(context, tripId);
      if (sharing!.expenses.openPayments > 0) {
        final r = await SharingDeps.ledger.balances(tripId);
        if (!context.mounted) return false;
        if (r is! BuddyOk<TripBalances>) {
          SharingDeps.toastError(r);
          return false;
        }
        final lines = openLinesOf(r.value);
        if (lines.isNotEmpty) {
          await settleFirst(context, tripId, lines);
          return false;
        }
      }
      return await confirm(context, tripId, leaveScreen: false);
    } finally {
      _busy = false;
    }
  }

  static ({int open, int stays, int taxis}) _openAsks(String tripId) {
    if (!Get.isRegistered<MyTripsController>()) return (open: 0, stays: 0, taxis: 0);
    final c = MyTripsController.to;
    final rows = [...c.active, ...c.past].firstWhereOrNull((t) => t.id == tripId)?.progress.rows ?? const <TripEasyRowModel>[];
    bool done(TripEasyRowModel r, TripEasyRowKind k) => (r.state == TripRowState.confirmed || r.state == TripRowState.booked) && r.key.kind == k;
    return (
      open: rows.fold<int>(0, (n, r) => n + r.askedCount),
      stays: rows.where((r) => done(r, TripEasyRowKind.stay)).length,
      taxis: rows.where((r) => done(r, TripEasyRowKind.taxi)).length,
    );
  }

  static Future<bool> _deletePlain(BuildContext context, String tripId) async {
    final asks = _openAsks(tripId);
    final named = await loadAsks(tripId);
    if (!context.mounted) return false;
    if (!await TripLifecycleActions.confirmDelete(context, open: asks.open, confirmed: asks.stays, confirmedTaxis: asks.taxis, named: named)) return false;
    if (Get.isRegistered<MyTripsController>()) {
      final done = await MyTripsController.to.delete(tripId);
      if (done) AppToast.success(SharingStrings.tripDeleted);
      return done;
    }
    final r = await SharingDeps.members.deleteTrip(tripId);
    if (r is BuddyOk<void>) {
      AppToast.success(SharingStrings.tripDeleted);
      return true;
    }
    if (r is BuddyRefused<void> && r.type == BuddyErrorTypes.tripHasOpenBalances && context.mounted) {
      await settleFirst(context, tripId, OpenPaymentLine.fromRefusal(r.data));
      return false;
    }
    if (PostRemovalBlock.fromResult(r) case final block?) {
      await PostRemovalNotice.show(context, tripId, block);
      return false;
    }
    SharingDeps.toastError(r);
    return false;
  }

  static Future<bool> confirm(BuildContext context, String tripId, {bool leaveScreen = true}) async {
    final result = await Dialog3D.show<_DeleteOutcome>(context, builder: (_) => _DeleteBox(tripId: tripId));
    if (!context.mounted || result == null) return false;
    switch (result) {
      case _Deleted():
        if (leaveScreen) (debugOpenTrips ?? TripNavigation.openTripsTab)();
        if (Get.isRegistered<MyTripsController>()) {
          leaveScreen ? MyTripsController.to.load() : MyTripsController.to.removeLocal(tripId);
        }
        AppToast.success(SharingStrings.tripDeleted);
        return true;
      case _OpenBalances(:final lines):
        await settleFirst(context, tripId, lines);
        return false;
      case _Blocked(:final block):
        await PostRemovalNotice.show(context, tripId, block);
        return false;
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

class _Blocked extends _DeleteOutcome {
  const _Blocked(this.block);

  final PostRemovalBlock block;
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
  List<String>? _asks;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadNames();
    _loadAsks();
  }

  Future<void> _loadAsks() async {
    final lines = await TripDeleteFlow.loadAsks(widget.tripId);
    if (!mounted) return;
    setState(() => _asks = lines ?? const []);
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
      case BuddyRefused<void>(:final type, :final data) when PostRemovalBlock.fromRefusal(type, data) != null:
        Navigator.of(context).pop(_Blocked(PostRemovalBlock.fromRefusal(type, data)!));
      default:
        SharingDeps.toastError(r);
    }
  }

  @override
  Widget build(BuildContext context) => BuddyConfirmBox.box(
        art: BuddyArt.warning,
        title: SharingStrings.deleteTitle,
        body: _names == null || _asks == null ? null : [SharingStrings.deleteBody(_names!), ..._asks!].join('\n'),
        cancelLabel: BuddySharedStrings.cancel,
        confirmLabel: SharingStrings.delete,
        confirmKind: ConfirmKind.danger,
        busy: _busy,
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _names == null || _asks == null ? null : _delete,
      );
}
