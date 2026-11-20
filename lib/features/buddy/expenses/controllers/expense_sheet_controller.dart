import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../../utils/trip_expense_engine.dart';
import '../../buddy_error_types.dart';
import '../../buddy_limits.dart';
import '../../shared/buddy_json.dart';
import '../../shared/buddy_result.dart';
import '../../shared/models/person_models.dart';
import '../../shared/strings_shared.dart';
import '../data/expense_write_gateway.dart';
import '../data/expenses_api.dart';
import '../expense_deps.dart';
import '../expense_rules.dart';
import '../expense_strings.dart';
import '../models/expense_draft.dart';
import '../models/expense_models.dart';

class ExpenseSheetSetup {
  const ExpenseSheetSetup({
    required this.tripId,
    required this.travellers,
    this.links = const [],
    required this.dayCount,
    required this.dayToday,
    this.startDate,
    this.day,
    this.edit,
    this.suggestion,
  });

  factory ExpenseSheetSetup.fromList(ExpenseList l, {int? day, ExpenseDetail? edit, List<MoneyPerson> extra = const [], ExpenseSuggestion? suggestion}) {
    final known = l.travellers.map((p) => p.userId).toSet();
    return ExpenseSheetSetup(
      tripId: l.tripId,
      travellers: [...l.travellers, ...extra.where((p) => !known.contains(p.userId))],
      links: l.links,
      dayCount: l.dayCount,
      dayToday: l.dayToday,
      startDate: l.startDate,
      day: day,
      edit: edit,
      suggestion: suggestion,
    );
  }

  final String tripId;
  final List<MoneyPerson> travellers;
  final List<ExpenseLinkOption> links;
  final int dayCount;
  final int dayToday;
  final DateTime? startDate;
  final int? day;
  final ExpenseDetail? edit;
  final ExpenseSuggestion? suggestion;

  bool get isEdit => edit != null;
}

enum SheetSaveEnd { none, saved, queued, needsAck, closeFrozen, closeLimit }

class SplitRow {
  const SplitRow({required this.person, required this.ticked, required this.share, required this.locked, required this.former});

  final MoneyPerson person;
  final bool ticked;
  final int share;
  final bool locked;
  final bool former;
}

class ExpenseSheetController extends GetxController {
  ExpenseSheetController(this.setup, {this._api, this._gateway}) {
    _init();
  }

  static const String amountFocus = 'amount';
  static String customFocus(String userId) => 'c:$userId';

  final ExpenseSheetSetup setup;
  final ExpensesApi? _api;
  final ExpenseWriteGateway? _gateway;

  final TextEditingController titleCtl = TextEditingController();
  final TextEditingController noteCtl = TextEditingController();
  final RxString amountDigits = ''.obs;
  final RxString title = ''.obs;
  final Rx<String?> category = Rx<String?>(null);
  final RxInt day = 1.obs;
  final Rx<ExpenseLinkRef?> link = Rx<ExpenseLinkRef?>(null);
  final RxString payer = ''.obs;
  final RxString mode = SplitMode.all.obs;
  final RxSet<String> chosen = <String>{}.obs;
  final RxMap<String, String> customDigits = <String, String>{}.obs;
  final Rx<String?> focus = Rx<String?>(null);
  final RxBool padOpen = false.obs;
  final RxSet<ExpenseField> touched = <ExpenseField>{}.obs;
  final RxBool showAll = false.obs;
  final RxMap<ExpenseField, String> serverErrors = <ExpenseField, String>{}.obs;
  final Rx<String?> topError = Rx<String?>(null);
  final RxBool conflict = false.obs;
  final Rx<String?> typed = Rx<String?>(null);
  final RxBool saving = false.obs;
  final RxBool refreshing = false.obs;
  final Rx<String?> lastCustom = Rx<String?>(null);
  final RxList<MoneyPerson> people = <MoneyPerson>[].obs;

  late String expenseId;
  int baseVersion = 0;
  ExpenseDetail? _current;
  bool _idRetried = false;

  ExpensesApi get api => _api ?? ExpenseDeps.api;
  ExpenseWriteGateway get gateway => _gateway ?? ExpenseWriteGateway.to;

