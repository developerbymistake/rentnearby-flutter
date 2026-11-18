import 'dart:io';

import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/trip_constants.dart';
import 'package:bakhli/features/trip/utils/trip_leg_draft.dart';
import 'package:flutter_test/flutter_test.dart';

TripSpotRef _s(String id, {double lat = 29.38, double lng = 79.45, int visit = 60}) =>
    TripSpotRef(id: id, name: id, latitude: lat, longitude: lng, category: 'View', visitMinutes: visit);

List<TripSpotRef> _many(String prefix, int n) => [for (var i = 0; i < n; i++) _s('$prefix$i')];

TripCityLeg _leg(int index) =>
    TripCityLeg(index: index, cityKey: index, cityName: 'City $index', latitude: 29.0 + index, longitude: 79.0);

TripPlan _plan(List<List<TripSpotRef>> leg2Days, {Set<int> rest = const {}}) {
  final days = <TripDay>[
    TripDay(day: 1, leg: 1, spots: [_s('o1'), _s('o2')]),
    for (var i = 0; i < leg2Days.length; i++) TripDay(day: 2 + i, leg: 2, spots: leg2Days[i], restDay: rest.contains(i)),
    TripDay(day: 2 + leg2Days.length, leg: 3, spots: [_s('o3')]),
  ];
  return TripPlan(legs: [_leg(1), _leg(2), _leg(3)], days: days);
}

TripLegDraft _draft(TripPlan p, {int frozen = 0, int otherDays = 2, int otherSpots = 3}) =>
    TripLegDraft.from(p, 2, frozenDays: frozen, otherLegsDayCount: otherDays, otherLegsSpotCount: otherSpots);

List<List<String>> _ids(TripLegDraft d) => [for (final day in d.days) day.spots.map((s) => s.id).toList()];

