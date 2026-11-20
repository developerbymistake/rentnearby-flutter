import '../buddy_limits.dart';
import '../shared/buddy_format.dart';
import '../shared/models/person_models.dart';
import 'expense_strings.dart';
import 'models/expense_models.dart';

enum ExpenseField { amount, title, category, sharers }

abstract final class ExpenseRules {
  static const int maxDigits = 6;
  static const int shortTitleMax = 24;

  static String? amountError(int? amount) {
    if (amount == null || amount < 1) return ExpenseStrings.errAmount;
    if (amount > BuddyLimits.maxAmount) return ExpenseStrings.errAmountMax;
    return null;
  }

  static String? titleError(String title) => title.trim().isEmpty ? ExpenseStrings.errTitle : null;

  static String? categoryError(String? category) => category == null || !ExpenseCategory.all.contains(category) ? ExpenseStrings.errCategory : null;

  static String? sharersError(int count) => count < 1 ? ExpenseStrings.errSharers : null;

  static String pushDigit(String digits, String d) {
    if (digits.length >= maxDigits) return digits;
    if (digits.isEmpty && d == '0') return digits;
    return digits + d;
  }

  static String popDigit(String digits) => digits.isEmpty ? digits : digits.substring(0, digits.length - 1);

  static int? parse(String digits) => digits.isEmpty ? null : int.tryParse(digits);

  static String shortTitle(String title) {
    final t = title.trim();
    if (t.length <= shortTitleMax) return t;
    final head = t.substring(0, shortTitleMax);
    final comma = head.lastIndexOf(',');
    if (comma > 0) return head.substring(0, comma).trim();
    final space = head.lastIndexOf(' ');
    return (space > 0 ? head.substring(0, space) : head).trim();
  }

  static String payerLabel({required String payerId, required List<MoneyPerson> travellers, required bool callerIsOwner}) {
    MoneyPerson? payer;
    for (final p in travellers) {
      if (p.userId == payerId) payer = p;
    }
    if (payer == null) return BuddyFormat.deletedName;
    if (payer.isMe && !callerIsOwner) return ExpenseStrings.paidByYou;
    if (payer.isDeleted) return ExpenseStrings.paidBy(BuddyFormat.deletedName);
    final twin = travellers.where((p) => p.userId != payer!.userId && p.name == payer.name).isNotEmpty;
    return ExpenseStrings.paidBy(twin ? BuddyFormat.moneyName(payer) : payer.name);
  }

  static List<String> changedNames({
    required List<MoneyPerson> people,
    required List<ExpenseShare> before,
    required List<ExpenseShare> after,
    required String payerBefore,
    required String payerAfter,
    required int amountBefore,
    required int amountAfter,
  }) {
    int shareIn(List<ExpenseShare> list, String id) => list.where((s) => s.userId == id).fold(0, (a, s) => a + s.share);
    final out = <String>[];
    for (final p in people) {
      if (p.isMe) continue;
      final paidBefore = p.userId == payerBefore ? amountBefore : 0;
      final paidAfter = p.userId == payerAfter ? amountAfter : 0;
      if (shareIn(before, p.userId) != shareIn(after, p.userId) || paidBefore != paidAfter) out.add(p.name);
    }
    return out;
  }
}

class ExpenseFold {
  const ExpenseFold({required this.shownDays, required this.hiddenDays, required this.hiddenTotal});

  final List<int> shownDays;
  final List<int> hiddenDays;
  final int hiddenTotal;

  bool get folded => hiddenDays.isNotEmpty;

  static const int minRows = 3;

  static ExpenseFold of({required List<ExpenseDayTotal> days, required Map<int, int> rowsPerDay, required bool fold}) {
    final all = <int>{...days.where((d) => d.count > 0).map((d) => d.day), ...rowsPerDay.keys}.toList()..sort((a, b) => b.compareTo(a));
    if (!fold) return ExpenseFold(shownDays: all, hiddenDays: const [], hiddenTotal: 0);
    final shown = <int>[];
    var rows = 0;
    for (final d in all) {
      if (rows >= minRows) break;
      final n = rowsPerDay[d] ?? 0;
      if (n == 0) break;
      shown.add(d);
      rows += n;
    }
    final hidden = all.where((d) => !shown.contains(d)).toList();
    final total = days.where((d) => hidden.contains(d.day)).fold(0, (a, d) => a + d.total);
    return ExpenseFold(shownDays: shown, hiddenDays: hidden, hiddenTotal: total);
  }