  bool get isEdit => setup.isEdit;
  int? get amount => ExpenseRules.parse(amountDigits.value);
  ExpenseDetail? get current => _current;

  List<String> get canonical => [for (final p in people) p.userId];

  String get meId {
    for (final p in people) {
      if (p.isMe) return p.userId;
    }
    return people.isEmpty ? '' : people.first.userId;
  }

  MoneyPerson? person(String id) {
    for (final p in people) {
      if (p.userId == id) return p;
    }
    return null;
  }

  Set<String> get _originalSharers => {for (final s in _current?.shares ?? const <ExpenseShare>[]) s.userId};

  bool _isCurrent(MoneyPerson p) => !p.isFormer && !p.isDeleted;

  bool lockedOut(MoneyPerson p) => !_isCurrent(p) && !_originalSharers.contains(p.userId);

  void _init() {
    people.assignAll(setup.travellers);
    final e = setup.edit;
    final s = setup.suggestion;
    if (e != null) {
      expenseId = e.id;
      _fill(e);
    } else {
      expenseId = const Uuid().v4();
      day.value = (setup.day ?? setup.dayToday).clamp(1, setup.dayCount < 1 ? 1 : setup.dayCount);
      payer.value = meId;
      if (s != null) {
        amountDigits.value = s.amount > 0 ? '${s.amount}' : '';
        _setTitle(s.name);
        category.value = ExpenseCategory.stay;
        link.value = ExpenseLinkRef(kind: s.kind, id: s.sourceId, label: s.name);
        day.value = s.day;
        focus.value = amountFocus;
      } else {
        focus.value = amountFocus;
        padOpen.value = true;
      }
    }
  }

  void _setTitle(String v) {
    titleCtl.text = v;
    title.value = v;
  }

  void _fill(ExpenseDetail e) {
    _current = e;
    baseVersion = e.version;
    amountDigits.value = '${e.amount}';
    _setTitle(e.title);
    category.value = e.category;
    day.value = e.dayNumber;
    link.value = e.link;
    payer.value = e.paidByUserId;
    mode.value = e.splitMode;
    chosen
      ..clear()
      ..addAll(e.shares.map((x) => x.userId));
    customDigits
      ..clear()
      ..addAll({for (final x in e.shares) x.userId: '${x.share}'});
    noteCtl.text = e.note ?? '';
    final known = people.map((p) => p.userId).toSet();
    for (final x in e.shares) {
      if (!known.contains(x.userId)) {
        people.add(MoneyPerson(userId: x.userId, name: BuddySharedStrings.someone, last4: '', initial: '?', isMe: false, status: MoneyPersonStatus.left));
      }
    }
  }

  @override
  void onClose() {
    titleCtl.dispose();
    noteCtl.dispose();
    super.onClose();
  }

  bool get hasTyped =>
      amountDigits.value.isNotEmpty || title.value.trim().isNotEmpty || category.value != null || noteCtl.text.trim().isNotEmpty;

  DateTime? dateOf(int d) => setup.startDate?.add(Duration(days: d - 1));

  String get subtitle {
    final l = link.value;
    if (!isEdit && l != null) return l.kind == ExpenseLinkKind.taxi ? ExpenseStrings.fromBookedTaxi : ExpenseStrings.fromBookedStay;
    return ExpenseStrings.dayDate(day.value, dateOf(day.value));
  }

  List<MoneyPerson> get currentPeople => people.where(_isCurrent).toList();

  List<MoneyPerson> get listPeople => [
        for (final p in people)
          if (_isCurrent(p) || (isEdit && !p.isDeleted) || _originalSharers.contains(p.userId)) p,
      ];

  List<String> get sharers => switch (mode.value) {
        SplitMode.chosen => [for (final p in people) if (chosen.contains(p.userId) && !lockedOut(p)) p.userId],
        SplitMode.custom => [for (final p in people) if ((ExpenseRules.parse(customDigits[p.userId] ?? '') ?? 0) > 0) p.userId],
        _ => [for (final p in currentPeople) p.userId],
      };

  ExpenseSplit? get equal {
    final a = amount;
    final s = sharers;
    if (a == null || a < 1 || s.isEmpty || s.length > BuddyLimits.maxSharers) return null;
    try {
      return TripExpenseEngine.equalSplit(a, canonical, s, payer.value);
    } on ArgumentError {
      return null;
    }
  }