void main() {
  test('no_getx_or_controller_import', () {
    final src = File('lib/features/trip/utils/trip_leg_draft.dart').readAsStringSync();
    final imports = RegExp(r"^import\s+'([^']+)'", multiLine: true).allMatches(src).map((m) => m.group(1)!).toList();
    expect(imports.where((i) => i.contains('package:get/') || i.contains('controller')), isEmpty);
  });

  test('from_copies_only_that_city', () {
    final d = _draft(_plan([[_s('a'), _s('b')], [_s('c')]]));
    expect(_ids(d), [['a', 'b'], ['c']]);
    expect(d.firstDayNumber, 2);
    expect(d.changed, isFalse);
    expect(d.toLegDays().map((x) => x.day), [2, 3]);
    expect(d.toLegDays().every((x) => x.leg == 2), isTrue);
  });

  test('move_inside_a_day_with_index', () {
    final d = _draft(_plan([[_s('a'), _s('b'), _s('c')]]));
    expect(d.move('c', 0, 0), TripDraftBlock.none);
    expect(_ids(d), [['c', 'a', 'b']]);
    expect(d.move('c', 0, 2), TripDraftBlock.none);
    expect(_ids(d), [['a', 'b', 'c']]);
    expect(d.move('a', 0, 99), TripDraftBlock.none);
    expect(_ids(d), [['b', 'c', 'a']]);
  });

  test('move_across_days_with_index', () {
    final d = _draft(_plan([[_s('a'), _s('b')], [_s('c'), _s('d')]]));
    expect(d.move('a', 1, 1), TripDraftBlock.none);
    expect(_ids(d), [['b'], ['c', 'a', 'd']]);
    expect(d.changed, isTrue);
  });

  test('full_day_refuses', () {
    final d = _draft(_plan([[_s('a')], _many('f', 6)]));
    expect(d.canDrop('a', 1), TripDraftBlock.dayFull);
    expect(d.move('a', 1, 0), TripDraftBlock.dayFull);
    expect(_ids(d)[0], ['a']);
    expect(d.canDrop('f0', 1), TripDraftBlock.none);
    expect(d.move('f0', 1, 5), TripDraftBlock.none);
    expect(d.canDrop('zz', 0), TripDraftBlock.notFound);
    expect(d.canDrop('a', 5), TripDraftBlock.notFound);
  });

  test('move_and_move_back_leaves_changed_false', () {
    final d = _draft(_plan([[_s('a'), _s('b')], [_s('c')]]));
    d.move('a', 1, 0);
    expect(d.changed, isTrue);
    d.move('a', 0, 0);
    expect(d.changed, isFalse);
  });

  test('remove_leaves_an_empty_day', () {
    final d = _draft(_plan([[_s('a')], [_s('b')]]));
    expect(d.remove('a'), TripDraftBlock.none);
    expect(_ids(d), [[], ['b']]);
    expect(d.dayCount, 2);
    expect(d.firstEmptyDay, 0);
    expect(d.remove('a'), TripDraftBlock.notFound);
  });

  test('add_day_appends_empty_and_respects_the_cap', () {
    final d = _draft(_plan([[_s('a')]]), otherDays: TripConstants.maxDaysCap - 3);
    expect(d.addDay(), TripDraftBlock.none);
    expect(d.addDay(), TripDraftBlock.none);
    expect(d.dayCount, 3);
    expect(_ids(d), [['a'], [], []]);
    expect(d.canAddDay, isFalse);
    expect(d.addDay(), TripDraftBlock.tooManyDays);
    expect(d.dayCount, 3);
    expect(d.toLegDays().map((x) => x.day), [2, 3, 4]);
    expect(d.firstEmptyDay, 1);
  });

  test('delete_day_spreads_earliest_first_and_keeps_order', () {
    final d = _draft(_plan([_many('a', 4), _many('b', 5), [_s('c1'), _s('c2'), _s('c3')]]));
    expect(d.deleteDay(2), TripDraftBlock.none);
    expect(_ids(d), [
      ['a0', 'a1', 'a2', 'a3', 'c1', 'c2'],
      ['b0', 'b1', 'b2', 'b3', 'b4', 'c3'],
    ]);
    final r = d.deleteDayResult!;
    expect(r.deletedIndex, 2);
    expect(r.moved, 3);
    expect(r.intoDays, [0, 1]);
  });

  test('delete_middle_day_spreads_into_earlier_then_later_days', () {
    final d = _draft(_plan([_many('a', 5), [_s('m1'), _s('m2')], [_s('c')]]));
    expect(d.deleteDay(1), TripDraftBlock.none);
    expect(_ids(d), [
      ['a0', 'a1', 'a2', 'a3', 'a4', 'm1'],
      ['c', 'm2'],
    ]);
    expect(d.deleteDayResult!.intoDays, [0, 1]);
  });

  test('delete_blocked_at_days_minus_one_times_six_plus_one', () {
    final over = _draft(_plan([_many('a', 6), _many('b', 6), [_s('x')]]));
    expect(over.spotCount, (3 - 1) * 6 + 1);
    expect(over.deleteDay(2), TripDraftBlock.placesDontFit);
    expect(over.dayCount, 3);
    expect(over.deleteDayResult, isNull);
    final fits = _draft(_plan([_many('a', 6), _many('b', 5), [_s('x')]]));
    expect(fits.deleteDay(2), TripDraftBlock.none);
    expect(fits.dayCount, 2);
  });

  test('delete_of_the_last_day_refused', () {
    final d = _draft(_plan([[_s('a')]]));
    expect(d.deleteDay(0), TripDraftBlock.lastDay);
    expect(d.deleteDay(3), TripDraftBlock.notFound);
    final f = _draft(_plan([[_s('a')], [_s('b')]]), frozen: 1);
    expect(f.deleteDay(1), TripDraftBlock.lastDay);
  });

  test('frozen_days_never_change_and_never_receive', () {
    final d = _draft(_plan([[_s('a')], [_s('b'), _s('c')], [_s('d')]]), frozen: 1);
    expect(d.isFrozen(0), isTrue);
    expect(d.move('a', 1, 0), TripDraftBlock.frozen);
    expect(d.move('b', 0, 0), TripDraftBlock.frozen);
    expect(d.canDrop('b', 0), TripDraftBlock.frozen);
    expect(d.move('a', 0, 0), TripDraftBlock.frozen);
    expect(d.remove('a'), TripDraftBlock.frozen);
    expect(d.deleteDay(0), TripDraftBlock.frozen);
    expect(d.addSpots(0, [_s('n')]), TripDraftBlock.frozen);
    expect(d.deleteDay(1), TripDraftBlock.none);
    expect(_ids(d), [['a'], ['d', 'b', 'c']]);
    expect(d.deleteDayResult!.intoDays, [1]);
    expect(d.changed, isTrue);
  });

  test('frozen_spread_capacity_ignores_frozen_room', () {
    final d = _draft(_plan([[_s('a')], _many('b', 6), [_s('c')]]), frozen: 1);
    expect(d.deleteDay(2), TripDraftBlock.placesDontFit);
  });

  test('add_spots_caps_at_six_and_at_the_trip_total_and_skips_duplicates', () {
    final d = _draft(_plan([[_s('a'), _s('b')], [_s('c')]]));
    expect(d.addSpots(0, [_s('a'), _s('c'), _s('n1'), _s('n1'), _s('n2')]), TripDraftBlock.none);
    expect(_ids(d)[0], ['a', 'b', 'n1', 'n2']);
    expect(d.addSpots(0, _many('m', 4)), TripDraftBlock.dayFull);
    expect(_ids(d)[0], ['a', 'b', 'n1', 'n2', 'm0', 'm1']);
    expect(d.addSpots(9, [_s('q')]), TripDraftBlock.notFound);

    final t = _draft(_plan([[_s('a')], []]), otherSpots: TripConstants.maxSpots - 3);
    expect(t.spotRoom, 2);
    expect(t.addSpots(1, _many('t', 4)), TripDraftBlock.tooManySpots);
    expect(_ids(t)[1], ['t0', 't1']);
    expect(t.spotRoom, 0);
    expect(t.addSpots(0, [_s('u')]), TripDraftBlock.tooManySpots);
  });

  test('rest_day_is_not_empty', () {
    final d = _draft(_plan([[_s('a')], []], rest: {1}));
    expect(d.firstEmptyDay, isNull);
    expect(d.toLegDays()[1].restDay, isTrue);
    d.move('a', 1, 0);
    expect(d.firstEmptyDay, 0);
    expect(d.toLegDays()[1].restDay, isFalse);
    d.move('a', 0, 0);
    expect(d.changed, isFalse);
    expect(d.firstEmptyDay, isNull);
  });

  test('first_empty_day_skips_frozen_and_rest_days', () {
    final d = _draft(_plan([[], [], [_s('a')]], rest: {1}), frozen: 1);
    expect(d.firstEmptyDay, isNull);
    d.addDay();
    expect(d.firstEmptyDay, 3);
    d.addSpots(3, [_s('x')]);
    expect(d.firstEmptyDay, isNull);
  });

  test('reset_restores_the_original', () {
    final d = _draft(_plan([[_s('a'), _s('b')], [_s('c')]]));
    d.move('a', 1, 0);
    d.addDay();
    d.addSpots(2, [_s('n')]);
    d.deleteDay(0);
    expect(d.changed, isTrue);
    d.reset();
    expect(_ids(d), [['a', 'b'], ['c']]);
    expect(d.changed, isFalse);
    expect(d.deleteDayResult, isNull);
  });

  test('base_signature_stable', () {
    final p = _plan([[_s('a'), _s('b')], []], rest: {1});
    final d = _draft(p);
    final sig = d.baseSignature;
    expect(_draft(p).baseSignature, sig);
    expect(TripLegDraft.signatureOf(p.daysOf(2)), sig);
    d.move('a', 1, 0);
    d.addDay();
    expect(d.baseSignature, sig);
    expect(TripLegDraft.signatureOf(d.toLegDays()), isNot(sig));
    expect(TripLegDraft.signatureOf(p.daysOf(2)), isNot(TripLegDraft.signatureOf(_plan([[_s('b'), _s('a')], []], rest: {1}).daysOf(2))));
    expect(TripLegDraft.signatureOf(p.daysOf(2)), isNot(TripLegDraft.signatureOf(_plan([[_s('a'), _s('b')], []]).daysOf(2))));
  });

  test('to_leg_days_does_not_touch_the_plan', () {
    final p = _plan([[_s('a')], [_s('b')]]);
    final d = _draft(p);
    d.move('a', 1, 0);
    expect(p.daysOf(2).map((x) => x.spots.map((s) => s.id).toList()), [['a'], ['b']]);
    expect(p.daysOf(1).single.spots.length, 2);
  });

  test('estimate_minutes_adds_visits_and_local_drive', () {
    final d = _draft(_plan([
      [_s('a', visit: 30), _s('b', lat: 29.48, visit: 45)],
      [],
    ]));
    expect(d.estimateMinutes(0), greaterThan(75));
    expect(d.estimateMinutes(1), 0);
    expect(d.estimateMinutes(7), 0);
  });
}
