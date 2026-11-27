import 'dart:io';

import 'package:bakhli/features/buddy/notices/models/notice_models.dart';
import 'package:bakhli/features/owner_core/plan/plan_card_state.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/plan/plan_keys.dart';
import 'package:bakhli/features/stay_owner/notices/stay_notice_copy.dart';
import 'package:bakhli/features/stay_owner/plan/stay_plan_copy.dart';
import 'package:bakhli/features/stay_owner/plan/stay_plan_strings.dart';
import 'package:bakhli/features/taxi_driver/notices/taxi_notice_copy.dart';
import 'package:bakhli/features/taxi_driver/plan/taxi_plan_copy.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/plan_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/owner_fakes.dart';
import 'plans_harness.dart';

Notice _notice(String kind) => Notice(id: 'n1', kind: kind, count: 1, isRead: false);

void main() {
  tearDown(() {
    PlanGate.debugPlan = null;
    TaxiNoticeCopy.debugPlan = null;
    StayNoticeCopy.debugPlan = null;
  });

  group('PlanCardStates.ofPlan', () {
    test('every frame state', () {
      expect(PlanCardStates.ofPlan(Fx.free('Taxi')), PlanCardState.free);
      expect(PlanCardStates.ofPlan(Fx.trial('Taxi')), PlanCardState.trial);
      expect(PlanCardStates.ofPlan(Fx.plus('Stay')), PlanCardState.plus);
      expect(PlanCardStates.ofPlan(Fx.cancelled('Taxi')), PlanCardState.cancelled);
      expect(PlanCardStates.ofPlan(Fx.grace('Stay')), PlanCardState.grace);
      expect(PlanCardStates.ofPlan(Fx.onHold('Taxi')), PlanCardState.onHold);
      expect(PlanCardStates.ofPlan(Fx.onHold('Taxi', carry: 5)), PlanCardState.onHold);
      expect(PlanCardStates.ofPlan(Fx.ended('Taxi'), now: DateTime(2026, 12, 22)), PlanCardState.ended);
      expect(PlanCardStates.ofPlan(Fx.off('Taxi')), PlanCardState.paymentOff);
      expect(PlanCardStates.ofPlan(Fx.grant('Stay')), PlanCardState.adminGrant);
    });

    test('a cancelled trial reads as Cancelled', () {
      final me = Fx.trial('Taxi');
      final cancelled = MyPlanModel(
        paymentEnabled: true,
        featureKey: 'Taxi',
        isPaid: true,
        isDefault: false,
        source: 'Trial',
        play: play('Taxi', auto: false, trialEnds: trialEnd, expiry: trialEnd),
        limits: me.limits,
      );
      expect(PlanCardStates.ofPlan(cancelled), PlanCardState.cancelled);
    });

    test('Ended shows 30 days, then the Free page', () {
      expect(PlanCardStates.ofPlan(Fx.ended('Taxi'), now: DateTime(2027, 1, 19)), PlanCardState.ended);
      expect(PlanCardStates.ofPlan(Fx.ended('Taxi'), now: DateTime(2027, 1, 20)), PlanCardState.free);
    });

    test('rules: cycles and bar hidden while cancelled and payment OFF', () {
      expect(PlanCardStates.showsCycles(PlanCardState.cancelled), isFalse);
      expect(PlanCardStates.showsCycles(PlanCardState.paymentOff), isFalse);
      expect(PlanCardStates.showsCycles(PlanCardState.free), isTrue);
      expect(PlanCardStates.blocksPurchase(PlanCardState.onHold), isTrue);
    });

    test('FX-13 admin grant while payment is OFF reads as AdminGrant (D-09), by source not isPaid', () {
      final grantOff = MyPlanModel(
        paymentEnabled: false,
        featureKey: 'Stay',
        isDefault: false,
        isPaid: false,
        source: 'AdminGrant',
        endsAt: DateTime(2027, 1, 1),
      );
      expect(PlanCardStates.ofPlan(grantOff), PlanCardState.adminGrant);
      expect(PlanCardStates.ofPlan(Fx.off('Stay')), PlanCardState.paymentOff);
      final defaultGrant = MyPlanModel(paymentEnabled: false, featureKey: 'Stay', source: 'AdminGrant', endsAt: DateTime(2027));
      expect(PlanCardStates.ofPlan(defaultGrant), PlanCardState.paymentOff, reason: 'a default plan is never a grant');
    });

    test('FX-15 the server state wins; an unknown or missing state falls back unchanged', () {
      expect(PlanCardStates.ofPlan(MyPlanModel.fromJson({'paymentEnabled': true, 'state': 'Ended'})), PlanCardState.ended);
      expect(PlanCardStates.ofPlan(MyPlanModel.fromJson({'paymentEnabled': true, 'state': 'Cancelled'})), PlanCardState.cancelled);
      expect(PlanCardStates.ofPlan(MyPlanModel.fromJson({'paymentEnabled': true, 'state': 'Weird'})), PlanCardState.free);
      expect(PlanCardStates.ofPlan(MyPlanModel.fromJson({'paymentEnabled': false})), PlanCardState.paymentOff);
    });

    test('FX-15 canChoose and the choose target per role', () {
      final stay = const StayPlanCopy();
      final taxi = const TaxiPlanCopy();
      final photos = MyPlanModel.fromJson({'featureKey': 'Stay', 'hidden': {'photos': 2}});
      final pricesOnly = MyPlanModel.fromJson({'featureKey': 'Stay', 'hidden': {'specialPrices': 3}});
      final nothing = MyPlanModel.fromJson({'featureKey': 'Stay'});
      final routes = MyPlanModel.fromJson({'featureKey': 'Taxi', 'hidden': {'routes': 2}});
      expect(stay.canChoose(photos), isTrue);
      expect(stay.chooseLabelFor(photos), stay.chooseLabel);
      expect(stay.canChoose(pricesOnly), isTrue);
      expect(stay.chooseLabelFor(pricesOnly), 'Special prices');
      expect(stay.canChoose(nothing), isFalse);
      expect(taxi.canChoose(routes), isTrue);
      expect(taxi.canChoose(MyPlanModel.fromJson({'featureKey': 'Taxi', 'hidden': {'photos': 4}})), isFalse);
      expect(taxi.chooseLabelFor(routes), taxi.chooseLabel);
    });

    test('unknown wire state parses to unknown', () {
      expect(PlanCardStates.parse('Paused'), PlanCardState.unknown);
      expect(PlanCardStates.parse(7), PlanCardState.unknown);
      expect(PlanCardStates.parse('AdminGrant'), PlanCardState.adminGrant);
    });
  });

  test('MyPlanModel new fields: every wrong shape parses', () {
    final sample = <String, dynamic>{
      'paymentEnabled': true,
      'isPaid': false,
      'limits': {'photos': 2, 'roomTypes': 2, 'routes': 1, 'ringWeight': 1, 'calendarEntries': 4, 'monthSummary': false},
      'hidden': {'photos': 4, 'roomTypes': 2, 'routes': 3},
      'usage': {'photos': 2, 'roomTypes': 2, 'routes': 1},
      'canUpgrade': true,
      'paymentStartsOn': '2027-02-01',
      'plansStartedToday': true,
      'carryOverDays': 3,
    };
    for (final v in jsonVariants(sample)) {
      final me = MyPlanModel.fromJson(v);
      PlanCardStates.ofPlan(me);
      const TaxiPlanCopy().heroLines(PlanCardStates.ofPlan(me), me, const PlanValues());
      const StayPlanCopy().heroMeter(PlanCardStates.ofPlan(me), me, const PlanValues());
    }
    expect(MyPlanModel.fromJson(const {}).limits.routes, 1, reason: 'missing field = Free seed');
  });

  group('o_pl_10 / o_pl_13 board numbers', () {
    final v = PlanValues.fromCatalog([freePlan('Taxi'), plusPlan('Taxi')]);
    final s = PlanValues.fromCatalog([freePlan('Stay'), plusPlan('Stay')]);

    test('taxi Free / Plus', () {
      expect(v.free(PlanKey.routes), 1);
      expect(v.plus(PlanKey.routes), 5);
      expect(v.plus(PlanKey.ringWeight), 2);
      expect(v.free(PlanKey.calendarEntries), 4);
      expect(v.plus(PlanKey.calendarEntries), 50);
    });

    test('stay Free / Plus', () {
      expect([s.free(PlanKey.photos), s.plus(PlanKey.photos)], [2, 8]);
      expect([s.free(PlanKey.roomTypes), s.plus(PlanKey.roomTypes)], [2, 6]);
      expect([s.free(PlanKey.jobsPosts), s.plus(PlanKey.jobsPosts)], [1, 4]);
      expect([s.free(PlanKey.blockedRanges), s.plus(PlanKey.blockedRanges)], [1, 10]);
      expect([s.free(PlanKey.specialPrices), s.plus(PlanKey.specialPrices)], [1, 5]);
    });

    test('P1 table rows agree with the calendar board P13', () {
      final rows = const TaxiPlanCopy().compareRows(v);
      String cells(String label) => rows.firstWhere((r) => r.label == label).cells.map((c) => c.text.isEmpty ? c.kind.name : c.text).join('/');
      expect(cells('Upcoming list'), '15 days/6 months');
      expect(cells('Month calendar'), 'This month/+6 months');
      expect(cells('Trips you add'), '4/50');
      expect(cells('Morning reminder'), 'no/yes');
      expect(cells('Month money summary'), 'no/yes');
      expect(cells('Money notes on each trip'), 'yes/yes');
      expect(cells('Requests, bookings, rating'), 'yes/yes');
      expect(rows.length, 10);
    });

    test('P2 has 15 rows with the morning reminder and quotations a month', () {
      final rows = const StayPlanCopy().compareRows(s);
      expect(rows.length, 15);
      expect(rows.map((r) => r.label), contains('Morning reminder'));
      expect(rows.map((r) => r.label), contains('Quotations a month'));
      expect(rows.where((r) => r.tag != null).length, 12);
    });

    test('catalog missing: seed values, never unlocked', () {
      const empty = PlanValues();
      expect(empty.free(PlanKey.routes), 1);
      expect(empty.plus(PlanKey.routes), 5);
    });
  });

  group('payment OFF matrix (o_pl_17 C1)', () {
    test('every limit key reads the OFF payload values', () {
      PlanGate.debugPlan = Fx.off('Stay');
      expect(PlanGate.paymentOn, isFalse);
      expect(PlanGate.canUpgrade, isFalse);
      expect(PlanGate.limit(PlanKey.photos), 8);
      expect(PlanGate.limit(PlanKey.roomTypes), 6);
      expect(PlanGate.limit(PlanKey.jobsPosts), 4);
      expect(PlanGate.limit(PlanKey.calendarEntries), 50);
      expect(PlanGate.limit(PlanKey.blockedRanges), 10);
      expect(PlanGate.limit(PlanKey.monthsAhead), 6);
      expect(PlanGate.limit(PlanKey.specialPrices), 5);
      PlanGate.debugPlan = Fx.off('Taxi');
      expect(PlanGate.limit(PlanKey.routes), 5);
    });

    test('OFF hero prints the OFF number, no Free number', () {
      final lines = const TaxiPlanCopy().heroLines(PlanCardState.paymentOff, Fx.off('Taxi'), const PlanValues());
      expect(lines.map((l) => l.text), ['Up to 5 routes ring', 'Requests, bookings, rating']);
    });

    test('drivers with 6 to 10 routes keep them: the line still says the OFF limit', () {
      final me = MyPlanModel(paymentEnabled: false, featureKey: 'Taxi', limits: taxiPlusLimits, usage: const PlanUsageModel(routes: 7));
      expect(const TaxiPlanCopy().heroLines(PlanCardState.paymentOff, me, const PlanValues()).first.text, 'Up to 5 routes ring');
      expect(const TaxiPlanCopy().heroMeter(PlanCardState.paymentOff, me, const PlanValues()), isNull);
    });
  });

  group('copy', () {
    test('loss lines follow the free values', () {
      final v = PlanValues(freeFeatures: const {'Routes': 2, 'Photos': 3, 'RoomTypes': 1});
      expect(const TaxiPlanCopy().subNote(PlanCardState.cancelled, Fx.cancelled('Taxi'), v), 'After that, you keep 2 routes.');
      expect(const StayPlanCopy().subNote(PlanCardState.cancelled, Fx.cancelled('Stay'), v), 'After that, you keep 3 photos and 1 room type.');
    });

    test('stay hidden line variants', () {
      expect(StayPlanStrings.hidden(6, 4), 'Up to 6 photos and 4 room types are hidden. Nothing is deleted.');
      expect(StayPlanStrings.hidden(4, 0), 'Up to 4 photos are hidden. Nothing is deleted.');
      expect(StayPlanStrings.hidden(0, 1), 'Up to 1 room type is hidden. Nothing is deleted.');
    });

    test('profile line (o_st_23, o_tx_22)', () {
      expect(const StayPlanCopy().profileLine(Fx.free('Stay')), 'Free · 2 of 2 photos');
      expect(const TaxiPlanCopy().profileLine(Fx.free('Taxi')), 'Free · 1 of 1 route');
      expect(const TaxiPlanCopy().profileLine(const MyPlanModel()), 'Free');
    });

    test('free meter note (P1) and ended note (P8)', () {
      final v = PlanValues.fromCatalog([freePlan('Taxi'), plusPlan('Taxi')]);
      expect(const TaxiPlanCopy().heroMeter(PlanCardState.free, Fx.free('Taxi'), v)!.notes, ['Free plan: 1 route. Plus allows up to 5.']);
      expect(const TaxiPlanCopy().heroMeter(PlanCardState.ended, Fx.ended('Taxi'), v)!.notes, ['Your last added route stays. Extra routes are hidden, not deleted.']);
      expect(const TaxiPlanCopy().heroMeter(PlanCardState.free, const MyPlanModel(paymentEnabled: true), v), isNull, reason: 'no usage = no meter');
    });
  });

  group('o_pl_17 B / o_tx_45 C notices (registered by A3 / A6)', () {
    test('taxi PlanLimitsChanged and PlansStarting rows', () {
      TaxiNoticeCopy.debugPlan = const MyPlanModel(paymentEnabled: true, hidden: PlanHiddenModel(routes: 3));
      final a = TaxiNoticeCopy.of(_notice('PlanLimitsChanged'))!;
      expect(a.title, 'Plans have started');
      expect(a.body, '3 routes are hidden on Free. Nothing is deleted.');
      expect(a.route, '/taxi-plan-visible');
      TaxiNoticeCopy.debugPlan = MyPlanModel(paymentEnabled: false, trialAvailable: true, paymentStartsOn: DateTime(2027, 2, 1));
      TaxiNoticeCopy.debugCatalog = [freePlan('Taxi'), plusPlan('Taxi')];
      addTearDown(() => TaxiNoticeCopy.debugCatalog = null);
      final b = TaxiNoticeCopy.of(_notice('PlansStarting'))!;
      expect(b.title, 'Plans start on 1 Feb');
      expect(b.body, 'Free keeps 1 route. Try Plus free for 7 days.');
      expect(b.route, '/plans');
    });

    test('stay PlanLimitsChanged row', () {
      StayNoticeCopy.debugPlan = const MyPlanModel(paymentEnabled: true, hidden: PlanHiddenModel(photos: 4, roomTypes: 2));
      final a = StayNoticeCopy.of(_notice('PlanLimitsChanged'))!;
      expect(a.title, 'Plans have started');
      expect(a.body, '4 photos and 2 room types are hidden on Free. Nothing is deleted.');
      expect(a.route, '/stay-plan-visible');
    });

    test('nothing hidden: no row', () {
      TaxiNoticeCopy.debugPlan = const MyPlanModel(paymentEnabled: true);
      expect(TaxiNoticeCopy.of(_notice('PlanLimitsChanged')), isNull);
    });
  });

  group('guards', () {
    const laneFiles = [
      'lib/screens/plans_billing_screen.dart',
      'lib/widgets/plan_subscription_card.dart',
      'lib/widgets/plan_words.dart',
      'lib/widgets/plan_cap_strip.dart',
      'lib/widgets/plan_compare_table.dart',
      'lib/features/owner_core/plan/home_plan_card.dart',
      'lib/features/owner_core/plan/plan_card_state.dart',
      'lib/features/owner_core/plan/profile_plan_card.dart',
      'lib/features/stay_owner/plan/stay_plan_strings.dart',
      'lib/features/stay_owner/plan/stay_plan_copy.dart',
      'lib/features/taxi_driver/plan/taxi_plan_strings.dart',
      'lib/features/taxi_driver/plan/taxi_plan_copy.dart',
      'lib/features/taxi_driver/plan_visible/taxi_plan_visible_screen.dart',
      'lib/features/taxi_driver/plan_visible/taxi_plan_visible_strings.dart',
    ];

    test('no Resume, Paused or refund in the lane', () {
      for (final f in laneFiles) {
        final s = File(f).readAsStringSync();
        for (final w in ['Resume', 'Paused', 'refund']) {
          expect(s.contains(w), isFalse, reason: '$f: $w');
        }
      }
    });

    test('stay plan copy says you, never he / his / him', () {
      final s = File('lib/features/stay_owner/plan/stay_plan_strings.dart').readAsStringSync().toLowerCase();
      for (final w in [' he ', ' his ', ' him ', ' him.']) {
        expect(s.contains(w), isFalse, reason: w);
      }
    });

    test('plan model and catalog stay tolerant to an old server', () {
      final p = PlanModel.fromJson(const {'id': 'x', 'code': 'F', 'name': 'Free', 'isDefault': true}, 'Taxi');
      expect(PlanValues.fromCatalog([p]).free(PlanKey.routes), 1);
    });
  });
}
