import 'package:bakhli/config/notification_types.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/owner_core/plan/plan_card_state.dart';
import 'package:bakhli/features/taxi_driver/plan/taxi_plan_copy.dart';
import 'package:bakhli/features/taxi_driver/plan/taxi_plan_strings.dart';
import 'package:bakhli/features/taxi_driver/taxi_driver_session.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:flutter_test/flutter_test.dart';

// Matrix L3-L13 for the Taxi plan texts and plan-change detection: one /plans/me body per lifecycle state.

const _plusLimits = {'routes': 5, 'ringWeight': 2, 'calendarEntries': 50, 'upcomingDays': 183, 'monthsAhead': 6, 'monthSummary': true, 'reminders': true};
const _paidPlan = {'id': 'plus', 'isDefault': false};

Map<String, dynamic> _play(String state, {bool renew = true, bool owns = true}) =>
    {'state': 'SUBSCRIPTION_STATE_$state', 'autoRenewEnabled': renew, 'ownsActivePlan': owns, 'expiryAt': '2026-12-21T00:00:00Z'};

final Map<String, Map<String, dynamic>> _bodies = {
  'Free': {'state': 'Free', 'paymentEnabled': true, 'limits': {'routes': 1}, 'usage': {'routes': 1}},
  'Trial': {'state': 'Trial', 'paymentEnabled': true, 'isPaid': true, 'source': 'Trial', 'plan': _paidPlan, 'endsAt': '2026-11-28T00:00:00Z', 'limits': _plusLimits, 'usage': {'routes': 2}},
  'Plus': {'state': 'Plus', 'paymentEnabled': true, 'isPaid': true, 'plan': _paidPlan, 'endsAt': '2026-12-21T00:00:00Z', 'play': _play('ACTIVE'), 'limits': _plusLimits, 'usage': {'routes': 3}},
  'Cancelled': {'state': 'Cancelled', 'paymentEnabled': true, 'isPaid': true, 'plan': _paidPlan, 'endsAt': '2026-12-21T00:00:00Z', 'play': _play('ACTIVE', renew: false), 'limits': _plusLimits, 'usage': {'routes': 3}},
  'Grace': {'state': 'Grace', 'paymentEnabled': true, 'isPaid': true, 'plan': _paidPlan, 'endsAt': '2026-12-21T00:00:00Z', 'play': _play('IN_GRACE_PERIOD'), 'limits': _plusLimits, 'usage': {'routes': 3}},
  'OnHold': {'state': 'OnHold', 'paymentEnabled': true, 'play': _play('ON_HOLD', owns: false), 'limits': {'routes': 1}, 'hidden': {'routes': 2}, 'usage': {'routes': 1}},
  'Ended': {'state': 'Ended', 'paymentEnabled': true, 'play': _play('EXPIRED', owns: false), 'limits': {'routes': 1}, 'hidden': {'routes': 2}, 'usage': {'routes': 1}},
  'Resubscribed': {'state': 'Plus', 'paymentEnabled': true, 'isPaid': true, 'plan': _paidPlan, 'endsAt': '2027-01-21T00:00:00Z', 'play': _play('ACTIVE'), 'limits': _plusLimits, 'usage': {'routes': 3}},
  'PaymentOff': {'state': 'PaymentOff', 'paymentEnabled': false, 'limits': _plusLimits, 'usage': {'routes': 1}},
};

MyPlanModel _me(String k) => MyPlanModel.fromJson(_bodies[k]!);

