import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../buddy_error_types.dart';
import '../buddy_live.dart';
import '../expenses/data/expense_list_cache.dart';
import '../expenses/data/expense_write_gateway.dart';
import '../expenses/data/expenses_api.dart';
import '../expenses/models/expense_draft.dart';
import '../expenses/models/expense_models.dart';
import '../shared/models/person_models.dart';
import 'expense_op.dart';
import 'expense_queue_store.dart';
import 'queue_rules.dart';

abstract final class OfflineHooks {
  static Future<bool> Function(BuildContext context, PendingExpense pending) openEdit = _noEdit;
  static void Function(String tripId) onTripGone = _none;
  static Future<void> Function() logout = _noLogout;
  static List<MoneyPerson> Function(String tripId) travellers = _travellers;

  static Future<bool> _noEdit(BuildContext context, PendingExpense pending) async => false;
  static void _none(String tripId) {}
  static Future<void> _noLogout() async {}
  static List<MoneyPerson> _travellers(String tripId) => ExpenseListCache.read(tripId)?.travellers ?? const [];

  static void debugReset() {
    openEdit = _noEdit;
    onTripGone = _none;
    logout = _noLogout;
    travellers = _travellers;
  }
}

class ExpenseQueueService extends GetxService with WidgetsBindingObserver implements ExpensePendingSource {
  ExpenseQueueService({ExpenseQueueStore? store, this.onlineOverride, this.onlineChanges, this.isOnlineCheck, this.userSource})
      : store = store ?? ExpenseQueueStore();

  final ExpenseQueueStore store;
  final ExpenseWriteGateway? onlineOverride;
  final Stream<bool>? onlineChanges;
  final Future<bool> Function()? isOnlineCheck;
  final Rx<String?>? userSource;

  final RxList<ExpenseOp> ops = <ExpenseOp>[].obs;
  final RxBool offline = false.obs;
  final RxBool syncing = false.obs;
  final RxInt lost = 0.obs;
  final RxInt _version = 0.obs;

  String? _userId;
  Future<bool>? _syncing;
  Timer? _retry;
  StreamSubscription<bool>? _netSub;
  final List<Worker> _workers = [];
  late final Future<void> ready;

  static ExpenseQueueService? get maybe => Get.isRegistered<ExpenseQueueService>() ? Get.find<ExpenseQueueService>() : null;

  ExpenseWriteGateway get online => onlineOverride ?? OnlineExpenseGateway(api: Get.isRegistered<ExpensesApi>() ? Get.find<ExpensesApi>() : const ExpensesApi());

  String? get userId => _userId;

  @override
  RxInt get version => _version;

  int get count => ops.length;

  @override
  void onInit() {
    super.onInit();
    ready = _start();
  }

  Future<void> _start() async {
    try {
      await store.init();
    } catch (_) {}
    final source = userSource;
    if (source != null) {
      await _bind(source.value);
      _workers.add(ever<String?>(source, (id) => _bind(id)));
    }
    WidgetsBinding.instance.addObserver(this);
    _listenNet();
  }

  void _listenNet() {
    try {
      final changes = onlineChanges ?? Connectivity().onConnectivityChanged.map((r) => r.any((x) => x != ConnectivityResult.none));
      _netSub = changes.listen((on) {
        final was = offline.value;
        offline.value = !on;
        if (was && on) sync();
      }, onError: (_) {});
      final check = isOnlineCheck ?? () async => (await Connectivity().checkConnectivity()).any((x) => x != ConnectivityResult.none);
      check().then((on) => offline.value = !on).catchError((_) => false);
    } catch (_) {}
  }

