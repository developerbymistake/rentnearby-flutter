enum LedgerPaymentState { open, saysPaid, received, withdrawn, notReceived }

class SplitShare {
  const SplitShare(this.userId, this.share);
  final String userId;
  final int share;

  @override
  bool operator ==(Object other) => other is SplitShare && other.userId == userId && other.share == share;

  @override
  int get hashCode => Object.hash(userId, share);
}

class ExpenseSplit {
  const ExpenseSplit(this.shares, this.each, this.leftover, this.leftoverUserId);
  final List<SplitShare> shares;
  final int each;
  final int leftover;
  final String? leftoverUserId;
}

class CustomSplitCheck {
  const CustomSplitCheck(this.shares, this.assigned, this.difference, this.isValid);
  final List<SplitShare> shares;
  final int assigned;
  final int difference;
  final bool isValid;
}

class LedgerExpense {
  const LedgerExpense(this.paidByUserId, this.amount, this.shares);
  final String paidByUserId;
  final int amount;
  final List<SplitShare> shares;
}

class LedgerPayment {
  const LedgerPayment(this.id, this.fromUserId, this.toUserId, this.amount, this.state);
  final String id;
  final String fromUserId;
  final String toUserId;
  final int amount;
  final LedgerPaymentState state;
}

class PersonBalance {
  const PersonBalance(this.userId, this.paid, this.share, this.sent, this.got);
  final String userId;
  final int paid;
  final int share;
  final int sent;
  final int got;

  int get expenseNet => paid - share;
  int get settleNet => expenseNet + sent - got;
}

class OpenPayment {
  const OpenPayment(this.fromUserId, this.toUserId, this.amount);
  final String fromUserId;
  final String toUserId;
  final int amount;

  @override
  bool operator ==(Object other) =>
      other is OpenPayment && other.fromUserId == fromUserId && other.toUserId == toUserId && other.amount == amount;

  @override
  int get hashCode => Object.hash(fromUserId, toUserId, amount);
}

class SettleResult {
  const SettleResult(this.payments, this.exact);
  final List<OpenPayment> payments;
  final bool exact;
}

class WhoPaysRow {
  const WhoPaysRow(this.paymentId, this.fromUserId, this.toUserId, this.amount, this.state);
  final String? paymentId;
  final String fromUserId;
  final String toUserId;
  final int amount;
  final LedgerPaymentState state;
}

class WhoPaysList {
  const WhoPaysList(this.rows, this.done, this.total);
  final List<WhoPaysRow> rows;
  final int done;
  final int total;
}

class BalanceSheet {
  const BalanceSheet(this.people, this.open, this.exact, this.allSettled, this.whoPaysWhom);
  final List<PersonBalance> people;
  final List<OpenPayment> open;
  final bool exact;
  final bool allSettled;
  final WhoPaysList whoPaysWhom;
}

class _Found {
  _Found(this.from, this.to, this.amount);
  final int from;
  final int to;
  final int amount;
}

class _Keyed {
  _Keyed(this.from, this.to, this.kind, this.seq, this.row);
  final int from;
  final int to;
  final int kind;
  final int seq;
  final WhoPaysRow row;
}

// Whole rupees only. Mirror of the backend TripExpenseEngine; both read test/vectors/expense_engine_vectors.json.
// Every list passed as "canonical" is: owner, then joinedAt, then userId. Ids are lowercase uuid strings.
class TripExpenseEngine {
  TripExpenseEngine._();

  static const int minAmount = 1;
  static const int maxAmount = 500000;
  static const int maxSharers = 20;
  static const int exactSettleMaxPeople = 14;

  static bool counts(LedgerPaymentState state) =>
      state == LedgerPaymentState.saysPaid || state == LedgerPaymentState.received;

  static List<String> canonicalOrder(String ownerId, Iterable<(String userId, DateTime joinedAt)> members) {
    final rest = members.where((m) => m.$1 != ownerId).toList()
      ..sort((x, y) {
        final c = x.$2.compareTo(y.$2);
        return c != 0 ? c : x.$1.compareTo(y.$1);
      });
    final order = <String>[ownerId];
    for (final m in rest) {
      if (!order.contains(m.$1)) order.add(m.$1);
    }
    return order;
  }

  static List<String> order(List<String> canonical, Iterable<String> ids) {
    final index = _indexOf(canonical);
    final seen = <String>{};
    final known = <String>[];
    final unknown = <String>[];
    for (final id in ids) {
      if (!seen.add(id)) continue;
      (index.containsKey(id) ? known : unknown).add(id);
    }
    known.sort((x, y) => index[x]!.compareTo(index[y]!));
    unknown.sort();
    return known..addAll(unknown);
  }