  CustomSplitCheck get custom {
    final entries = [
      for (final p in listPeople)
        if (!lockedOut(p)) SplitShare(p.userId, ExpenseRules.parse(customDigits[p.userId] ?? '') ?? 0),
    ];
    return TripExpenseEngine.customSplit(amount ?? 0, canonical, entries);
  }

  int shareOf(String userId) {
    final e = equal;
    if (e == null) return 0;
    for (final s in e.shares) {
      if (s.userId == userId) return s.share;
    }
    return 0;
  }

  String? _clientError(ExpenseField f) => switch (f) {
        ExpenseField.amount => ExpenseRules.amountError(amount),
        ExpenseField.title => ExpenseRules.titleError(title.value),
        ExpenseField.category => ExpenseRules.categoryError(category.value),
        ExpenseField.sharers => mode.value == SplitMode.chosen ? ExpenseRules.sharersError(sharers.length) : null,
      };

  String? errorOf(ExpenseField f) {
    final client = _clientError(f);
    final shown = showAll.value || touched.contains(f);
    if (client != null) return shown ? client : null;
    return serverErrors[f];
  }

  bool get valid {
    for (final f in ExpenseField.values) {
      if (_clientError(f) != null) return false;
    }
    final n = sharers.length;
    if (n < 1 || n > BuddyLimits.maxSharers) return false;
    if (mode.value == SplitMode.custom && !custom.isValid) return false;
    return true;
  }

  void tapAmount() {
    focus.value = amountFocus;
    padOpen.value = true;
  }

  void tapCustom(String userId) {
    focus.value = customFocus(userId);
    lastCustom.value = userId;
    padOpen.value = true;
  }

  void blurPad() {
    padOpen.value = false;
    if (focus.value == amountFocus) touched.add(ExpenseField.amount);
  }

  void key(String k) {
    final f = focus.value;
    if (f == null) return;
    if (f == amountFocus) {
      amountDigits.value = k == AmountKeys.back ? ExpenseRules.popDigit(amountDigits.value) : ExpenseRules.pushDigit(amountDigits.value, k);
      touched.add(ExpenseField.amount);
      serverErrors.remove(ExpenseField.amount);
      return;
    }
    final id = f.substring(2);
    final cur = customDigits[id] ?? '';
    customDigits[id] = k == AmountKeys.back ? ExpenseRules.popDigit(cur) : ExpenseRules.pushDigit(cur, k);
    lastCustom.value = id;
    topError.value = null;
  }

  void onTitle(String v) {
    title.value = v;
    touched.add(ExpenseField.title);
    serverErrors.remove(ExpenseField.title);
  }

  void titleFocused() {
    padOpen.value = false;
    focus.value = null;
    if (amountDigits.value.isNotEmpty) touched.add(ExpenseField.amount);
  }

  void pickCategory(String c) {
    category.value = c;
    touched.add(ExpenseField.category);
    serverErrors.remove(ExpenseField.category);
  }

  void pickDay(int d) {
    day.value = d;
    link.value = null;
  }

  void pickLink(ExpenseLinkOption o) {
    link.value = ExpenseLinkRef(kind: o.kind, id: o.id, label: o.label);
    if (o.day != null) day.value = o.day!;
    topError.value = null;
  }

  void pickPayer(String id) => payer.value = id;

  void pickMode(String m) {
    if (m == mode.value) return;
    if (m == SplitMode.chosen && chosen.isEmpty && !touched.contains(ExpenseField.sharers)) {
      chosen.addAll(sharers.isEmpty ? currentPeople.map((p) => p.userId) : sharers);
    }
    if (m == SplitMode.custom && customDigits.values.every((v) => v.isEmpty)) {
      final e = equal;
      if (e != null) customDigits.addAll({for (final s in e.shares) s.userId: '${s.share}'});
    }
    mode.value = m;
    serverErrors.remove(ExpenseField.sharers);
  }

  void toggle(MoneyPerson p) {
    if (lockedOut(p)) return;
    touched.add(ExpenseField.sharers);
    if (!chosen.remove(p.userId)) chosen.add(p.userId);
  }

