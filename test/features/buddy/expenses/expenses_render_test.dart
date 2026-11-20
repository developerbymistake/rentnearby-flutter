import 'package:bakhli/features/buddy/buddy_error_types.dart';
import 'package:bakhli/features/buddy/expenses/controllers/expense_sheet_controller.dart';
import 'package:bakhli/features/buddy/expenses/expense_rules.dart';
import 'package:bakhli/features/buddy/expenses/models/expense_models.dart';
import 'package:bakhli/features/buddy/expenses/screens/expense_detail_screen.dart';
import 'package:bakhli/features/buddy/expenses/screens/trip_expenses_screen.dart';
import 'package:bakhli/features/buddy/expenses/widgets/expense_delete_dialog.dart';
import 'package:bakhli/features/buddy/expenses/widgets/expense_sheet.dart';
import 'package:bakhli/features/buddy/expenses/widgets/late_joiner_sheet.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/buddy_render.dart';
import 'expenses_fixtures.dart';

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.tap(f.last);
  await _settle(t);
}

Future<void> _render(WidgetTester t, String id, Widget screen, {Future<void> Function(WidgetTester)? arrange}) async {
  final f = await renderFrame(t, id, screen, arrange: arrange);
  expect(t.takeException(), isNull);
  expect(f.existsSync(), isTrue);
  await t.pump(const Duration(seconds: 6));
}

ExpenseSheetController get _sheet => ExpenseSheet.debugLast!;

Future<void> _openAdd(WidgetTester t) => _tap(t, find.byKey(TripExpensesScreen.addKey));

void _fill(ExpenseSheetController c, {required int amount, required String title, required String cat}) {
  c.amountDigits.value = '$amount';
  c.titleCtl.text = title;
  c.onTitle(title);
  c.pickCategory(cat);
}

void _custom(ExpenseSheetController c, Map<String, int> v, String last) {
  c.pickMode(SplitMode.custom);
  c.customDigits.addAll({for (final e in v.entries) e.key: '${e.value}'});
  c.lastCustom.value = last;
  c.focus.value = null;
  c.padOpen.value = false;
}

