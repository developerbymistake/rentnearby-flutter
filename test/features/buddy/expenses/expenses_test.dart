import 'package:bakhli/features/buddy/buddy_error_types.dart';
import 'package:bakhli/features/buddy/expenses/controllers/expense_sheet_controller.dart';
import 'package:bakhli/features/buddy/expenses/data/expense_write_gateway.dart';
import 'package:bakhli/features/buddy/expenses/expense_deps.dart';
import 'package:bakhli/features/buddy/expenses/expense_rules.dart';
import 'package:bakhli/features/buddy/expenses/expense_strings.dart';
import 'package:bakhli/features/buddy/expenses/models/expense_models.dart';
import 'package:bakhli/features/buddy/expenses/screens/expense_detail_screen.dart';
import 'package:bakhli/features/buddy/expenses/screens/trip_expenses_screen.dart';
import 'package:bakhli/features/buddy/expenses/widgets/amount_pad.dart';
import 'package:bakhli/features/buddy/expenses/widgets/expense_day_list.dart';
import 'package:bakhli/features/buddy/expenses/widgets/expense_delete_dialog.dart';
import 'package:bakhli/features/buddy/expenses/widgets/expense_sheet.dart';
import 'package:bakhli/features/buddy/expenses/widgets/expense_suggestion_card.dart';
import 'package:bakhli/features/buddy/expenses/widgets/late_joiner_sheet.dart';
import 'package:bakhli/features/buddy/expenses/widgets/share_earlier_sheet.dart';
import 'package:bakhli/features/buddy/expenses/widgets/split_editor.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/shared/models/person_models.dart';
import 'package:bakhli/features/buddy/shared/widgets/view_only_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/real_phone.dart';
import 'expenses_fixtures.dart';

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f.last);
  await t.pump();
  await t.tap(f.last);
  await _settle(t);
}

Future<void> _pump(WidgetTester t, Widget w) async {
  await pumpPhone(t, w, size: const Size(392, 900), toastHost: true);
  await _settle(t);
}

Future<void> _keys(WidgetTester t, String digits) async {
  for (final d in digits.split('')) {
    await t.tap(find.byKey(AmountPad.keyOf(d)));
    await t.pump();
  }
}

void _tw(String name, Future<void> Function(WidgetTester t) body) => testWidgets(name, (t) async {
      await body(t);
      await t.pump(const Duration(seconds: 6));
    });

ExpenseSheetController get _sheet => ExpenseSheet.debugLast!;

const _me = MoneyPerson(userId: rahul, name: 'Rahul', last4: '1736', initial: 'R', isMe: true, status: 'Owner');
const _aman = MoneyPerson(userId: aman, name: 'Aman', last4: '8275', initial: 'A', isMe: false, status: 'Joined');