  List<SplitRow> get rows {
    final e = equal;
    int shareIn(String id) => e?.shares.where((s) => s.userId == id).fold<int>(0, (a, s) => a + s.share) ?? 0;
    return [
      for (final p in listPeople)
        SplitRow(person: p, ticked: chosen.contains(p.userId) && !lockedOut(p), share: shareIn(p.userId), locked: lockedOut(p), former: !_isCurrent(p)),
    ];
  }

  void attemptOnOff() {
    showAll.value = true;
    touched.addAll(ExpenseField.values);
  }

  ExpenseWriteRequest _body({required String opId, required bool ack}) {
    final isCustom = mode.value == SplitMode.custom;
    final note = noteCtl.text.trim();
    return ExpenseWriteRequest(
      opId: opId,
      baseVersion: baseVersion,
      amount: amount ?? 0,
      title: title.value.trim(),
      category: category.value ?? ExpenseCategory.other,
      dayNumber: day.value,
      link: link.value,
      paidByUserId: payer.value,
      splitMode: mode.value,
      sharers: isCustom ? const [] : sharers,
      shares: isCustom ? [for (final s in custom.shares) ExpenseShare(userId: s.userId, share: s.share)] : const [],
      note: note.isEmpty ? null : note,
      paymentsAcknowledged: ack,
    );
  }

  int get _myShare {
    if (mode.value == SplitMode.custom) {
      for (final s in custom.shares) {
        if (s.userId == meId) return s.share;
      }
      return 0;
    }
    return shareOf(meId);
  }

  ExpenseItem _shown() => ExpenseItem(
        id: expenseId,
        title: title.value.trim(),
        category: category.value ?? ExpenseCategory.other,
        amount: amount ?? 0,
        dayNumber: day.value,
        paidByUserId: payer.value,
        sharedBy: sharers.length,
        myShare: _myShare,
        version: baseVersion,
        edited: isEdit,
        linkKind: link.value?.kind,
        linkId: link.value?.id,
      );

  List<String> get ackNames {
    final e = _current;
    if (e == null) return const [];
    final after = mode.value == SplitMode.custom
        ? [for (final s in custom.shares) ExpenseShare(userId: s.userId, share: s.share)]
        : [for (final s in equal?.shares ?? const <SplitShare>[]) ExpenseShare(userId: s.userId, share: s.share)];
    return ExpenseRules.changedNames(
      people: people,
      before: e.shares,
      after: after,
      payerBefore: e.paidByUserId,
      payerAfter: payer.value,
      amountBefore: e.amount,
      amountAfter: amount ?? 0,
    );
  }

  Future<SheetSaveEnd> save({bool ack = false}) async {
    if (saving.value) return SheetSaveEnd.none;
    if (!valid) {
      attemptOnOff();
      return SheetSaveEnd.none;
    }
    padOpen.value = false;
    saving.value = true;
    topError.value = null;
    try {
      return await _send(ack: ack, opId: const Uuid().v4());
    } finally {
      if (!isClosed) saving.value = false;
    }
  }

  Future<SheetSaveEnd> _send({required bool ack, required String opId}) async {
    final draft = ExpenseDraft(tripId: setup.tripId, expenseId: expenseId, body: _body(opId: opId, ack: ack), shown: _shown());
    final out = await gateway.save(draft);
    if (isClosed) return SheetSaveEnd.none;
    switch (out) {
      case ExpenseSaved(:final expense):
        _current = expense;
        baseVersion = expense.version;
        return SheetSaveEnd.saved;
      case ExpenseQueued():
        return SheetSaveEnd.queued;
      case ExpenseDeleted():
        return SheetSaveEnd.saved;
      case ExpenseWriteFailed(:final isOffline):
        isOffline ? ExpenseDeps.offline() : ExpenseDeps.toast(BuddySharedStrings.somethingWrong);
        return SheetSaveEnd.none;
      case ExpenseRefused(:final error):
        return _refused(error, ack: ack);
    }
  }