  static ExpenseSplit equalSplit(int amount, List<String> canonical, List<String> sharers, String payer) {
    if (amount < minAmount) throw ArgumentError.value(amount, 'amount', 'Amount must be at least 1.');
    if (sharers.isEmpty || sharers.length > maxSharers) {
      throw ArgumentError.value(sharers.length, 'sharers', '1 to 20 sharers.');
    }
    final s = order(canonical, sharers);
    if (s.length != sharers.length) throw ArgumentError.value(sharers, 'sharers', 'A sharer is listed twice.');

    final k = s.length;
    final each = amount ~/ k;
    final leftover = amount % k;
    final String? leftoverUser = leftover > 0 ? (s.contains(payer) ? payer : s.first) : null;

    final shares = <SplitShare>[];
    for (final id in s) {
      final share = each + (id == leftoverUser ? leftover : 0);
      if (share > 0) shares.add(SplitShare(id, share));
    }
    return ExpenseSplit(shares, each, leftover, leftoverUser);
  }

  // difference > 0: left to assign. difference < 0: more than the amount. Zero entries are dropped.
  static CustomSplitCheck customSplit(int amount, List<String> canonical, List<SplitShare> entries) {
    final by = <String, int>{};
    var assigned = 0;
    for (final e in entries) {
      if (e.share < 0) throw ArgumentError.value(e.share, 'entries', 'A share cannot be negative.');
      if (by.containsKey(e.userId)) throw ArgumentError.value(e.userId, 'entries', 'A person is listed twice.');
      by[e.userId] = e.share;
      assigned += e.share;
    }
    final shares = [
      for (final id in order(canonical, by.keys))
        if (by[id]! > 0) SplitShare(id, by[id]!),
    ];
    final valid = amount >= minAmount && assigned == amount && shares.isNotEmpty && shares.length <= maxSharers;
    return CustomSplitCheck(shares, assigned, amount - assigned, valid);
  }

  // Late joiner: old sharers + joiner, equal split, leftover to the payer.
  static ExpenseSplit shareWith(
    int amount,
    List<String> canonical,
    List<SplitShare> stored,
    String payer,
    String joiner,
  ) {
    final ids = <String>[];
    for (final s in stored) {
      if (s.userId == joiner) throw ArgumentError.value(joiner, 'joiner', 'Already shares this expense.');
      ids.add(s.userId);
    }
    ids.add(joiner);
    return equalSplit(amount, canonical, ids, payer);
  }

  // Live expenses only (no deleted rows). Every canonical person gets a row, also with all zeros.
  static List<PersonBalance> balances(
    List<String> canonical,
    List<LedgerExpense> expenses,
    List<LedgerPayment> payments,
  ) {
    final ids = <String>[...canonical];
    for (final e in expenses) {
      ids.add(e.paidByUserId);
      for (final s in e.shares) {
        ids.add(s.userId);
      }
    }
    for (final p in payments) {
      ids
        ..add(p.fromUserId)
        ..add(p.toUserId);
    }
    final people = order(canonical, ids);
    final at = _indexOf(people);
    final n = people.length;
    final paid = List<int>.filled(n, 0);
    final share = List<int>.filled(n, 0);
    final sent = List<int>.filled(n, 0);
    final got = List<int>.filled(n, 0);

    for (final e in expenses) {
      var sum = 0;
      for (final s in e.shares) {
        share[at[s.userId]!] += s.share;
        sum += s.share;
      }
      if (sum != e.amount) throw ArgumentError.value(sum, 'expenses', 'Shares do not add up to the amount.');
      paid[at[e.paidByUserId]!] += e.amount;
    }
    for (final p in payments) {
      if (!counts(p.state)) continue;
      sent[at[p.fromUserId]!] += p.amount;
      got[at[p.toUserId]!] += p.amount;
    }
    return [for (var i = 0; i < n; i++) PersonBalance(people[i], paid[i], share[i], sent[i], got[i])];
  }