  String get linkText {
    if (hiddenDays.isEmpty) return '';
    if (hiddenDays.length == 1) return ExpenseStrings.showOneDay(hiddenDays.first, hiddenTotal);
    if (hiddenDays.length == 2) return ExpenseStrings.showTwoDays(hiddenDays.first, hiddenDays.last, hiddenTotal);
    return ExpenseStrings.showDayRange(hiddenDays.first, hiddenDays.last, hiddenTotal);
  }
}

class ExpenseHistoryText {
  const ExpenseHistoryText({required this.time, required this.sentence, this.detail, this.emphasis});

  final String time;
  final String sentence;
  final String? detail;
  final String? emphasis;
}

abstract final class ExpenseHistoryCopy {
  static String time(DateTime? at) {
    if (at == null) return '';
    final l = at.toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final m = l.minute.toString().padLeft(2, '0');
    return '${BuddyFormat.dayMonth(l)}, $h:$m ${l.hour < 12 ? 'am' : 'pm'}';
  }

  static String _money(Object? v) => v is num ? BuddyFormat.rupees(v.round()) : '${v ?? ''}';

  static List<ExpenseHistoryText> lines(ExpenseHistoryLine line, String Function(String? userId) nameOf) {
    final actor = nameOf(line.actorUserId);
    final t = time(line.at);
    switch (line.kind) {
      case ExpenseHistoryKind.added:
        return [ExpenseHistoryText(time: t, sentence: ExpenseStrings.hAdded(actor), detail: ExpenseStrings.hAddedDetail(line.amountAfter, line.sharedBy))];
      case ExpenseHistoryKind.deleted:
        return [ExpenseHistoryText(time: t, sentence: ExpenseStrings.hDeleted(actor))];
      case ExpenseHistoryKind.sharedWith:
        final who = line.changes.isEmpty ? null : line.changes.first.newValue;
        return [ExpenseHistoryText(time: t, sentence: ExpenseStrings.hSharedWith(actor, nameOf(who?.toString())))];
    }
    if (line.changes.isEmpty) return [ExpenseHistoryText(time: t, sentence: ExpenseStrings.hShares(actor), detail: ExpenseStrings.hSharesDetail(line.sharedBy))];
    return [for (final c in line.changes) _change(t, actor, c, line, nameOf)];
  }

  static ExpenseHistoryText _change(String t, String actor, ExpenseChange c, ExpenseHistoryLine line, String Function(String?) nameOf) =>
      switch (c.field) {
        'amount' => ExpenseHistoryText(time: t, sentence: ExpenseStrings.hAmount(actor), detail: '${_money(c.oldValue)} → ', emphasis: _money(c.newValue)),
        'title' => ExpenseHistoryText(time: t, sentence: ExpenseStrings.hTitle(actor), detail: ExpenseStrings.arrow('${c.oldValue ?? ''}', '${c.newValue ?? ''}')),
        'category' => ExpenseHistoryText(time: t, sentence: ExpenseStrings.hCategory(actor)),
        'day' => ExpenseHistoryText(time: t, sentence: ExpenseStrings.hDay(actor, c.newValue)),
        'link' => ExpenseHistoryText(time: t, sentence: ExpenseStrings.hLink(actor)),
        'paidBy' => ExpenseHistoryText(
            time: t, sentence: ExpenseStrings.hPaidBy(actor), detail: ExpenseStrings.arrow(nameOf(c.oldValue?.toString()), nameOf(c.newValue?.toString()))),
        'note' => ExpenseHistoryText(time: t, sentence: ExpenseStrings.hNote(actor)),
        _ => ExpenseHistoryText(time: t, sentence: ExpenseStrings.hShares(actor), detail: ExpenseStrings.hSharesDetail(line.sharedBy)),
      };
}