  Future<SheetSaveEnd> _refused(BuddyRefused<Object?> e, {required bool ack}) async {
    if (e.rateLimited) {
      ExpenseDeps.toast(ExpenseStrings.tryAgainLater);
      return SheetSaveEnd.none;
    }
    final msg = e.message;
    switch (e.type) {
      case BuddyErrorTypes.paymentsNotAcknowledged:
        return SheetSaveEnd.needsAck;
      case BuddyErrorTypes.expenseVersionConflict:
        final cur = BuddyJson.mapOrNull(e.data['current']);
        if (cur != null) _conflictCurrent = ExpenseDetail.fromJson(cur);
        conflict.value = true;
        return SheetSaveEnd.none;
      case BuddyErrorTypes.expenseIdTaken:
        if (!isEdit && !_idRetried) {
          _idRetried = true;
          expenseId = const Uuid().v4();
          return _send(ack: ack, opId: const Uuid().v4());
        }
        topError.value = msg ?? BuddySharedStrings.somethingWrong;
      case BuddyErrorTypes.expenseLimitReached:
        return SheetSaveEnd.closeLimit;
      case BuddyErrorTypes.tripExpensesFrozen:
        return SheetSaveEnd.closeFrozen;
      case BuddyErrorTypes.invalidAmount:
        _server(ExpenseField.amount, msg ?? ExpenseStrings.errAmount);
      case BuddyErrorTypes.titleRequired:
        _server(ExpenseField.title, msg ?? ExpenseStrings.errTitle);
      case BuddyErrorTypes.invalidCategory:
        _server(ExpenseField.category, msg ?? ExpenseStrings.errCategory);
      case BuddyErrorTypes.noSharers:
        _server(ExpenseField.sharers, msg ?? ExpenseStrings.errSharers);
      case BuddyErrorTypes.invalidDay:
        topError.value = msg ?? ExpenseStrings.errDay;
      case BuddyErrorTypes.sharerNotTraveller || BuddyErrorTypes.payerNotTraveller:
        topError.value = ExpenseStrings.notOnTrip(_goneName(e));
        await _reloadTravellers();
      case BuddyErrorTypes.linkNotInTrip:
        link.value = null;
        topError.value = ExpenseStrings.linkNotInTrip;
      default:
        topError.value = msg ?? BuddySharedStrings.somethingWrong;
    }
    return SheetSaveEnd.none;
  }

  ExpenseDetail? _conflictCurrent;

  void _server(ExpenseField f, String text) {
    serverErrors[f] = text;
    touched.add(f);
  }

  String _goneName(BuddyRefused<Object?> e) {
    final id = BuddyJson.strOrNull(e.data['userId']);
    final named = BuddyJson.strOrNull(e.data['name']);
    if (named != null && named.isNotEmpty) return named;
    final p = id == null ? null : person(id);
    if (p != null) return p.name;
    for (final s in [payer.value, ...sharers]) {
      final x = person(s);
      if (x != null && x.isFormer) return x.name;
    }
    return BuddySharedStrings.someone;
  }

  Future<void> _reloadTravellers() async {
    final r = await api.list(setup.tripId, limit: 1);
    if (isClosed || r is! BuddyOk<ExpenseList>) return;
    final fresh = r.value.travellers;
    if (fresh.isEmpty) return;
    final known = fresh.map((p) => p.userId).toSet();
    people.assignAll([...fresh, ...people.where((p) => !known.contains(p.userId))]);
  }

  Future<void> refreshAfterConflict() async {
    if (refreshing.value) return;
    refreshing.value = true;
    try {
      final typedAmount = amount;
      final typedTitle = title.value.trim();
      var fresh = _conflictCurrent;
      if (fresh == null) {
        final r = await api.detail(setup.tripId, expenseId);
        if (isClosed) return;
        if (r is BuddyOk<ExpenseDetailPage>) {
          fresh = r.value.expense;
        } else if (r is BuddyOffline<ExpenseDetailPage>) {
          ExpenseDeps.offline();
          return;
        }
      }
      if (fresh == null) return;
      _conflictCurrent = null;
      _fill(fresh);
      typed.value = ExpenseStrings.typedLine(typedAmount, typedTitle);
      conflict.value = false;
      focus.value = amountFocus;
      padOpen.value = false;
    } finally {
      if (!isClosed) refreshing.value = false;
    }
  }
}

abstract final class AmountKeys {
  static const String back = '⌫';
  static const List<String> grid = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', back];
}
