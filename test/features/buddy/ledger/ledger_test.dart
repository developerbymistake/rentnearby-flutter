import 'dart:async';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/buddy/buddy_error_types.dart';
import 'package:bakhli/features/buddy/buddy_live.dart';
import 'package:bakhli/features/buddy/ledger/controllers/money_summary_controller.dart';
import 'package:bakhli/features/buddy/ledger/controllers/trip_balances_controller.dart';
import 'package:bakhli/features/buddy/ledger/data/ledger_api.dart';
import 'package:bakhli/features/buddy/ledger/ledger_deps.dart';
import 'package:bakhli/features/buddy/ledger/ledger_rules.dart';
import 'package:bakhli/features/buddy/ledger/models/ledger_models.dart';
import 'package:bakhli/features/buddy/ledger/screens/money_summary_screen.dart';
import 'package:bakhli/features/buddy/ledger/screens/settle_up_screen.dart';
import 'package:bakhli/features/buddy/ledger/widgets/balances_view.dart';
import 'package:bakhli/features/buddy/ledger/widgets/booking_expense_line.dart';
import 'package:bakhli/features/buddy/ledger/widgets/day_spent_chip.dart';
import 'package:bakhli/features/buddy/ledger/widgets/expense_state_banner.dart';
import 'package:bakhli/features/buddy/ledger/widgets/ledger_menu.dart';
import 'package:bakhli/features/buddy/ledger/widgets/viewer_money_card.dart';
import 'package:bakhli/features/buddy/ledger/widgets/who_pays_card.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_snack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'ledger_fixtures.dart';

Future<void> _settle(WidgetTester t, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f.first);
  await t.tap(f.first);
  await _settle(t);
}

Widget _scroll(List<Widget> children) => Scaffold(body: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)));

Future<void> _pump(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.7;
  addTearDown(t.view.reset);
  await t.pumpWidget(app(w));
  await _settle(t);
}

Future<void> _drain(WidgetTester t) async {
  BuddySnack.hide();
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 6));
}

class _GatedApi extends FakeLedgerApi {
  _GatedApi(super.answers);

  Completer<BuddyResult<TripBalances>>? gate;

  @override
  Future<BuddyResult<TripBalances>> balances(String tripId) {
    final g = gate;
    if (g == null) return super.balances(tripId);
    gate = null;
    balanceCalls++;
    return g.future;
  }
}