void main() {
  tearDown(resetExpenseFakes);

  group('rules', () {
    test('amount lines', () {
      expect(ExpenseRules.amountError(null), ExpenseStrings.errAmount);
      expect(ExpenseRules.amountError(0), ExpenseStrings.errAmount);
      expect(ExpenseRules.amountError(500000), isNull);
      expect(ExpenseRules.amountError(500001), 'Up to ₹5,00,000 for one expense');
    });

    test('pad digits: no leading zero, max 6', () {
      expect(ExpenseRules.pushDigit('', '0'), '');
      expect(ExpenseRules.pushDigit('12345', '6'), '123456');
      expect(ExpenseRules.pushDigit('123456', '7'), '123456');
      expect(ExpenseRules.popDigit('12'), '1');
      expect(AmountKeys.grid.where((k) => k == '-' || k == '.'), isEmpty);
    });

    test('short title cuts at a comma', () {
      expect(ExpenseRules.shortTitle('Taxi, Suresh (Dzire), full trip'), 'Taxi, Suresh (Dzire)');
      expect(ExpenseRules.shortTitle('Lunch'), 'Lunch');
    });

    test('fold link text', () {
      final l = ownerList();
      final f = ExpenseFold.of(days: l.days, rowsPerDay: {4: 1, 3: 2, 2: 1, 1: 2}, fold: true);
      expect(f.shownDays, [4, 3]);
      expect(f.linkText, 'Show Day 2 and Day 1 · ₹9,900');
      final range = ExpenseFold.of(days: limitList().days, rowsPerDay: {6: 3}, fold: true);
      expect(range.linkText, 'Show Day 5 to Day 1 · ₹4,09,350');
      expect(ExpenseFold.of(days: l.days, rowsPerDay: {4: 1, 3: 2, 2: 1, 1: 2}, fold: false).folded, isFalse);
    });

    test('payer label: plain name, you for a viewer, last 4 for twins', () {
      expect(ExpenseRules.payerLabel(payerId: rahul, travellers: const [_me, _aman], callerIsOwner: true), 'Paid by Rahul');
      expect(ExpenseRules.payerLabel(payerId: rahul, travellers: const [_me, _aman], callerIsOwner: false), 'Paid by you');
      const twin = MoneyPerson(userId: priya, name: 'Aman', last4: '7139', initial: 'A', isMe: false, status: 'Joined');
      expect(ExpenseRules.payerLabel(payerId: aman, travellers: const [_me, _aman, twin], callerIsOwner: true), 'Paid by Aman 8275');
    });

    test('history copy', () {
      final page = detailPage();
      String name(String? id) => id == rahul ? 'Rahul' : 'Aman';
      final edited = ExpenseHistoryCopy.lines(page.history.first, name).single;
      expect(edited.sentence, 'Rahul changed the amount');
      expect('${edited.detail}${edited.emphasis}', '₹19,200 → ₹18,500');
      final added = ExpenseHistoryCopy.lines(page.history.last, name).single;
      expect(added.sentence, 'Rahul added this expense');
      expect(added.detail, '₹19,200 · shared by 3');
    });

    test('payments box names', () {
      expect(ExpenseStrings.paymentsBody(const ['Aman', 'Priya']), endsWith('Aman and Priya are told.'));
      expect(ExpenseStrings.paymentsBody(const ['Aman']), endsWith('Aman is told.'));
      expect(ExpenseStrings.paymentsBody(const []), endsWith('Travellers are told.'));
    });
  });

  group('list', () {
    _tw('owner empty: one hero cell, suggestion, empty state, no tabs; Skip calls E5', (t) async {
      final f = registerFakes(list: BuddyOk(emptyList()));
      await _pump(t, TripExpensesScreen(tripId: tripId, initial: emptyList()));
      expect(find.text('Spent so far'), findsOneWidget);
      expect(find.text('₹0'), findsOneWidget);
      expect(find.text('Travellers'), findsOneWidget);
      expect(find.text('Your share'), findsNothing);
      expect(find.text('Snow View Hotel is booked for ₹8,000'), findsOneWidget);
      expect(find.text('No expenses yet'), findsOneWidget);
      expect(find.text('Add what the group spends, day by day.'), findsOneWidget);
      expect(find.text('By day'), findsNothing);
      await _tap(t, find.byKey(ExpenseSuggestionCard.skipKey));
      expect(f.api.calls, contains('skip:$stayLink'));
      expect(find.text('Snow View Hotel is booked for ₹8,000'), findsNothing);
    });

    _tw('suggestion Add opens the filled sheet linked to the stay', (t) async {
      registerFakes(list: BuddyOk(emptyList()));
      await _pump(t, TripExpensesScreen(tripId: tripId, initial: emptyList()));
      await _tap(t, find.byKey(ExpenseSuggestionCard.addKey));
      expect(find.text('From your booked stay'), findsOneWidget);
      expect(find.text('₹ 8,000'), findsOneWidget);
      expect(_sheet.link.value?.id, stayLink);
      expect(_sheet.category.value, ExpenseCategory.stay);
    });

    _tw('viewer empty: view only, owner line, no add button', (t) async {
      registerFakes(list: BuddyOk(viewerEmpty()));
      await _pump(t, TripExpensesScreen(tripId: tripId, initial: viewerEmpty()));
      expect(find.byType(ViewOnlyChip), findsOneWidget);
      expect(find.text('Rahul has not added any expense yet'), findsOneWidget);
      expect(find.byKey(TripExpensesScreen.addKey), findsNothing);
      expect(find.text('Uttarakhand Hills Trip · by Rahul'), findsOneWidget);
    });

    _tw('by day: headers, rows, fold link, show all, row tap', (t) async {
      registerFakes(list: BuddyOk(ownerList()));
      String? opened;
      ExpenseDeps.openExpense = (trip, id) {
        opened = id;
        return null;
      };
      await _pump(t, TripExpensesScreen(tripId: tripId, initial: ownerList()));
      expect(find.text('Uttarakhand Hills Trip · Day 4'), findsOneWidget);
      expect(find.text('DAY 4 · 19 MAY'), findsOneWidget);
      expect(find.text('Paid by Rahul · Shared by 2'), findsOneWidget);
      expect(find.text('Your share ₹6,168'), findsOneWidget);
      expect(find.text('Edited'), findsOneWidget);
      expect(find.text('Show Day 2 and Day 1 · ₹9,900'), findsOneWidget);
      expect(find.text('Naini Lake boating'), findsNothing);
      await _tap(t, find.byKey(ExpenseDayList.showAllKey));
      expect(find.text('Naini Lake boating'), findsOneWidget);
      await _tap(t, find.text('Dinner by the Ganga'));
      expect(opened, e5);
    });

    _tw('500 expenses: line above a grey pill that does nothing', (t) async {
      registerFakes(list: BuddyOk(limitList()));
      await _pump(t, TripExpensesScreen(tripId: tripId, initial: limitList()));
      expect(find.text('This trip has 500 expenses. Delete one to add more.'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(find.text('Expenses'), findsWidgets);
      await _tap(t, find.byKey(TripExpensesScreen.addKey));
      expect(ExpenseSheet.debugLast, isNull);
    });

    _tw('frozen trip: no add, no suggestion', (t) async {
      final frozen = ExpenseList.fromJson({...emptyList().toJson(), 'frozen': true});
      registerFakes(list: BuddyOk(frozen));
      await _pump(t, TripExpensesScreen(tripId: tripId, initial: frozen));
      expect(find.byKey(TripExpensesScreen.addKey), findsNothing);
      expect(find.byKey(ExpenseSuggestionCard.addKey), findsNothing);
    });

    _tw('former role replaces the route with my share', (t) async {
      final former = ExpenseList.fromJson({...ownerList().toJson(), 'role': 'Former', 'isOwner': false});
      registerFakes(list: BuddyOk(former));
      String? myShare;
      ExpenseDeps.openMyShare = (id) => myShare = id;
      await _pump(t, TripExpensesScreen(tripId: tripId, initial: former));
      expect(myShare, tripId);
    });

    _tw('trip gone view on 404', (t) async {
      registerFakes(list: const BuddyRefused(type: BuddyErrorTypes.tripNotFound, statusCode: 404));
      await _pump(t, const TripExpensesScreen(tripId: tripId));
      expect(find.text(ExpenseStrings.tripGone), findsOneWidget);
    });
  });

  group('sheet', () {
    Future<FakeGateway> open(WidgetTester t, {int dayToday = 4}) async {
      final f = registerFakes(list: BuddyOk(sheetList(dayToday: dayToday)));
      await _pump(t, TripExpensesScreen(tripId: tripId, initial: sheetList(dayToday: dayToday)));
      await _tap(t, find.byKey(TripExpensesScreen.addKey));
      return f.gateway;
    }

    _tw('blank sheet: pad up, grey save shows one line per wrong field', (t) async {
      await open(t);
      expect(find.text('Add expense'), findsOneWidget);
      expect(find.text('Day 4 · 19 May'), findsOneWidget);
      expect(find.byType(AmountPad), findsOneWidget);
      expect(find.text('₹ 0'), findsOneWidget);
      expect(find.text('Enter the amount'), findsNothing);
      await _tap(t, find.byKey(ExpenseSheet.saveKey));
      expect(find.text('Enter the amount'), findsOneWidget);
      expect(find.text('Add a short title'), findsOneWidget);
      expect(find.text('Choose a category'), findsOneWidget);
      expect(find.text('For example, lunch at Mall Road'), findsOneWidget);
    });

    _tw('pad typing groups digits and caps at 6 digits; above the limit shows the line', (t) async {
      await open(t);
      await _keys(t, '18500');
      expect(find.text('₹ 18,500'), findsOneWidget);
      await _keys(t, '0');
      expect(find.text('₹ 1,85,000'), findsOneWidget);
      await _keys(t, '9');
      expect(find.text('₹ 1,85,000'), findsOneWidget);
      await t.tap(find.byKey(AmountPad.keyOf(AmountKeys.back)));
      await t.pump();
      expect(find.text('₹ 18,500'), findsOneWidget);
      _sheet.amountDigits.value = '600000';
      await _settle(t);
      expect(find.text('Up to ₹5,00,000 for one expense'), findsOneWidget);
    });

    _tw('split all with leftover, choose people, nobody ticked, custom lines', (t) async {
      await open(t);
      final c = _sheet;
      c.amountDigits.value = '18500';
      c.titleCtl.text = 'Taxi';
      c.onTitle('Taxi');
      c.pickCategory(ExpenseCategory.taxi);
      c.blurPad();
      await _settle(t);
      expect(find.text("₹2 left over is added to Rahul's share"), findsOneWidget);
      expect(find.text('₹6,168'), findsOneWidget);
      await _tap(t, find.text('Choose people'));
      await _tap(t, find.byKey(SplitEditor.rowKey(rahul)));
      expect(find.text('Not in this one'), findsOneWidget);
      expect(find.text('₹9,250 each, shared by 2'), findsOneWidget);
      await _tap(t, find.byKey(SplitEditor.rowKey(aman)));
      await _tap(t, find.byKey(SplitEditor.rowKey(priya)));
      expect(find.text('Choose at least one person'), findsOneWidget);
      expect(c.valid, isFalse);
      await _tap(t, find.text('Custom'));
      c.customDigits.addAll({rahul: '10000', aman: '5000', priya: '3000'});
      c.lastCustom.value = priya;
      await _settle(t);
      expect(find.text('₹500 left to assign'), findsOneWidget);
      c.customDigits[priya] = '4000';
      await _settle(t);
      expect(find.text('₹500 more than the amount'), findsOneWidget);
      c.customDigits[priya] = '3500';
      await _settle(t);
      expect(find.text('All assigned'), findsOneWidget);
      expect(c.valid, isTrue);
    });

    _tw('save sends one op with the app id and closes with Expense added', (t) async {
      final g = await open(t);
      await _keys(t, '2400');
      final c = _sheet;
      c.titleCtl.text = 'Rafting in Rishikesh';
      c.onTitle('Rafting in Rishikesh');
      c.pickCategory(ExpenseCategory.other);
      c.pickMode(SplitMode.chosen);
      c.toggle(c.person(rahul)!);
      await _settle(t);
      await _tap(t, find.byKey(ExpenseSheet.saveKey));
      expect(g.drafts, hasLength(1));
      final body = g.drafts.single.body;
      expect(body.baseVersion, 0);
      expect(body.amount, 2400);
      expect(body.splitMode, SplitMode.chosen);
      expect(body.sharers, [aman, priya]);
      expect(body.dayNumber, 4);
      expect(body.opId, isNotEmpty);
      expect(g.drafts.single.expenseId, isNotEmpty);
      expect(find.text('Expense added'), findsOneWidget);
      expect(find.text('Add expense'), findsNothing);
    });

    _tw('close with typed data asks first', (t) async {
      await open(t);
      await _keys(t, '5');
      await _tap(t, find.byKey(ExpenseSheet.closeKey));
      expect(find.text('Discard this expense?'), findsOneWidget);
      await _tap(t, find.text('Keep editing'));
      expect(find.text('Add expense'), findsOneWidget);
    });

    _tw('server refusals: limit closes, link cleared with a line, id taken retries once', (t) async {
      final g = await open(t);
      final c = _sheet;
      void fill() {
        c.amountDigits.value = '900';
        c.titleCtl.text = 'Boat';
        c.onTitle('Boat');
        c.pickCategory(ExpenseCategory.tickets);
        c.blurPad();
      }

      fill();
      c.pickLink(c.setup.links.first);
      g.saveOutcomes.addAll([refused(BuddyErrorTypes.linkNotInTrip, status: 422), refused(BuddyErrorTypes.expenseIdTaken)]);
      await _settle(t);
      await _tap(t, find.byKey(ExpenseSheet.saveKey));
      expect(find.text('This booking is not part of this trip.'), findsOneWidget);
      expect(c.link.value, isNull);
      final firstId = c.expenseId;
      await _tap(t, find.byKey(ExpenseSheet.saveKey));
      expect(g.drafts, hasLength(3));
      expect(g.drafts.last.expenseId, isNot(firstId));
      expect(find.text('Expense added'), findsOneWidget);
    });
  });

  group('detail and edit', () {
    Widget detail({ExpenseDetailPage? page, ExpenseList? ctx}) => ExpenseDetailScreen(
          tripId: tripId,
          expenseId: e4,
          initial: page ?? detailPage(),
          context: ctx ?? sheetList(dayToday: 3),
        );

    _tw('detail shows badges, money names, note and history', (t) async {
      registerFakes(list: BuddyOk(sheetList(dayToday: 3)), detail: BuddyOk(detailPage()));
      await _pump(t, detail());
      expect(find.text('Day 3 · 18 May'), findsOneWidget);
      expect(find.text('₹18,500'), findsOneWidget);
      expect(find.text('Booked taxi · Day 3'), findsOneWidget);
      expect(find.text('Edited 1 time'), findsOneWidget);
      expect(find.text('Note: paid in cash at pickup'), findsOneWidget);
      expect(find.text('Rahul changed the amount'), findsOneWidget);
      expect(find.text('Edit history'), findsOneWidget);
      expect(find.byKey(ExpenseDetailScreen.editKey), findsOneWidget);
    });

    _tw('viewer and deleted: no edit, no menu', (t) async {
      final page = detailPage({'deleted': true}, {'canEdit': false, 'canDelete': false});
      registerFakes(list: BuddyOk(sheetList(dayToday: 3)), detail: BuddyOk(page));
      await _pump(t, detail(page: page));
      expect(find.byKey(ExpenseDetailScreen.editKey), findsNothing);
      expect(find.byKey(ExpenseDetailScreen.menuKey), findsNothing);
      expect(find.text('This expense was deleted.'), findsOneWidget);
    });

    _tw('gone: 404 shows the line and Back', (t) async {
      registerFakes(list: BuddyOk(sheetList()), detail: const BuddyRefused(type: BuddyErrorTypes.expenseNotFound, statusCode: 404));
      await _pump(t, const ExpenseDetailScreen(tripId: tripId, expenseId: e4));
      expect(find.text('This expense is gone.'), findsOneWidget);
      expect(find.byKey(ExpenseDetailScreen.backKey), findsOneWidget);
    });

    _tw('edit after payments: box, then save again with ack and a new op id', (t) async {
      final f = registerFakes(list: BuddyOk(sheetList(dayToday: 3)), detail: BuddyOk(detailPage()));
      f.gateway.saveOutcomes.add(refused(BuddyErrorTypes.paymentsNotAcknowledged));
      await _pump(t, detail());
      await _tap(t, find.byKey(ExpenseDetailScreen.editKey));
      expect(find.text('Edit expense'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      _sheet.amountDigits.value = '19100';
      await _settle(t);
      await _tap(t, find.byKey(ExpenseSheet.saveKey));
      expect(find.text('Payments are already made'), findsOneWidget);
      expect(find.textContaining('Aman and Priya are told.'), findsOneWidget);
      await _tap(t, find.text('Save'));
      expect(f.gateway.drafts, hasLength(2));
      expect(f.gateway.drafts.first.body.paymentsAcknowledged, isFalse);
      expect(f.gateway.drafts.last.body.paymentsAcknowledged, isTrue);
      expect(f.gateway.drafts.last.body.baseVersion, 2);
      expect(f.gateway.drafts.last.opId, isNot(f.gateway.drafts.first.opId));
      expect(find.text('Changes saved'), findsOneWidget);
    });

    _tw('left traveller: still sharing can be unticked, removed one is locked', (t) async {
      final ctx = sheetList(dayToday: 3, amanStatus: 'Left');
      final page = detailPage({
        'splitMode': 'Chosen',
        'shares': [
          {'userId': rahul, 'share': 750},
          {'userId': priya, 'share': 750},
        ],
        'amount': 1500,
      });
      registerFakes(list: BuddyOk(ctx), detail: BuddyOk(page));
      await _pump(t, detail(page: page, ctx: ctx));
      await _tap(t, find.byKey(ExpenseDetailScreen.editKey));
      expect(find.text('Left the trip. Cannot be added back.'), findsOneWidget);
      await _tap(t, find.byKey(SplitEditor.rowKey(aman)));
      expect(_sheet.chosen.contains(aman), isFalse);
      expect(_sheet.sharers, [rahul, priya]);
      expect(find.text('₹750 each, shared by 2'), findsOneWidget);
    });

    _tw('conflict: strip, typed values kept; Refresh shows server values and You typed', (t) async {
      final current = {
        ...sample('e4_expense_detail')['expense'] as Map<String, dynamic>,
        'amount': 19000,
        'version': 3,
      };
      final f = registerFakes(list: BuddyOk(sheetList(dayToday: 3)), detail: BuddyOk(detailPage()));
      f.gateway.saveOutcomes.add(refused(BuddyErrorTypes.expenseVersionConflict, data: {'current': current}));
      await _pump(t, detail());
      await _tap(t, find.byKey(ExpenseDetailScreen.editKey));
      _sheet.amountDigits.value = '18000';
      await _settle(t);
      await _tap(t, find.byKey(ExpenseSheet.saveKey));
      expect(find.text('Updated on another device, refresh'), findsOneWidget);
      expect(find.text('₹ 18,000'), findsOneWidget);
      await _tap(t, find.byKey(ExpenseSheet.refreshKey));
      expect(find.text('₹ 19,000'), findsOneWidget);
      expect(find.text('You typed'), findsOneWidget);
      expect(find.text('₹18,000 · Taxi, Suresh (Dzire), full trip'), findsOneWidget);
      expect(_sheet.baseVersion, 3);
      expect(find.text("₹1 left over is added to Rahul's share"), findsOneWidget);
    });

    _tw('delete: payments line on first refusal, second Delete acknowledges', (t) async {
      final f = registerFakes(list: BuddyOk(sheetList(dayToday: 3)), detail: BuddyOk(detailPage()));
      f.gateway.deleteOutcomes.add(refused(BuddyErrorTypes.paymentsNotAcknowledged));
      await _pump(t, detail());
      await _tap(t, find.byKey(ExpenseDetailScreen.menuKey));
      await _tap(t, find.text('Delete'));
      expect(find.text('Delete this expense?'), findsOneWidget);
      expect(find.text('₹18,500 · Taxi, Suresh (Dzire). Shares go down for everyone. History keeps a line.'), findsOneWidget);
      await _tap(t, find.byKey(ExpenseDeleteDialog.deleteKey));
      expect(find.text(ExpenseStrings.deletePayments), findsOneWidget);
      await _tap(t, find.byKey(ExpenseDeleteDialog.deleteKey));
      expect(f.gateway.deletes.map((d) => d.ack), [false, true]);
      expect(f.gateway.deletes.first.baseVersion, 2);
      expect(find.text('Delete this expense?'), findsNothing);
    });

    _tw('delete conflict shows Refresh in the box', (t) async {
      final f = registerFakes(list: BuddyOk(sheetList(dayToday: 3)), detail: BuddyOk(detailPage()));
      f.gateway.deleteOutcomes.add(refused(BuddyErrorTypes.expenseVersionConflict));
      await _pump(t, detail());
      await _tap(t, find.byKey(ExpenseDetailScreen.menuKey));
      await _tap(t, find.text('Delete'));
      await _tap(t, find.byKey(ExpenseDeleteDialog.deleteKey));
      expect(find.text('Updated on another device, refresh'), findsOneWidget);
      await _tap(t, find.byKey(ExpenseDeleteDialog.refreshKey));
      expect(f.api.calls.where((c) => c.startsWith('detail')), isNotEmpty);
      expect(find.text('Updated on another device, refresh'), findsNothing);
    });
  });

  group('late joiner', () {
    _tw('box once; keep calls E6', (t) async {
      final f = registerFakes(list: BuddyOk(lateList()));
      await _pump(t, TripExpensesScreen(tripId: tripId, initial: lateList()));
      expect(find.text('Priya joined'), findsOneWidget);
      expect(find.text('Share earlier expenses with Priya?'), findsOneWidget);
      expect(find.text('3 expenses, ₹9,900 so far'), findsOneWidget);
      await _tap(t, find.byKey(LateJoinerSheet.keepKey));
      expect(f.api.calls, contains('keep:$priya'));
      expect(find.text('Priya joined'), findsNothing);
    });

    _tw('choose: preview with engine shares, notice names, E7 body', (t) async {
      final f = registerFakes(list: BuddyOk(lateList()));
      await _pump(t, TripExpensesScreen(tripId: tripId, initial: lateList()));
      await _tap(t, find.byKey(LateJoinerSheet.chooseKey));
      expect(find.text('Share with Priya'), findsOneWidget);
      expect(find.text('Day 1 · ₹8,000 · Paid by Rahul'), findsOneWidget);
      await _tap(t, find.byKey(ShareEarlierSheet.rowKey(e1)));
      expect(find.text('Snow View Hotel, new shares'), findsOneWidget);
      expect(find.text('₹2,668'), findsOneWidget);
      expect(find.text('₹2,666'), findsNWidgets(2));
      expect(find.text('Aman and Priya will get a notice'), findsOneWidget);
      expect(find.text('Share 1 expense'), findsOneWidget);
      await _tap(t, find.byKey(ShareEarlierSheet.submitKey));
      final body = f.api.shareBodies.single;
      expect(body.userId, priya);
      expect(body.items.single.expenseId, e1);
      expect(body.items.single.baseVersion, 1);
      expect(body.paymentsAcknowledged, isFalse);
      expect(find.text('Shared with Priya'), findsOneWidget);
    });

    _tw('choose: version conflict unticks the row with a red line', (t) async {
      final f = registerFakes(list: BuddyOk(lateList()));
      f.api.shareResults.add(BuddyRefused(type: BuddyErrorTypes.expenseVersionConflict, statusCode: 409, data: {
        'conflicts': [e1],
      }));
      await _pump(t, TripExpensesScreen(tripId: tripId, initial: lateList()));
      await _tap(t, find.byKey(LateJoinerSheet.chooseKey));
      await _tap(t, find.byKey(ShareEarlierSheet.rowKey(e1)));
      await _tap(t, find.byKey(ShareEarlierSheet.submitKey));
      expect(find.text('Updated on another device, refresh'), findsOneWidget);
      expect(find.byKey(ShareEarlierSheet.rowKey(e1)), findsNothing);
    });
  });

  test('gateway seam: refused maps to ExpenseRefused', () {
    final r = refused(BuddyErrorTypes.tripExpensesFrozen);
    expect(r, isA<ExpenseRefused>());
  });
}