void main() {
  useBuddyRenderScale();
  tearDown(resetExpenseFakes);

  testWidgets('4.1 expenses empty', (t) async {
    registerFakes(list: BuddyOk(emptyList()));
    await _render(t, '4.1', TripExpensesScreen(tripId: tripId, initial: emptyList()));
  });

  testWidgets('4.2 add expense', (t) async {
    registerFakes(list: BuddyOk(sheetList(dayToday: 3)));
    await _render(t, '4.2', TripExpensesScreen(tripId: tripId, initial: sheetList(dayToday: 3)), arrange: (t) async {
      await _openAdd(t);
      final c = _sheet;
      _fill(c, amount: 18500, title: 'Taxi, Suresh (Dzire), full trip', cat: ExpenseCategory.taxi);
      c.pickLink(c.setup.links.firstWhere((l) => l.kind == ExpenseLinkKind.taxi));
      c.day.value = 3;
      c.padOpen.value = false;
      await _settle(t);
    });
  });

  testWidgets('4.3 choose people', (t) async {
    registerFakes(list: BuddyOk(sheetList()));
    await _render(t, '4.3', TripExpensesScreen(tripId: tripId, initial: sheetList()), arrange: (t) async {
      await _openAdd(t);
      final c = _sheet;
      _fill(c, amount: 2400, title: 'Rafting in Rishikesh', cat: ExpenseCategory.other);
      c.padOpen.value = false;
      c.pickMode(SplitMode.chosen);
      c.toggle(c.person(rahul)!);
      await _settle(t);
    });
  });

  testWidgets('4.4 custom left to assign', (t) async {
    registerFakes(list: BuddyOk(sheetList(dayToday: 3)));
    await _render(t, '4.4', TripExpensesScreen(tripId: tripId, initial: sheetList(dayToday: 3)), arrange: (t) async {
      await _openAdd(t);
      final c = _sheet;
      _fill(c, amount: 1500, title: 'Dinner by the Ganga', cat: ExpenseCategory.food);
      c.pickPayer(priya);
      _custom(c, {rahul: 500, aman: 500, priya: 300}, priya);
      await _settle(t);
    });
  });

  testWidgets('4.4a empty fields', (t) async {
    registerFakes(list: BuddyOk(sheetList()));
    await _render(t, '4.4a', TripExpensesScreen(tripId: tripId, initial: sheetList()), arrange: (t) async {
      await _openAdd(t);
      await _tap(t, find.byKey(ExpenseSheet.saveKey));
    });
  });

  testWidgets('4.4b limit and nobody ticked', (t) async {
    registerFakes(list: BuddyOk(sheetList()));
    await _render(t, '4.4b', TripExpensesScreen(tripId: tripId, initial: sheetList()), arrange: (t) async {
      await _openAdd(t);
      final c = _sheet;
      _fill(c, amount: 600000, title: 'Rafting in Rishikesh', cat: ExpenseCategory.other);
      c.touched.add(ExpenseField.amount);
      c.padOpen.value = false;
      c.pickMode(SplitMode.chosen);
      for (final id in [rahul, aman, priya]) {
        c.toggle(c.person(id)!);
      }
      await _settle(t);
    });
  });

  testWidgets('4.4c custom above the amount', (t) async {
    registerFakes(list: BuddyOk(sheetList(dayToday: 3)));
    await _render(t, '4.4c', TripExpensesScreen(tripId: tripId, initial: sheetList(dayToday: 3)), arrange: (t) async {
      await _openAdd(t);
      final c = _sheet;
      _fill(c, amount: 1500, title: 'Dinner by the Ganga', cat: ExpenseCategory.food);
      c.pickPayer(priya);
      _custom(c, {rahul: 500, aman: 700, priya: 500}, aman);
      await _settle(t);
    });
  });

  testWidgets('4.4d custom all assigned', (t) async {
    registerFakes(list: BuddyOk(sheetList(dayToday: 3)));
    await _render(t, '4.4d', TripExpensesScreen(tripId: tripId, initial: sheetList(dayToday: 3)), arrange: (t) async {
      await _openAdd(t);
      final c = _sheet;
      _fill(c, amount: 1500, title: 'Dinner by the Ganga', cat: ExpenseCategory.food);
      c.pickPayer(priya);
      _custom(c, {rahul: 500, aman: 500, priya: 500}, priya);
      await _settle(t);
    });
  });

  testWidgets('4.5 by day', (t) async {
    registerFakes(list: BuddyOk(ownerList()));
    await _render(t, '4.5', TripExpensesScreen(tripId: tripId, initial: ownerList()));
  });

  testWidgets('4.5a 500 expenses', (t) async {
    registerFakes(list: BuddyOk(limitList()));
    await _render(t, '4.5a', TripExpensesScreen(tripId: tripId, initial: limitList()));
  });

  testWidgets('4.6 late joiner', (t) async {
    registerFakes(list: BuddyOk(lateList()));
    await _render(t, '4.6', TripExpensesScreen(tripId: tripId, initial: lateList()));
  });

  testWidgets('4.7 choose earlier expenses', (t) async {
    registerFakes(list: BuddyOk(lateList()));
    await _render(t, '4.7', TripExpensesScreen(tripId: tripId, initial: lateList()), arrange: (t) async {
      await _settle(t);
      await _tap(t, find.byKey(LateJoinerSheet.chooseKey));
      await _tap(t, find.text('Snow View Hotel, 3 nights'));
    });
  });

  testWidgets('4.8 expense detail', (t) async {
    registerFakes(list: BuddyOk(sheetList(dayToday: 3)), detail: BuddyOk(detailPage()));
    await _render(t, '4.8', ExpenseDetailScreen(tripId: tripId, expenseId: e4, initial: detailPage(), context: sheetList(dayToday: 3)));
  });

  testWidgets('4.8a edit expense', (t) async {
    final ctx = sheetList(dayToday: 3, amanStatus: 'Left');
    final page = detailPage({'splitMode': 'Chosen'});
    registerFakes(list: BuddyOk(ctx), detail: BuddyOk(page));
    await _render(t, '4.8a', ExpenseDetailScreen(tripId: tripId, expenseId: e4, initial: page, context: ctx), arrange: (t) async {
      await _tap(t, find.byKey(ExpenseDetailScreen.editKey));
    });
  });

  testWidgets('4.8b edit, left and removed', (t) async {
    final ctx = sheetList(dayToday: 3, amanStatus: 'Left');
    final page = detailPage({
      'id': e5,
      'title': 'Dinner by the Ganga',
      'category': 'Food',
      'amount': 1500,
      'link': null,
      'splitMode': 'Chosen',
      'shares': [
        {'userId': rahul, 'share': 750},
        {'userId': priya, 'share': 750},
      ],
    });
    registerFakes(list: BuddyOk(ctx), detail: BuddyOk(page));
    await _render(t, '4.8b', ExpenseDetailScreen(tripId: tripId, expenseId: e5, initial: page, context: ctx), arrange: (t) async {
      await _tap(t, find.byKey(ExpenseDetailScreen.editKey));
    });
  });

  testWidgets('4.8c payments made', (t) async {
    final page = detailPage({'splitMode': 'Chosen'});
    final f = registerFakes(list: BuddyOk(sheetList(dayToday: 3)), detail: BuddyOk(page));
    f.gateway.saveOutcomes.add(refused(BuddyErrorTypes.paymentsNotAcknowledged));
    await _render(t, '4.8c', ExpenseDetailScreen(tripId: tripId, expenseId: e4, initial: page, context: sheetList(dayToday: 3)), arrange: (t) async {
      await _tap(t, find.byKey(ExpenseDetailScreen.editKey));
      _sheet.amountDigits.value = '19100';
      await _settle(t);
      await _tap(t, find.byKey(ExpenseSheet.saveKey));
    });
  });

  testWidgets('4.8d delete', (t) async {
    final f = registerFakes(list: BuddyOk(sheetList(dayToday: 3)), detail: BuddyOk(detailPage()));
    f.gateway.deleteOutcomes.add(refused(BuddyErrorTypes.paymentsNotAcknowledged));
    await _render(t, '4.8d', ExpenseDetailScreen(tripId: tripId, expenseId: e4, initial: detailPage(), context: sheetList(dayToday: 3)), arrange: (t) async {
      await _tap(t, find.byKey(ExpenseDetailScreen.menuKey));
      await _tap(t, find.text('Delete'));
      await _tap(t, find.byKey(ExpenseDeleteDialog.deleteKey));
    });
  });

  Map<String, dynamic> current() => {
        ...sample('e4_expense_detail')['expense'] as Map<String, dynamic>,
        'amount': 19000,
        'version': 3,
        'shares': [
          {'userId': rahul, 'share': 6334},
          {'userId': aman, 'share': 6333},
          {'userId': priya, 'share': 6333},
        ],
      };

  Future<void> conflictArrange(WidgetTester t) async {
    await _tap(t, find.byKey(ExpenseDetailScreen.editKey));
    _sheet.amountDigits.value = '18000';
    _sheet.focus.value = ExpenseSheetController.amountFocus;
    await _settle(t);
    await _tap(t, find.byKey(ExpenseSheet.saveKey));
  }

  testWidgets('4.8e updated on another device', (t) async {
    final f = registerFakes(list: BuddyOk(sheetList(dayToday: 3)), detail: BuddyOk(detailPage()));
    f.gateway.saveOutcomes.add(refused(BuddyErrorTypes.expenseVersionConflict, data: {'current': current()}));
    await _render(t, '4.8e', ExpenseDetailScreen(tripId: tripId, expenseId: e4, initial: detailPage(), context: sheetList(dayToday: 3)), arrange: conflictArrange);
  });

  testWidgets('4.8f after refresh', (t) async {
    final f = registerFakes(list: BuddyOk(sheetList(dayToday: 3)), detail: BuddyOk(detailPage()));
    f.gateway.saveOutcomes.add(refused(BuddyErrorTypes.expenseVersionConflict, data: {'current': current()}));
    await _render(t, '4.8f', ExpenseDetailScreen(tripId: tripId, expenseId: e4, initial: detailPage(), context: sheetList(dayToday: 3)), arrange: (t) async {
      await conflictArrange(t);
      await _tap(t, find.byKey(ExpenseSheet.refreshKey));
    });
  });
}