void main() {
  const copy = TaxiPlanCopy();
  const values = PlanValues();

  test('every body maps to its card state', () {
    const want = {
      'Free': PlanCardState.free,
      'Trial': PlanCardState.trial,
      'Plus': PlanCardState.plus,
      'Cancelled': PlanCardState.cancelled,
      'Grace': PlanCardState.grace,
      'OnHold': PlanCardState.onHold,
      'Ended': PlanCardState.ended,
      'Resubscribed': PlanCardState.plus,
      'PaymentOff': PlanCardState.paymentOff,
    };
    for (final e in want.entries) {
      expect(PlanCardStates.ofPlan(_me(e.key)), e.value, reason: e.key);
    }
  });

  test('without a server state the same bodies still map (old server)', () {
    for (final k in ['Trial', 'Plus', 'Cancelled', 'Grace', 'OnHold', 'Ended', 'PaymentOff']) {
      final body = {..._bodies[k]!}..remove('state');
      final got = PlanCardStates.ofPlan(MyPlanModel.fromJson(body), now: DateTime(2026, 12, 25));
      expect(got, PlanCardStates.parse(_bodies[k]!['state']), reason: k);
    }
  });

  test('L5/L7/L8/L6 sub notes per state', () {
    expect(copy.subNote(PlanCardState.cancelled, _me('Cancelled'), values), 'After that, you keep 1 route.');
    expect(copy.subNote(PlanCardState.onHold, _me('OnHold'), values), 'Until then, you keep 1 route.');
    expect(copy.subNote(PlanCardState.ended, _me('Ended'), values), TaxiPlanStrings.extraHidden);
    expect(copy.subNote(PlanCardState.ended, _me('Free'), values), isNull, reason: 'nothing hidden, no hidden line');
    for (final s in [PlanCardState.free, PlanCardState.trial, PlanCardState.plus, PlanCardState.grace, PlanCardState.paymentOff]) {
      expect(copy.subNote(s, _me('Plus'), values), isNull, reason: '$s');
    }
  });

  test('hero lines: Plus values for trial, plus, cancelled, grace; Free values for free, ended, on hold', () {
    for (final (s, k) in [(PlanCardState.trial, 'Trial'), (PlanCardState.plus, 'Plus'), (PlanCardState.cancelled, 'Cancelled'), (PlanCardState.grace, 'Grace')]) {
      final lines = copy.heroLines(s, _me(k), values).map((l) => l.text).toList();
      expect(lines, ['Up to 5 routes', 'Your turn 2x as often', 'Featured in taxi lists'], reason: '$s');
    }
    for (final (s, k) in [(PlanCardState.free, 'Free'), (PlanCardState.ended, 'Ended'), (PlanCardState.onHold, 'OnHold')]) {
      final lines = copy.heroLines(s, _me(k), values);
      expect(lines.map((l) => l.text).toList(), ['1 route', 'Normal turn for requests'], reason: '$s');
      expect(lines.last.on, isFalse);
    }
    expect(copy.heroLines(PlanCardState.paymentOff, _me('PaymentOff'), values).map((l) => l.text).toList(), ['Up to 5 routes ring', 'Requests, bookings, rating']);
  });

  test('hero meter: used and limit come from the server, notes per state', () {
    final free = copy.heroMeter(PlanCardState.free, _me('Free'), values)!;
    expect(free.value, '1 of 1');
    expect(free.notes, hasLength(1));
    final ended = copy.heroMeter(PlanCardState.ended, _me('Ended'), values)!;
    expect(ended.notes, [TaxiPlanStrings.lastRouteStays]);
    for (final (s, k) in [(PlanCardState.trial, 'Trial'), (PlanCardState.plus, 'Plus')]) {
      final m = copy.heroMeter(s, _me(k), values)!;
      expect(m.notes, isEmpty, reason: '$s');
    }
    expect(copy.heroMeter(PlanCardState.plus, _me('Plus'), values)!.value, '3 of 5');
    for (final (s, k) in [(PlanCardState.cancelled, 'Cancelled'), (PlanCardState.grace, 'Grace'), (PlanCardState.onHold, 'OnHold')]) {
      expect(copy.heroMeter(s, _me(k), values), isNull, reason: '$s');
    }
    final noUsage = MyPlanModel.fromJson({..._bodies['Plus']!}..remove('usage'));
    expect(copy.heroMeter(PlanCardState.plus, noUsage, values), isNull, reason: 'no guessed number before the server answers');
  });

  test('L3-L13: every real change between steps changes the fingerprint (screens reload once), a repeat does not', () {
    const walk = ['Free', 'Trial', 'Plus', 'Cancelled', 'Grace', 'OnHold', 'Ended', 'Resubscribed'];
    for (var i = 1; i < walk.length; i++) {
      expect(PlanController.fingerprintOf(_me(walk[i])), isNot(PlanController.fingerprintOf(_me(walk[i - 1]))), reason: '${walk[i - 1]} -> ${walk[i]}');
    }
    for (final k in walk) {
      expect(PlanController.fingerprintOf(_me(k)), PlanController.fingerprintOf(_me(k)), reason: 'repeat $k');
    }
    expect(PlanController.fingerprintOf(_me('Plus')), isNot(PlanController.fingerprintOf(_me('Resubscribed'))), reason: 'renewal moves endsAt');
    expect(PlanController.fingerprintOf(_me('Ended')), isNot(PlanController.fingerprintOf(_me('Free'))));
    expect(PlanController.fingerprintOf(_me('PaymentOff')), isNot(PlanController.fingerprintOf(_me('Free'))), reason: 'L14 flip');
  });

  test('L12 cycle switch: a deferred change keeps the Plus numbers and does not look like a downgrade', () {
    final body = {..._bodies['Plus']!, 'play': {..._play('ACTIVE'), 'scheduledPlanName': 'Plus 12 months', 'scheduledAt': '2026-12-21T00:00:00Z'}};
    final me = MyPlanModel.fromJson(body);
    expect(PlanCardStates.ofPlan(me), PlanCardState.plus);
    expect(me.limits.routes, 5);
    expect(me.hidden.routes, 0);
  });

  test('L13 restore with no entitlement change: same body, same fingerprint', () {
    expect(PlanController.fingerprintOf(_me('Free')), PlanController.fingerprintOf(MyPlanModel.fromJson({..._bodies['Free']!, 'otherAccountProducts': ['x']})));
  });

  test('plan_* pushes: the plan controller handles them, Taxi screens do not double reload', () {
    for (final t in ['plan_expired', 'plan_renewed', 'plan_payment_issue', 'plan_on_hold', 'plan_paused', 'plan_carry_over_activated', 'plan_limits_changed', 'plans_starting']) {
      expect(TaxiDriverSession.reloadsCalendar(t), isFalse, reason: t);
      expect(TaxiDriverSession.reloadsHome(t), isFalse, reason: t);
    }
    for (final t in ['plan_limits_changed', 'plans_starting']) {
      expect(NotificationTypeKeys.invalidatesPlan.contains(t), isTrue, reason: t);
    }
    expect(NotificationTypeKeys.ownerTaxi.contains('owner_booking_tomorrow'), isTrue, reason: 'evening-before alert reaches Free owners');
  });
}