  // Nets in canonical order. Exact (fewest payments) up to 14 people with a non-zero net, plain greedy above.
  static SettleResult settle(List<(String userId, int net)> nets) {
    final ids = <String>[];
    final left = <int>[];
    var total = 0;
    for (final (userId, value) in nets) {
      total += value;
      if (value == 0) continue;
      ids.add(userId);
      left.add(value);
    }
    if (total != 0) throw ArgumentError.value(total, 'nets', 'Nets must sum to zero.');

    final n = left.length;
    final found = <_Found>[];
    final exact = n <= exactSettleMaxPeople;

    if (!exact) {
      _greedy([for (var i = 0; i < n; i++) i], left, found);
    } else if (n > 0) {
      final full = (1 << n) - 1;
      final sum = List<int>.filled(full + 1, 0);
      final dp = List<int>.filled(full + 1, 0);
      for (var mask = 1; mask <= full; mask++) {
        sum[mask] = sum[mask & (mask - 1)] + left[_lowIndex(mask)];
        var best = 0;
        for (var bits = mask; bits != 0; bits &= bits - 1) {
          final prev = dp[mask ^ (bits & -bits)];
          if (prev > best) best = prev;
        }
        dp[mask] = best + (sum[mask] == 0 ? 1 : 0);
      }

      var remaining = full;
      while (remaining != 0) {
        final low = remaining & -remaining;
        final rest = remaining ^ low;
        final want = dp[remaining] - 1;
        var group = 0;
        var groupSize = 1 << 30;
        for (var sub = rest;; sub = (sub - 1) & rest) {
          final g = sub | low;
          if (sum[g] == 0 && dp[remaining ^ g] == want) {
            final size = _popCount(g);
            if (size < groupSize || (size == groupSize && g < group)) {
              group = g;
              groupSize = size;
            }
          }
          if (sub == 0) break;
        }
        final members = <int>[];
        for (var bits = group; bits != 0; bits &= bits - 1) {
          members.add(_lowIndex(bits));
        }
        _greedy(members, left, found);
        remaining ^= group;
      }
    }

    found.sort((x, y) => x.from != y.from ? x.from.compareTo(y.from) : x.to.compareTo(y.to));
    return SettleResult([for (final f in found) OpenPayment(ids[f.from], ids[f.to], f.amount)], exact);
  }

  // Stored rows that count (saysPaid, received) + open rows; payer order, then receiver order, stored before open.
  // Pass the stored payments oldest first.
  static WhoPaysList whoPaysWhom(List<String> canonical, List<LedgerPayment> payments, List<OpenPayment> open) {
    final ids = <String>[...canonical];
    for (final p in payments) {
      ids
        ..add(p.fromUserId)
        ..add(p.toUserId);
    }
    for (final o in open) {
      ids
        ..add(o.fromUserId)
        ..add(o.toUserId);
    }
    final at = _indexOf(order(canonical, ids));

    final keyed = <_Keyed>[];
    var done = 0;
    for (var i = 0; i < payments.length; i++) {
      final p = payments[i];
      if (!counts(p.state)) continue;
      if (p.state == LedgerPaymentState.received) done++;
      keyed.add(_Keyed(at[p.fromUserId]!, at[p.toUserId]!, 0, i,
          WhoPaysRow(p.id, p.fromUserId, p.toUserId, p.amount, p.state)));
    }
    for (var i = 0; i < open.length; i++) {
      final o = open[i];
      keyed.add(_Keyed(at[o.fromUserId]!, at[o.toUserId]!, 1, i,
          WhoPaysRow(null, o.fromUserId, o.toUserId, o.amount, LedgerPaymentState.open)));
    }
    keyed.sort((x, y) {
      if (x.from != y.from) return x.from.compareTo(y.from);
      if (x.to != y.to) return x.to.compareTo(y.to);
      if (x.kind != y.kind) return x.kind.compareTo(y.kind);
      return x.seq.compareTo(y.seq);
    });
    return WhoPaysList([for (final k in keyed) k.row], done, keyed.length);
  }

  static BalanceSheet sheet(List<String> canonical, List<LedgerExpense> expenses, List<LedgerPayment> payments) {
    final people = balances(canonical, expenses, payments);
    final result = settle([for (final p in people) (p.userId, p.settleNet)]);
    final allSettled = people.every((p) => p.settleNet == 0) &&
        !payments.any((p) => p.state == LedgerPaymentState.saysPaid);
    return BalanceSheet(
        people, result.payments, result.exact, allSettled, whoPaysWhom(canonical, payments, result.payments));
  }

  // What "from" still has to pay "to" right now (0 when there is no open row for the pair).
  static int openAmount(List<OpenPayment> open, String from, String to) {
    for (final o in open) {
      if (o.fromUserId == from && o.toUserId == to) return o.amount;
    }
    return 0;
  }

  static Map<String, int> _indexOf(List<String> ids) {
    final index = <String, int>{};
    for (var i = 0; i < ids.length; i++) {
      index.putIfAbsent(ids[i], () => i);
    }
    return index;
  }

  static int _lowIndex(int mask) => (mask & -mask).bitLength - 1;

  static int _popCount(int mask) {
    var count = 0;
    for (var bits = mask; bits != 0; bits &= bits - 1) {
      count++;
    }
    return count;
  }

  static void _greedy(List<int> members, List<int> left, List<_Found> found) {
    while (true) {
      var debtor = -1;
      var creditor = -1;
      for (final i in members) {
        if (left[i] < 0 && (debtor < 0 || left[i] < left[debtor])) debtor = i;
        if (left[i] > 0 && (creditor < 0 || left[i] > left[creditor])) creditor = i;
      }
      if (debtor < 0 || creditor < 0) return;
      final amount = -left[debtor] < left[creditor] ? -left[debtor] : left[creditor];
      left[debtor] += amount;
      left[creditor] -= amount;
      found.add(_Found(debtor, creditor, amount));
    }
  }
}
