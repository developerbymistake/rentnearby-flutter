import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/owner_core/calendar/models/calendar_models.dart';
import 'package:bakhli/features/owner_core/calendar/owner_upcoming_heading.dart';
import 'package:bakhli/features/owner_core/data/owner_args.dart';
import 'package:bakhli/features/owner_core/data/owner_error_types.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/home/numbers_row.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/plan/owner_inactive.dart';
import 'package:bakhli/features/owner_core/plan/owner_manage_card.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/plan/soft_lock.dart';
import 'package:bakhli/features/owner_core/strings/owner_shared_strings.dart';
import 'package:bakhli/features/stay_owner/widgets/stay_widgets.dart';
import 'package:bakhli/features/taxi_driver/widgets/taxi_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toastification/toastification.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';

const _spec = GateSpec(id: 'g5', title: 'You have 2 room types', body: 'Free keeps 2 room types. Plus keeps 6.', taxi: false);

Widget _page(List<Widget> children) => Scaffold(body: ListView(padding: const EdgeInsets.symmetric(vertical: 16), children: children));

bool _noEllipsis(WidgetTester t) => t.widgetList<Text>(find.byType(Text)).every((w) => w.overflow != TextOverflow.ellipsis);

void main() {
  tearDown(() => PlanGate.debugPlan = null);

  group('OwnerFacts and NumbersRow', () {
    testOwnerSizes(
      'facts both layouts fit',
      () => _page(const [
        OwnerFacts(facts: [NumberTile(value: '3', label: 'Rooms'), NumberTile(value: '₹3,000', label: 'From, per night')]),
        OwnerFacts(labelFirst: true, facts: [
          NumberTile(value: '22 – 23 Nov', label: 'DATES'),
          NumberTile(value: '2 adults, 1 child', label: 'GUESTS'),
          NumberTile(value: 'Family Room', label: 'ROOMS'),
        ]),
      ]),
      check: (t, size, scale) async {
        expect(find.text('From, per night'), findsOneWidget);
        expect(find.text('2 adults, 1 child'), findsOneWidget);
        expect(find.text('GUESTS'), findsOneWidget);
        expect(_noEllipsis(t), isTrue);
      },
    );

    testWidgets('label first puts the label above the value', (t) async {
      await pumpPhone(t, _page(const [OwnerFacts(labelFirst: true, facts: [NumberTile(value: 'Sedan', label: 'CAR')])]));
      expect(t.getTopLeft(find.text('CAR')).dy, lessThan(t.getTopLeft(find.text('Sedan')).dy));
    });

    testWidgets('NumbersRow is one card with dividers and each column taps', (t) async {
      final taps = <String>[];
      await pumpPhone(
        t,
        _page([
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: NumbersRow(tiles: [
              NumberTile(value: '2', label: 'New enquiries', onTap: () => taps.add('new')),
              NumberTile(value: '1', label: 'Offers waiting', onTap: () => taps.add('offers')),
              NumberTile(value: '3', label: 'Confirmed', onTap: () => taps.add('confirmed')),
            ]),
          ),
        ]),
      );
      expect(find.byType(VerticalDivider), findsNWidgets(2));
      expect(find.byType(InkWell), findsNWidgets(3));
      expect(find.descendant(of: find.byType(NumbersRow), matching: find.byType(ClipRRect)), findsOneWidget);
      await t.tap(find.text('Offers waiting'));
      await t.tap(find.text('Confirmed'));
      expect(taps, ['offers', 'confirmed']);
      expect(_noEllipsis(t), isTrue);
    });

    testOwnerSizes(
      'NumbersRow three and four tiles fit',
      () => _page(const [
        NumbersRow(tiles: [NumberTile(value: '12', label: 'New requests'), NumberTile(value: '3', label: 'Missed'), NumberTile(value: '4.8', label: 'Rating')]),
      ]),
    );
  });

  group('plan add rule', () {
    test('addEnabled: off only when full and no upgrade', () {
      PlanGate.debugPlan = OwnerPlans.free;
      expect(PlanGate.addEnabled(false), isTrue);
      expect(PlanGate.addEnabled(true), isTrue);
      PlanGate.debugPlan = OwnerPlans.plus;
      expect(PlanGate.addEnabled(false), isTrue);
      expect(PlanGate.addEnabled(true), isFalse);
      PlanGate.debugPlan = OwnerPlans.paymentOff;
      expect(PlanGate.addEnabled(true), isFalse);
    });

    Widget addButton(bool full, VoidCallback onAdd) => Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => PlanGate.addTap(context, full: full, gate: () => _spec, onAdd: onAdd),
                child: const Text('add'),
              ),
            ),
          ),
        );

    testWidgets('not full: onAdd runs, no sheet', (t) async {
      PlanGate.debugPlan = OwnerPlans.free;
      var added = 0;
      await pumpPhone(t, addButton(false, () => added++));
      await t.tap(find.text('add'));
      await t.pumpAndSettle();
      expect(added, 1);
      expect(find.byKey(GateKeys.sheet), findsNothing);
    });

    testWidgets('full on Free: the Plus sheet opens, onAdd does not run', (t) async {
      PlanGate.debugPlan = OwnerPlans.free;
      var added = 0;
      await pumpPhone(t, addButton(true, () => added++));
      await t.tap(find.text('add'));
      await t.pumpAndSettle();
      expect(added, 0);
      expect(find.byKey(GateKeys.sheet), findsOneWidget);
    });

    testWidgets('full on Plus: nothing happens', (t) async {
      PlanGate.debugPlan = OwnerPlans.plus;
      var added = 0;
      await pumpPhone(t, addButton(true, () => added++));
      await t.tap(find.text('add'));
      await t.pumpAndSettle();
      expect(added, 0);
      expect(find.byKey(GateKeys.sheet), findsNothing);
    });

    testWidgets('plan strip shows on Free only', (t) async {
      PlanGate.debugPlan = OwnerPlans.free;
      await pumpPhone(t, _page([SoftLock.strip(text: 'Free keeps 2 room types. Plus keeps 6.')]));
      expect(find.byKey(GateKeys.planStrip), findsOneWidget);
      expect(find.text(OwnerSharedStrings.seePlus), findsOneWidget);
      PlanGate.debugPlan = OwnerPlans.plus;
      await pumpPhone(t, _page([SoftLock.strip(text: 'Free keeps 2 room types. Plus keeps 6.', taxi: true)]));
      expect(find.byKey(GateKeys.planStrip), findsNothing);
    });
  });

  group('inactive rows', () {
    testWidgets('OwnerInactive shows the reason and Delete; the row itself does not tap', (t) async {
      var opened = 0;
      var deleted = 0;
      await pumpPhone(
        t,
        _page([
          OwnerInactive(
            reason: 'Inactive: the Free plan allows 2 room types.',
            onDelete: () => deleted++,
            child: OwnerManageCard(
              eyebrow: 'ROOM 3',
              chip: '4 guests',
              title: 'Family Room',
              sub: '₹3,000 / night',
              actions: [WhitePillButton(tone: ListingTone.forest, label: 'Edit room', height: 42, fontSize: 12.5, onTap: () => opened++)],
            ),
          ),
        ]),
      );
      expect(find.byKey(GateKeys.inactiveRow), findsOneWidget);
      expect(find.text('Inactive: the Free plan allows 2 room types.'), findsOneWidget);
      await t.tap(find.text('Edit room'), warnIfMissed: false);
      await t.tap(find.text(OwnerSharedStrings.delete));
      expect(opened, 0);
      expect(deleted, 1);
    });

    testWidgets('busy OwnerInactive does not delete twice', (t) async {
      var deleted = 0;
      await pumpPhone(t, _page([OwnerInactive(reason: 'Inactive', busy: true, taxi: true, onDelete: () => deleted++, child: const Text('row'))]));
      await t.tap(find.text(OwnerSharedStrings.delete));
      expect(deleted, 0);
    });

    testWidgets('handleInactive toasts only the inactive refusal', (t) async {
      await pumpPhone(t, _page(const [Text('page')]), toastHost: true);
      const other = BuddyRefused<void>(type: 'StaleEdit', statusCode: 409);
      expect(PlanGate.handleInactive(other), isFalse);
      const inactive = BuddyRefused<void>(type: OwnerErrorTypes.planRowInactive, statusCode: 409);
      expect(PlanGate.handleInactive(inactive), isTrue);
      await t.pump();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text(OwnerSharedStrings.inactiveToast), findsOneWidget);
      await t.pump(const Duration(seconds: 6));
      toastification.dismissAll(delayForAnimation: false);
      await t.pump(const Duration(seconds: 1));
      expect(OwnerErrorTypes.limitTypes.contains(OwnerErrorTypes.planRowInactive), isFalse);
    });

    test('CalendarEntry reads inactiveByPlan, default false', () {
      final on = CalendarEntry.fromJson({'id': 'e1', 'kind': 'Manual', 'dateFrom': '2026-11-28', 'inactiveByPlan': true});
      final off = CalendarEntry.fromJson({'id': 'e2', 'kind': 'Manual', 'dateFrom': '2026-11-28'});
      expect(on.inactiveByPlan, isTrue);
      expect(off.inactiveByPlan, isFalse);
    });

    test('OwnerArgs.manage marks the manage page', () {
      expect(OwnerArgs.isManage(OwnerArgs.manage), isTrue);
      expect(OwnerArgs.isManage(null), isFalse);
      expect(OwnerArgs.isManage(const {'manage': false}), isFalse);
    });
  });

  group('role widgets', () {
    testWidgets('StayHeroCard without body keeps the gradient card', (t) async {
      await pumpPhone(t, _page([StayHeroCard(tone: ListingTone.forest, art: ListingArt.stay, title: 'Deodar Heights', pill: 'LIVE', line: 'Accepting guests', trailing: const Text('switch'))]));
      expect(find.text('Accepting guests'), findsOneWidget);
      expect(find.text('switch'), findsOneWidget);
      expect(find.descendant(of: find.byType(StayHeroCard), matching: find.byType(ClipRRect)), findsNothing);
    });

    testOwnerSizes(
      'StayHeroCard with body draws the band and the white body',
      () => _page([
        StayHeroCard(
          tone: ListingTone.forest,
          art: ListingArt.stay,
          title: 'Deodar Heights',
          pill: 'LIVE',
          line: 'Accepting guests',
          trailing: const SizedBox(width: 48, height: 28),
          body: const OwnerFacts(facts: [NumberTile(value: '2', label: 'Rooms'), NumberTile(value: '₹3,000', label: 'From, per night')]),
        ),
      ]),
      check: (t, size, scale) async {
        expect(find.descendant(of: find.byType(StayHeroCard), matching: find.byType(ClipRRect)), findsOneWidget);
        expect(t.getTopLeft(find.text('Rooms')).dy, greaterThan(t.getBottomLeft(find.text('Accepting guests')).dy));
      },
    );

    testWidgets('StayDeleteRow and TaxiDeleteRow tap Delete', (t) async {
      final taps = <String>[];
      await pumpPhone(
        t,
        _page([
          StayDeleteRow(title: 'Delete stay', sub: 'Remove this listing', busy: false, onDelete: () => taps.add('stay')),
          TaxiDeleteRow(title: 'Delete taxi', sub: 'Remove this listing', busy: false, onDelete: () => taps.add('taxi')),
        ]),
      );
      await t.tap(find.text(OwnerSharedStrings.delete).first);
      await t.tap(find.text(OwnerSharedStrings.delete).last);
      expect(taps, ['stay', 'taxi']);
    });

    testWidgets('busy delete rows do not tap', (t) async {
      var n = 0;
      await pumpPhone(t, _page([StayDeleteRow(title: 'Delete stay', sub: 'Remove this listing', busy: true, onDelete: () => n++)]));
      await t.tap(find.text('Delete stay'));
      await t.tap(find.text(OwnerSharedStrings.delete));
      expect(n, 0);
    });

    testWidgets('TaxiStatusCard draws the body under the band', (t) async {
      await pumpPhone(
        t,
        _page([
          TaxiStatusCard(
            tone: ListingTone.coral,
            art: ListingArt.stay,
            title: 'Swift Dzire',
            line: 'Online',
            body: const OwnerFacts(facts: [NumberTile(value: '1', label: 'Route')]),
            note: 'note',
          ),
        ]),
      );
      expect(t.getTopLeft(find.text('Route')).dy, greaterThan(t.getTopLeft(find.text('Online')).dy));
      expect(t.getTopLeft(find.text('note')).dy, greaterThan(t.getTopLeft(find.text('Route')).dy));
    });

    testWidgets('TaxiRail shows three tiles in one row', (t) async {
      await pumpPhone(
        t,
        _page([
          TaxiRail(tiles: [
            TaxiRailTile(tone: ListingTone.coral, art: ListingArt.stay, title: 'Edit fares', sub: 'Routes', onTap: () {}),
            TaxiRailTile(tone: ListingTone.sunrise, art: ListingArt.stay, title: 'Ready check', sub: 'Phone', onTap: () {}),
            TaxiRailTile(tone: ListingTone.indigo, art: ListingArt.stay, title: 'My rating', sub: 'Stars', onTap: () {}),
          ]),
        ]),
      );
      expect(find.byType(MealsRail), findsOneWidget);
      final y = t.getTopLeft(find.text('Edit fares')).dy;
      expect(t.getTopLeft(find.text('My rating')).dy, y);
    });

    testWidgets('OwnerUpcomingHeading See all taps', (t) async {
      var n = 0;
      await pumpPhone(t, _page([OwnerUpcomingHeading(title: 'Upcoming bookings', sub: 'next 15 days', seeAll: 'See all', onSeeAll: () => n++, linkColor: DesignColors.primary)]));
      expect(find.text('next 15 days'), findsOneWidget);
      await t.tap(find.text('See all ›'));
      expect(n, 1);
    });

    test('card corners are capped at 36', () {
      expect(StayLook.cardRadius(68).topRight.x, StayLook.cardRadius(36).topRight.x);
      expect(TaxiLook.cardRadius(54).topRight.x, TaxiLook.cardRadius(36).topRight.x);
      expect(StayLook.cardRadius(20).topRight.x, lessThan(StayLook.cardRadius(36).topRight.x));
    });
  });
}