void main() {
  var op = 0;
  setUp(() {
    op = 0;
    opened.clear();
    LedgerDeps.newOpId = () => 'op-${++op}';
  });
  tearDown(() {
    LedgerDeps.debugReset();
    Get.reset();
  });

  group('LedgerRules', () {
    test('net labels and tones', () {
      expect(LedgerRules.netLabel(18182), 'Gets back ₹18,182');
      expect(LedgerRules.netLabel(-11816), 'Owes ₹11,816');
      expect(LedgerRules.netLabel(0), 'All square');
      expect(LedgerRules.settleHeroLabel(-5), 'You owe');
    });

    test('viewer hero table', () {
      expect(LedgerRules.viewerHero(viewer410()).kind, ViewerHeroKind.youOwe);
      expect(LedgerRules.viewerHero(viewer410()).label, 'You owe Rahul 1736');
      expect(LedgerRules.viewerHero(viewer410()).showPaid, isTrue);
      final w = LedgerRules.viewerHero(viewer410(state: 'SaidPaid'));
      expect((w.kind, w.label, w.bannerText, w.showNotPaid), (ViewerHeroKind.paidWaiting, 'Paid to Rahul', 'You said paid. Waiting for Rahul to confirm.', true));
      expect(LedgerRules.viewerHero(viewer410c()).kind, ViewerHeroKind.nothingToPay);
      expect(LedgerRules.viewerHero(viewer410c()).bannerText, isNull);
      expect(LedgerRules.viewerHero(viewer410c(), race: LedgerRace.nothingLeft).bannerText, 'Nothing left to pay. You are all square.');
      final e = LedgerRules.viewerHero(viewer410e());
      expect((e.kind, e.label, e.amount), (ViewerHeroKind.owedToYou, 'Owed to you', 1000));
      final nr = LedgerRules.viewerHero(viewer410(afterNotReceived: '2026-05-20T07:00:00Z'));
      expect(nr.bannerText, 'Rahul has not got it yet. Check and try again.');
      final ch = LedgerRules.viewerHero(viewer410(amount: 11616, share: 12616), race: LedgerRace.amountChanged);
      expect(ch.bannerText, 'The amount changed to ₹11,616. Check and confirm again.');
      final sq = LedgerRules.viewerHero(viewerReceived());
      expect((sq.kind, sq.label, sq.bannerText, sq.showPaid), (ViewerHeroKind.paidSquare, 'Paid to Rahul', 'Rahul got it. You are all square.', false));
    });

    test('row subtitles and lines', () {
      final b = owner415a();
      final edit = b.payments.firstWhere((r) => r.afterEdit);
      expect(LedgerRules.subtitle(edit, b.reopened), 'Taxi changed, 24 May');
      final rec = b.payments.firstWhere((r) => r.isReceived);
      expect(LedgerRules.subtitle(rec, b.reopened), 'Paid 19 May');
      expect(LedgerRules.markedLine(b, rec), 'Marked by you, 23 May');
      expect(LedgerRules.openAgain(b), 2);
      expect(LedgerRules.subtitle(owner49().payments[1], null), 'Not paid yet');
      expect(LedgerRules.shortTitle('Taxi, Suresh (Dzire), full trip'), 'Taxi');
    });
  });

  group('Owner balances (4.9)', () {
    testWidgets('people card and who pays whom', (t) async {
      registerLedger([BuddyOk(owner49())]);
      await _pump(t, _scroll([const BalancesView(tripId: tripId)]));
      for (final s in ['Gets back ₹18,182', 'Owes ₹11,816', 'Owes ₹6,366', 'Paid ₹29,800 · Share ₹11,618', 'WHO PAYS WHOM', 'Paid 19 May', 'Not paid yet', 'Says paid', 'Open', 'Not received', 'Mark as received', 'Send a reminder', '₹11,816', '₹6,366']) {
        expect(find.textContaining(s, findRichText: true), findsWidgets, reason: s);
      }
      expect(find.text('I have paid'), findsNothing);
      await _drain(t);
    });

    testWidgets('4.9a Mark as received asks, Not yet closes, Yes records and snacks', (t) async {
      final api = registerLedger([BuddyOk(owner49())]);
      await _pump(t, _scroll([const BalancesView(tripId: tripId)]));
      await _tap(t, find.text('Mark as received'));
      expect(find.text('Mark ₹11,816 as received?'), findsOneWidget);
      expect(find.text('Tap Yes only when the money is in your account. Aman is told. This cannot be switched back.'), findsOneWidget);
      await _tap(t, find.text('Not yet'));
      expect(api.calls, isEmpty);
      api.answer(BuddyOk(owner414()));
      final before = api.balanceCalls;
      await _tap(t, find.text('Mark as received'));
      await _tap(t, find.text('Yes, received'));
      expect(api.calls, ['received:$payId']);
      expect(api.balanceCalls, before + 1);
      expect(find.text('Marked as received from Aman'), findsOneWidget);
      expect(find.byType(ReceivedBadge), findsOneWidget);
      expect(find.text('Marked by you, 23 May'), findsOneWidget);
      await _drain(t);
    });

    testWidgets('4.9b changed while confirming shows the red line and new numbers', (t) async {
      final api = registerLedger([BuddyOk(owner49())]);
      await _pump(t, _scroll([const BalancesView(tripId: tripId)]));
      api.writeResult = refused(BuddyErrorTypes.paymentStateChanged);
      api.answer(BuddyOk(owner49b()));
      await _tap(t, find.text('Mark as received'));
      await _tap(t, find.text('Yes, received'));
      expect(find.text('This payment changed. Check it again.'), findsOneWidget);
      expect(find.text('Owes ₹11,616'), findsOneWidget);
      expect(find.text('Send a reminder'), findsNWidgets(2));
      expect(find.text('Marked as received from Aman'), findsNothing);
      await TripBalancesController.of(tripId).reload();
      await _settle(t);
      expect(find.text('This payment changed. Check it again.'), findsNothing);
      await _drain(t);
    });

    testWidgets('4.9c two Amans keep their digits', (t) async {
      registerLedger([BuddyOk(owner49(twoAmans: true))]);
      await _pump(t, _scroll([const BalancesView(tripId: tripId)]));
      expect(find.textContaining('4419', findRichText: true), findsWidgets);
      expect(find.textContaining('8275', findRichText: true), findsWidgets);
      await _drain(t);
    });

    testWidgets('4.9d Not received asks then reopens the row', (t) async {
      final api = registerLedger([BuddyOk(owner49(twoAmans: true))]);
      await _pump(t, _scroll([const BalancesView(tripId: tripId)]));
      await _tap(t, find.text('Not received'));
      expect(find.text('Not received yet?'), findsOneWidget);
      expect(find.text('Aman 8275 said he paid ₹11,816. The payment opens again and Aman is asked to check.'), findsOneWidget);
      await _tap(t, find.text('Cancel'));
      expect(api.calls, isEmpty);
      api.answer(BuddyOk(owner49b()));
      await _tap(t, find.text('Not received'));
      await _tap(t, find.text('Not received').last);
      expect(api.calls, ['notReceived:$payId']);
      expect(find.text('Says paid'), findsNothing);
      await _drain(t);
    });

    testWidgets('Send a reminder turns off for today', (t) async {
      final api = registerLedger([BuddyOk(owner49())]);
      await _pump(t, _scroll([const BalancesView(tripId: tripId)]));
      await _tap(t, find.text('Send a reminder'));
      expect(api.calls, ['remind:$priya']);
      expect(find.text('Reminder sent to Priya'), findsOneWidget);
      expect(find.text('Reminder sent'), findsOneWidget);
      await _tap(t, find.text('Reminder sent'));
      expect(api.calls.length, 1);
      await _drain(t);
    });

    testWidgets('ReminderAlreadySent shows the off state', (t) async {
      final api = registerLedger([BuddyOk(owner49())]);
      api.remindResult = refused(BuddyErrorTypes.reminderAlreadySent);
      await _pump(t, _scroll([const BalancesView(tripId: tripId)]));
      await _tap(t, find.text('Send a reminder'));
      expect(find.text('Reminder sent'), findsOneWidget);
      await _drain(t);
    });

    testWidgets('4.9e owner pays a viewer: I have paid on his own row, no reminder', (t) async {
      final api = registerLedger([BuddyOk(owner49e())]);
      await _pump(t, _scroll([const BalancesView(tripId: tripId)]));
      expect(find.text('Send a reminder'), findsNothing);
      await _tap(t, find.text('I have paid'));
      expect(find.text('Have you paid ₹500?'), findsOneWidget);
      expect(find.text('Tap Yes only after you have sent the money to Priya. You can take it back until it is marked as received.'), findsOneWidget);
      await _tap(t, find.text('Yes, I paid'));
      expect(api.calls, ['saidPaid:$priya:500']);
      expect(api.opIds, ['op-1']);
      await _drain(t);
    });

    testWidgets('4.9f receiver is a viewer: the box names her', (t) async {
      registerLedger([BuddyOk(owner49e())]);
      await _pump(t, _scroll([const BalancesView(tripId: tripId)]));
      await _tap(t, find.text('Mark as received'));
      expect(find.text('Mark ₹500 as received by Priya?'), findsOneWidget);
      expect(find.text('Tap Yes only when Priya has the money. Aman is told. This cannot be switched back.'), findsOneWidget);
      await _tap(t, find.text('Not yet'));
      await _drain(t);
    });

    testWidgets('nothing yet, all settled, failure and gone states', (t) async {
      final api = registerLedger([BuddyOk(viewer410c())]);
      await _pump(t, _scroll([const BalancesView(tripId: tripId)]));
      expect(find.text('Nothing to settle yet'), findsNothing);
      api.answer(BuddyOk(balances(me: rahul, people: [balanceOf(rahul, rahul, 0, 0)], payments: const [])));
      await TripBalancesController.of(tripId).reload();
      await TripBalancesController.of(tripId).reload();
      await _settle(t);
      expect(find.text('Nothing to settle yet'), findsOneWidget);
      api.answer(BuddyOk(owner414(allDone: true)));
      await TripBalancesController.of(tripId).reload();
      await TripBalancesController.of(tripId).reload();
      await _settle(t);
      expect(find.text('All settled'), findsOneWidget);
      await _drain(t);
      Get.reset();
      registerLedger([const BuddyFailed(message: 'x')]);
      await _pump(t, _scroll([const BalancesView(tripId: tripId)]));
      expect(find.text('Could not load'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await _drain(t);
      Get.reset();
      registerLedger([refused(BuddyErrorTypes.tripNotFound, status: 404)]);
      await _pump(t, _scroll([const BalancesView(tripId: tripId)]));
      expect(find.text('This trip is no longer available'), findsOneWidget);
      await _drain(t);
    });

    testWidgets('a live tick reloads E8', (t) async {
      final api = registerLedger([BuddyOk(owner49())]);
      await _pump(t, _scroll([const BalancesView(tripId: tripId)]));
      final n = api.balanceCalls;
      BuddyLive.expenses(tripId).value++;
      await _settle(t);
      expect(api.balanceCalls, n + 1);
      await _drain(t);
    });
  });

  group('Viewer card (4.10 to 4.12c)', () {
    Widget viewer() => _scroll([const ViewerMoneyCard(tripId: tripId), const BalancesView(tripId: tripId)]);

    testWidgets('4.10 hero, 4.10a box, Yes records with an op id', (t) async {
      final api = registerLedger([BuddyOk(viewer410())]);
      await _pump(t, viewer());
      expect(find.text('You owe Rahul 1736'), findsOneWidget);
      expect(find.text('₹12,816'), findsOneWidget);
      expect(find.text('Your share'), findsOneWidget);
      expect(find.text('You paid'), findsOneWidget);
      expect(find.text('WHO PAYS WHOM'), findsNothing);
      await _tap(t, find.byKey(ViewerMoneyCard.paidKey));
      expect(find.text('Have you paid ₹11,816?'), findsOneWidget);
      expect(find.text('Tap Yes only after you have sent the money to Rahul. Rahul is told and confirms. You can take it back until Rahul confirms.'), findsOneWidget);
      await _tap(t, find.text('Not yet'));
      expect(api.calls, isEmpty);
      api.answer(BuddyOk(viewer410(state: 'SaidPaid')));
      await _tap(t, find.byKey(ViewerMoneyCard.paidKey));
      await _tap(t, find.text('Yes, I paid'));
      expect(api.calls, ['saidPaid:$rahul:11816']);
      expect(find.text('Paid to Rahul'), findsOneWidget);
      expect(find.text('You said paid. Waiting for Rahul to confirm.'), findsOneWidget);
      expect(find.byKey(ViewerMoneyCard.paidKey), findsNothing);
      expect(find.byKey(ViewerMoneyCard.notPaidKey), findsOneWidget);
      await _drain(t);
    });

    testWidgets('offline keeps the op id for the retry; double tap opens one box', (t) async {
      final api = registerLedger([BuddyOk(viewer410())]);
      api.writeResult = const BuddyOffline();
      await _pump(t, viewer());
      await t.tap(find.byKey(ViewerMoneyCard.paidKey));
      await t.tap(find.byKey(ViewerMoneyCard.paidKey), warnIfMissed: false);
      await _settle(t);
      expect(find.text('Have you paid ₹11,816?'), findsOneWidget);
      await _tap(t, find.text('Yes, I paid'));
      await _tap(t, find.byKey(ViewerMoneyCard.paidKey));
      api.writeResult = const BuddyOk(PaymentWriteResponse(balancesVersion: 9));
      await _tap(t, find.text('Yes, I paid'));
      expect(api.opIds, ['op-1', 'op-1']);
      await _drain(t);
    });

    testWidgets('4.10b amount changed: nothing recorded, banner with the new amount', (t) async {
      final api = registerLedger([BuddyOk(viewer410())]);
      await _pump(t, viewer());
      api.writeResult = refused(BuddyErrorTypes.balancesChanged);
      api.answer(BuddyOk(viewer410(amount: 11616, share: 12616)));
      await _tap(t, find.byKey(ViewerMoneyCard.paidKey));
      await _tap(t, find.text('Yes, I paid'));
      expect(find.text('The amount changed to ₹11,616. Check and confirm again.'), findsOneWidget);
      expect(find.text('₹11,616'), findsWidgets);
      await _tap(t, find.byKey(ViewerMoneyCard.paidKey));
      expect(find.text('Have you paid ₹11,616?'), findsOneWidget);
      await _tap(t, find.text('Not yet'));
      await _drain(t);
    });

    testWidgets('4.10c NothingToPay: no buttons and the all square line', (t) async {
      final api = registerLedger([BuddyOk(viewer410())]);
      await _pump(t, viewer());
      api.writeResult = refused(BuddyErrorTypes.nothingToPay);
      api.answer(BuddyOk(viewer410c()));
      await _tap(t, find.byKey(ViewerMoneyCard.paidKey));
      await _tap(t, find.text('Yes, I paid'));
      expect(find.text('Nothing to pay'), findsOneWidget);
      expect(find.text('₹0'), findsOneWidget);
      expect(find.text('Nothing left to pay. You are all square.'), findsOneWidget);
      expect(find.byKey(ViewerMoneyCard.paidKey), findsNothing);
      await _drain(t);
    });

    testWidgets('4.10e owed viewer: rows read pays you, no buttons', (t) async {
      registerLedger([BuddyOk(viewer410e())]);
      await _pump(t, viewer());
      expect(find.text('Owed to you'), findsOneWidget);
      expect(find.text('Rahul pays you ₹500'), findsOneWidget);
      expect(find.text('Aman pays you ₹500'), findsOneWidget);
      expect(find.text('Aman says paid. Rahul will mark it as received.'), findsOneWidget);
      expect(find.text('Paid 17 May'), findsOneWidget);
      for (final s in ['I have paid', 'Not paid', 'Mark as received', 'Send a reminder', 'Not received']) {
        expect(find.text(s), findsNothing, reason: s);
      }
      await _drain(t);
    });

    testWidgets('4.12b Not paid asks, Keep it closes, Not paid withdraws', (t) async {
      final api = registerLedger([BuddyOk(viewer410(state: 'SaidPaid'))]);
      await _pump(t, viewer());
      await _tap(t, find.byKey(ViewerMoneyCard.notPaidKey));
      expect(find.text('Mark as not paid?'), findsOneWidget);
      expect(find.text('Use this if the money did not go. Rahul is told and the payment opens again.'), findsOneWidget);
      await _tap(t, find.text('Keep it'));
      expect(api.calls, isEmpty);
      api.answer(BuddyOk(viewer410()));
      await _tap(t, find.byKey(ViewerMoneyCard.notPaidKey));
      await _tap(t, find.text('Not paid').last);
      expect(api.calls, ['withdraw:$payId']);
      expect(find.byKey(ViewerMoneyCard.paidKey), findsOneWidget);
      await _drain(t);
    });

    testWidgets('4.12c after Not received: red line and I have paid again', (t) async {
      registerLedger([BuddyOk(viewer410(afterNotReceived: '2026-05-20T07:00:00Z'))]);
      await _pump(t, viewer());
      expect(find.text('You owe Rahul 1736'), findsOneWidget);
      expect(find.text('Rahul has not got it yet. Check and try again.'), findsOneWidget);
      expect(find.byKey(ViewerMoneyCard.paidKey), findsOneWidget);
      await _drain(t);
    });

    testWidgets('received: all square line, no button', (t) async {
      registerLedger([BuddyOk(viewerReceived())]);
      await _pump(t, viewer());
      expect(find.text('Rahul got it. You are all square.'), findsOneWidget);
      expect(find.byKey(ViewerMoneyCard.paidKey), findsNothing);
      expect(find.byKey(ViewerMoneyCard.notPaidKey), findsNothing);
      await _drain(t);
    });
  });

  group('Settle up and summary', () {
    testWidgets('4.14 settle up page, menu', (t) async {
      registerLedger([BuddyOk(owner414())]);
      await _pump(t, const SettleUpScreen(tripId: tripId));
      for (final s in ['Settle up', 'Uttarakhand Hills Trip · ended 22 May', 'Trip finished. 1 payment to settle.', 'You get back', '₹18,182', 'Received', 'Still open', 'PAYMENTS · 1 OF 2 DONE', 'Marked by you, 23 May', 'Send a reminder']) {
        expect(find.textContaining(s, findRichText: true), findsWidgets, reason: s);
      }
      await _tap(t, find.byKey(LedgerMenu.dotsKey));
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Trip summary'), findsOneWidget);
      await _tap(t, find.text('Trip summary'));
      expect(opened.single.$1, AppRoutes.tripMoneySummary);
      await _drain(t);
    });

    testWidgets('all settled shows the banner and a Trip summary button', (t) async {
      registerLedger([BuddyOk(owner414(allDone: true))]);
      await _pump(t, const SettleUpScreen(tripId: tripId));
      expect(find.text('All settled'), findsOneWidget);
      await _tap(t, find.byKey(SettleUpScreen.summaryKey));
      expect(opened.single.$1, AppRoutes.tripMoneySummary);
      await _drain(t);
    });

    testWidgets('4.15a reopened after an edit', (t) async {
      registerLedger([BuddyOk(owner415a())]);
      await _pump(t, const SettleUpScreen(tripId: tripId));
      expect(find.text('Expenses changed. 2 payments open again.'), findsOneWidget);
      expect(find.text('Taxi changed, 24 May'), findsNWidgets(2));
      expect(find.text('PAYMENTS · 2 OF 4 DONE'), findsOneWidget);
      await _drain(t);
    });

    testWidgets('4.15b frozen: banner, actions still work', (t) async {
      final api = registerLedger([BuddyOk(owner415b())]);
      await _pump(t, _scroll([const ExpenseStateBanner(tripId: tripId), const BalancesView(tripId: tripId)]));
      expect(find.text('This trip is closed for changes.'), findsOneWidget);
      expect(find.text('Paid 22 Jun'), findsOneWidget);
      await _tap(t, find.text('Send a reminder'));
      expect(api.calls, ['remind:$priya']);
      await _drain(t);
    });

    testWidgets('4.15 summary: settled, categories, no export', (t) async {
      registerLedger([BuddyOk(owner414())]);
      await _pump(t, const MoneySummaryScreen(tripId: tripId));
      for (final s in ['Trip summary', '16 – 22 May · 7 days · 3 travellers', 'All settled', 'No payments left', 'Total spent', '₹32,300', 'By category', 'Taxi', 'Stay', 'Food', 'Other', 'Tickets', '₹18,500', 'Plan the next trip with the same travellers']) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      expect(find.text('Download sheet'), findsNothing);
      expect(find.text('Share summary'), findsNothing);
      var planned = 0;
      LedgerDeps.openPlanATrip = () => planned++;
      await _tap(t, find.byKey(MoneySummaryScreen.planKey));
      expect(planned, 1);
      await _drain(t);
    });

    testWidgets('4.15 summary with open payments offers Settle up', (t) async {
      registerLedger([BuddyOk(owner414())], summary: BuddyOk(summarySample(settled: false, open: 2)));
      await _pump(t, const MoneySummaryScreen(tripId: tripId));
      expect(find.text('2 payments open'), findsOneWidget);
      await _tap(t, find.byKey(MoneySummaryScreen.settleKey));
      expect(opened.single.$1, AppRoutes.tripSettle);
      await _drain(t);
    });
  });

  group('4.16 day chip and booking line', () {
    testWidgets('chip per day, booking totals, one E17 call', (t) async {
      final api = registerLedger([BuddyOk(owner49())]);
      await _pump(
        t,
        _scroll([
          const DaySpentChip(tripId: tripId, day: 3),
          const DaySpentChip(tripId: tripId, day: 4),
          const DaySpentChip(tripId: tripId, day: 7),
          const BookingExpenseLine(tripId: tripId, kind: 'Taxi', id: 'd0000000-0000-4000-8000-000000000002'),
          const BookingExpenseLine(tripId: tripId, kind: 'Stay', id: 'd0000000-0000-4000-8000-000000000001'),
          const BookingExpenseLine(tripId: tripId, kind: 'Stay', id: 'nope'),
        ]),
      );
      expect(api.summaryCalls, 1);
      expect(find.text('Spent ₹20,000 →'), findsOneWidget);
      expect(find.text('Spent ₹2,400 →'), findsOneWidget);
      expect(find.byKey(DaySpentChip.keyOf(7)), findsNothing);
      expect(find.text('In expenses'), findsNWidgets(2));
      expect(find.text('₹18,500'), findsOneWidget);
      expect(find.text('₹8,000'), findsOneWidget);
      int? openedDay;
      LedgerDeps.openExpenses = (id, {String? tab, int? day}) => openedDay = day;
      await _tap(t, find.text('Spent ₹20,000 →'));
      expect(openedDay, 3);
      await t.pumpWidget(const SizedBox.shrink());
      expect(Get.isRegistered<MoneySummaryController>(tag: 'summary:$tripId'), isFalse);
      await _drain(t);
    });

    testWidgets('a failure shows nothing', (t) async {
      registerLedger([BuddyOk(owner49())], summary: const BuddyFailed(message: 'x'));
      await _pump(t, _scroll([const DaySpentChip(tripId: tripId, day: 3), const BookingExpenseLine(tripId: tripId, kind: 'Taxi', id: 'x')]));
      expect(find.textContaining('Spent'), findsNothing);
      expect(find.text('In expenses'), findsNothing);
      await _drain(t);
    });
  });

  group('Verifier: races', () {
    testWidgets('an action waits out a reload already in flight and then loads fresh', (t) async {
      final api = _GatedApi([BuddyOk(owner49())]);
      Get.put<LedgerApi>(api);
      await _pump(t, _scroll([const BalancesView(tripId: tripId)]));
      final gate = Completer<BuddyResult<TripBalances>>();
      api.gate = gate;
      BuddyLive.expenses(tripId).value++;
      await _settle(t, 2);
      api.answer(BuddyOk(owner414()));
      await _tap(t, find.text('Mark as received'));
      await _tap(t, find.text('Yes, received'));
      expect(api.calls, ['received:$payId']);
      gate.complete(BuddyOk(owner49()));
      await _settle(t);
      expect(find.byType(ReceivedBadge), findsOneWidget);
      expect(find.text('Mark as received'), findsNothing);
      await _drain(t);
    });

    testWidgets('a failed answer keeps the op id for the retry', (t) async {
      final api = registerLedger([BuddyOk(viewer410())]);
      api.writeResult = const BuddyFailed(message: 'x');
      await _pump(t, _scroll([const ViewerMoneyCard(tripId: tripId)]));
      await _tap(t, find.byKey(ViewerMoneyCard.paidKey));
      await _tap(t, find.text('Yes, I paid'));
      api.writeResult = const BuddyOk(PaymentWriteResponse(balancesVersion: 9));
      await _tap(t, find.byKey(ViewerMoneyCard.paidKey));
      await _tap(t, find.text('Yes, I paid'));
      expect(api.opIds, ['op-1', 'op-1']);
      await _drain(t);
    });

    testWidgets('Not paid after the owner marked it received: toast and the server state', (t) async {
      final api = registerLedger([BuddyOk(viewer410(state: 'SaidPaid'))]);
      await _pump(t, _scroll([const ViewerMoneyCard(tripId: tripId)]));
      api.writeResult = refused(BuddyErrorTypes.paymentStateChanged);
      api.answer(BuddyOk(viewerReceived()));
      await _tap(t, find.byKey(ViewerMoneyCard.notPaidKey));
      await _tap(t, find.text('Not paid').last);
      expect(api.calls, ['withdraw:$payId']);
      expect(find.text('Rahul already marked it as received.'), findsOneWidget);
      expect(find.text('Rahul got it. You are all square.'), findsOneWidget);
      expect(find.byKey(ViewerMoneyCard.notPaidKey), findsNothing);
      await _drain(t);
    });

    testWidgets('a viewer on Settle up sees only his own action', (t) async {
      registerLedger([BuddyOk(viewer410())]);
      await _pump(t, const SettleUpScreen(tripId: tripId));
      expect(find.text('I have paid'), findsOneWidget);
      for (final s in ['Mark as received', 'Not received', 'Send a reminder']) {
        expect(find.text(s), findsNothing, reason: s);
      }
      await _drain(t);
    });
  });
}
