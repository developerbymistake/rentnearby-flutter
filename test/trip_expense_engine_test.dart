import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bakhli/utils/trip_expense_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _vectorFile = 'test/vectors/expense_engine_vectors.json';

const _states = {
  'Open': LedgerPaymentState.open,
  'SaysPaid': LedgerPaymentState.saysPaid,
  'Received': LedgerPaymentState.received,
  'Withdrawn': LedgerPaymentState.withdrawn,
  'NotReceived': LedgerPaymentState.notReceived,
};

String _stateName(LedgerPaymentState s) => _states.entries.firstWhere((e) => e.value == s).key;

List<String> _ids(dynamic v) => (v as List).cast<String>();

List<SplitShare> _shares(dynamic v) =>
    [for (final x in v as List) SplitShare(x['userId'] as String, x['share'] as int)];

Map<String, dynamic> _share(SplitShare s) => {'userId': s.userId, 'share': s.share};

Map<String, dynamic> _pay(OpenPayment p) => {'from': p.fromUserId, 'to': p.toUserId, 'amount': p.amount};

Map<String, dynamic> _split(ExpenseSplit s) => {
      'shares': s.shares.map(_share).toList(),
      'each': s.each,
      'leftover': s.leftover,
      'leftoverUserId': s.leftoverUserId,
    };

dynamic _run(String kind, Map<String, dynamic> input) {
  switch (kind) {
    case 'equalSplit':
      return _split(TripExpenseEngine.equalSplit(
          input['amount'] as int, _ids(input['canonical']), _ids(input['sharers']), input['payer'] as String));
    case 'customSplit':
      final c = TripExpenseEngine.customSplit(
          input['amount'] as int, _ids(input['canonical']), _shares(input['entries']));
      return {
        'shares': c.shares.map(_share).toList(),
        'assigned': c.assigned,
        'difference': c.difference,
        'isValid': c.isValid,
      };
    case 'shareWith':
      return _split(TripExpenseEngine.shareWith(input['amount'] as int, _ids(input['canonical']),
          _shares(input['stored']), input['payer'] as String, input['joiner'] as String));
    case 'canonicalOrder':
      return TripExpenseEngine.canonicalOrder(input['owner'] as String, [
        for (final m in input['members'] as List) (m['userId'] as String, DateTime.parse(m['joinedAt'] as String)),
      ]);
    case 'settle':
      final r = TripExpenseEngine.settle([
        for (final n in input['nets'] as List) (n['userId'] as String, n['net'] as int),
      ]);
      return {'payments': r.payments.map(_pay).toList(), 'exact': r.exact};
    case 'sheet':
      final s = TripExpenseEngine.sheet(
        _ids(input['canonical']),
        [
          for (final e in input['expenses'] as List)
            LedgerExpense(e['paidBy'] as String, e['amount'] as int, _shares(e['shares'])),
        ],
        [
          for (final p in input['payments'] as List)
            LedgerPayment(p['id'] as String, p['from'] as String, p['to'] as String, p['amount'] as int,
                _states[p['state']]!),
        ],
      );
      return {
        'people': [
          for (final p in s.people)
            {
              'userId': p.userId,
              'paid': p.paid,
              'share': p.share,
              'sent': p.sent,
              'got': p.got,
              'expenseNet': p.expenseNet,
              'settleNet': p.settleNet,
            },
        ],
        'open': s.open.map(_pay).toList(),
        'exact': s.exact,
        'allSettled': s.allSettled,
        'whoPaysWhom': {
          'rows': [
            for (final r in s.whoPaysWhom.rows)
              {
                'paymentId': r.paymentId,
                'from': r.fromUserId,
                'to': r.toUserId,
                'amount': r.amount,
                'state': _stateName(r.state),
              },
          ],
          'done': s.whoPaysWhom.done,
          'total': s.whoPaysWhom.total,
        },
      };
  }
  throw StateError('Unknown kind $kind');
}

void main() {
  final doc = jsonDecode(File(_vectorFile).readAsStringSync()) as Map<String, dynamic>;
  final cases = (doc['cases'] as List).cast<Map<String, dynamic>>();

  test('vector file has every kind', () {
    expect(doc['version'], 1);
    expect(cases.length, 89);
    expect(cases.map((c) => c['kind']).toSet(),
        {'equalSplit', 'customSplit', 'shareWith', 'canonicalOrder', 'settle', 'sheet'});
  });

  for (var i = 0; i < cases.length; i++) {
    final c = cases[i];
    test('vector $i: ${c['name']}', () {
      final input = c['in'] as Map<String, dynamic>;
      final kind = c['kind'] as String;
      if (c['error'] == true) {
        expect(() => _run(kind, input), throwsArgumentError);
        return;
      }
      expect(_run(kind, input), equals(c['out']));
      expect(jsonEncode(_run(kind, input)), jsonEncode(_run(kind, input)));
    });
  }

  test('18500 by 3 is 6168, 6166, 6166', () {
    final split = TripExpenseEngine.equalSplit(18500, ['r', 'a', 'p'], ['p', 'a', 'r'], 'r');
    expect(split.shares, const [SplitShare('r', 6168), SplitShare('a', 6166), SplitShare('p', 6166)]);
    expect(split.leftover, 2);
    expect(split.leftoverUserId, 'r');
  });

  test('random nets clear every balance and stay stable', () {
    final rnd = Random(20261120);
    for (var round = 0; round < 300; round++) {
      final n = 2 + rnd.nextInt(19);
      final ids = [for (var i = 0; i < n; i++) 'u${i.toString().padLeft(2, '0')}'];
      final nets = List<int>.filled(n, 0);
      for (var i = 0; i < n - 1; i++) {
        nets[i] = (rnd.nextInt(19) - 9) * (1 + rnd.nextInt(3999));
        nets[n - 1] -= nets[i];
      }
      final input = [for (var i = 0; i < n; i++) (ids[i], nets[i])];
      final first = TripExpenseEngine.settle(input);
      expect(TripExpenseEngine.settle(input).payments, first.payments);

      final people = nets.where((v) => v != 0).length;
      expect(first.exact, people <= TripExpenseEngine.exactSettleMaxPeople);
      expect(first.payments.length, lessThanOrEqualTo(max(0, people - 1)));

      final left = {for (var i = 0; i < n; i++) ids[i]: nets[i]};
      var last = (-1, -1);
      for (final p in first.payments) {
        expect(p.amount, greaterThan(0));
        expect(left[p.fromUserId]! < 0 && left[p.toUserId]! > 0, isTrue);
        left[p.fromUserId] = left[p.fromUserId]! + p.amount;
        left[p.toUserId] = left[p.toUserId]! - p.amount;
        final key = (ids.indexOf(p.fromUserId), ids.indexOf(p.toUserId));
        expect(key.$1 > last.$1 || (key.$1 == last.$1 && key.$2 > last.$2), isTrue);
        last = key;
      }
      expect(left.values.every((v) => v == 0), isTrue);
    }
  });

  test('worst case of 14 people is fast', () {
    final input = [for (var i = 0; i < 14; i++) ('u${i.toString().padLeft(2, '0')}', i.isEven ? 1 : -1)];
    final watch = Stopwatch()..start();
    final result = TripExpenseEngine.settle(input);
    watch.stop();
    expect(result.payments.length, 7);
    expect(watch.elapsedMilliseconds, lessThan(2000));
  });

  test('open amount reads the pair', () {
    const open = [OpenPayment('a', 'b', 500)];
    expect(TripExpenseEngine.openAmount(open, 'a', 'b'), 500);
    expect(TripExpenseEngine.openAmount(open, 'b', 'a'), 0);
  });
}