  Future<void> _bind(String? id) async {
    if (id == _userId) return;
    _userId = id;
    _retry?.cancel();
    if (id == null) {
      ops.clear();
      lost.value = 0;
      _bump();
      return;
    }
    ops.assignAll(store.load(id));
    lost.value = store.lost(id);
    _bump();
    try {
      await store.touchAndPrune(id);
    } catch (_) {}
    if (ops.any((o) => o.waiting)) sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) sync();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _netSub?.cancel();
    for (final w in _workers) {
      w.dispose();
    }
    _retry?.cancel();
    super.onClose();
  }

  void _bump() => _version.value++;

  Future<void> _persist() async {
    final id = _userId;
    if (id == null) return;
    try {
      await store.save(id, ops.toList());
    } catch (_) {}
  }

  int _myShare(ExpenseWriteRequest body) {
    final me = _userId;
    if (me == null) return 0;
    if (body.shares.isNotEmpty) return body.shares.where((s) => s.userId == me).fold(0, (a, s) => a + s.share);
    if (!body.sharers.contains(me) || body.sharers.isEmpty) return 0;
    return body.amount ~/ body.sharers.length;
  }

  ExpenseItem _shownOf(ExpenseDraft d) =>
      d.shown ??
      ExpenseItem(
        id: d.expenseId,
        title: d.body.title,
        category: d.body.category,
        amount: d.body.amount,
        dayNumber: d.body.dayNumber,
        paidByUserId: d.body.paidByUserId,
        sharedBy: d.body.shares.isNotEmpty ? d.body.shares.length : d.body.sharers.length,
        myShare: _myShare(d.body),
        version: d.baseVersion,
        edited: !d.isCreate,
      );

  ExpenseQueued enqueueSave(ExpenseDraft draft) {
    final known = ops.firstWhereOrNull((o) => o.opId == draft.opId);
    if (known == null) {
      _add(ExpenseOp(
        opId: draft.opId,
        kind: draft.isCreate ? OpKind.create : OpKind.edit,
        tripId: draft.tripId,
        expenseId: draft.expenseId,
        baseVersion: draft.baseVersion,
        body: draft.body,
        paymentsAcknowledged: draft.body.paymentsAcknowledged,
        shown: _shownOf(draft),
        createdAt: DateTime.now().toUtc(),
      ));
    }
    return ExpenseQueued(opId: draft.opId);
  }

  ExpenseQueued enqueueDelete({
    required String tripId,
    required String expenseId,
    required int baseVersion,
    required String opId,
    bool paymentsAcknowledged = false,
    required ExpenseItem shown,
  }) {
    if (ops.every((o) => o.opId != opId)) {
      _add(ExpenseOp(
        opId: opId,
        kind: OpKind.delete,
        tripId: tripId,
        expenseId: expenseId,
        baseVersion: baseVersion,
        paymentsAcknowledged: paymentsAcknowledged,
        shown: shown,
        createdAt: DateTime.now().toUtc(),
      ));
    }
    return ExpenseQueued(opId: opId);
  }

  void _add(ExpenseOp op) {
    ops.add(op);
    _bump();
    _persist();
    if (!offline.value) sync();
  }

  Future<bool> sync() => _syncing ??= _run().whenComplete(() => _syncing = null);

  Future<bool> _run() async {
    final user = _userId;
    if (user == null) return ops.isEmpty;
    if (offline.value || !ops.any((o) => o.waiting)) return !ops.any((o) => o.waiting);
    syncing.value = true;
    final touched = <String>{};
    try {
      while (_userId == user) {
        final next = ops.firstWhereOrNull((o) => o.waiting);
        if (next == null) break;
        final out = await _send(next);
        if (_userId != user) return false;
        if (out.kind == OutcomeKind.retry) {
          final wait = out.retryAfterSeconds;
          if (wait != null) {
            _retry?.cancel();
            _retry = Timer(Duration(seconds: wait), sync);
          }
          break;
        }
        touched.add(next.tripId);
        switch (out.kind) {
          case OutcomeKind.done:
            ops.removeWhere((o) => o.opId == next.opId);
          case OutcomeKind.notSaved:
            final i = ops.indexWhere((o) => o.opId == next.opId);
            if (i >= 0) ops[i] = ops[i].copyWith(state: OpState.notSaved, failAction: out.action, attempts: next.attempts + 1);
          case OutcomeKind.tripGone:
            final n = ops.where((o) => o.tripId == next.tripId).length;
            ops.removeWhere((o) => o.tripId == next.tripId);
            lost.value += n;
            await store.addLost(user, n);
            OfflineHooks.onTripGone(next.tripId);
          case OutcomeKind.retry:
            break;
        }
        _bump();
        await _persist();
      }
    } finally {
      syncing.value = false;
      for (final t in touched) {
        BuddyLive.expenses(t).value++;
      }
    }
    return _userId == user && !ops.any((o) => o.waiting);
  }

  Future<QueueOutcome> _send(ExpenseOp op) async {
    ExpenseWriteOutcome r;
    try {
      final body = op.body;
      r = op.kind == OpKind.delete || body == null
          ? await online.delete(
              tripId: op.tripId,
              expenseId: op.expenseId,
              baseVersion: op.baseVersion,
              opId: op.opId,
              paymentsAcknowledged: op.paymentsAcknowledged,
              shown: op.shown,
            )
          : await online.save(ExpenseDraft(tripId: op.tripId, expenseId: op.expenseId, body: body, shown: op.shown));
    } catch (_) {
      return QueueOutcome.retry;
    }
    switch (r) {
      case ExpenseSaved() || ExpenseDeleted():
        return QueueOutcome.done;
      case ExpenseRefused(:final error):
        final o = QueueRules.outcome(op.kind, statusCode: error.statusCode, type: error.type, retryAfterSeconds: error.retryAfterSeconds);
        if (o.kind == OutcomeKind.notSaved) {
          final i = ops.indexWhere((x) => x.opId == op.opId);
          if (i >= 0) ops[i] = ops[i].copyWith(failType: error.type ?? '', failMessage: error.message);
        }
        return o;
      case ExpenseQueued() || ExpenseWriteFailed():
        return QueueOutcome.retry;
    }
  }

  ExpenseOp? byId(String opId) => ops.firstWhereOrNull((o) => o.opId == opId);

  Future<void> drop(String opId) async {
    final before = ops.length;
    ops.removeWhere((o) => o.opId == opId);
    if (ops.length == before) return;
    _bump();
    await _persist();
  }

  Future<void> refresh(String opId) async {
    final op = byId(opId);
    await drop(opId);
    if (op != null) BuddyLive.expenses(op.tripId).value++;
  }

  Future<void> clearLost() async {
    final id = _userId;
    lost.value = 0;
    if (id != null) await store.clearLost(id);
  }

  Future<void> clearAccount(String? id) async {
    if (id == null) return;
    if (id == _userId) {
      ops.clear();
      lost.value = 0;
      _bump();
    }
    await store.clear(id);
  }

  int storedCount(String? id) {
    if (id == null) return 0;
    if (id == _userId) return ops.length;
    return store.load(id).length;
  }

  ExpenseDraft? editDraft(ExpenseOp op) {
    final body = op.body;
    if (body == null) return null;
    final fresh = const Uuid().v4();
    final create = op.kind == OpKind.create;
    return ExpenseDraft(
      tripId: op.tripId,
      expenseId: create ? const Uuid().v4() : op.expenseId,
      body: body.copyWith(opId: fresh),
      shown: op.shown,
    );
  }

  PendingExpense toPending(ExpenseOp op) {
    final action = op.failAction;
    return PendingExpense(
      opId: op.opId,
      tripId: op.tripId,
      expenseId: op.expenseId,
      kind: QueueRules.pendingKind(op.kind),
      state: op.notSaved ? PendingState.notSaved : PendingState.waiting,
      shown: op.shown,
      draft: op.notSaved && action == OpAction.edit ? editDraft(op) : null,
      line: op.notSaved ? QueueRules.line(op, travellers: _needsNames(op) ? OfflineHooks.travellers(op.tripId) : const []) : null,
      action: op.notSaved && action != null ? QueueRules.pendingAction(action) : null,
    );
  }

  bool _needsNames(ExpenseOp op) => op.failType == BuddyErrorTypes.sharerNotTraveller || op.failType == BuddyErrorTypes.payerNotTraveller;

  @override
  List<PendingExpense> forTrip(String tripId) => [for (final o in ops) if (o.tripId == tripId) toPending(o)];

  List<ExpenseOp> opsOf(String tripId) => [for (final o in ops) if (o.tripId == tripId) o];
}
