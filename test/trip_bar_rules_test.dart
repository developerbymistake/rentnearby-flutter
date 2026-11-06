import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/utils/trip_bar_rules.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 11, 10);

String _d(int offset) {
  final d = DateTime(_today.year, _today.month, _today.day + offset);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

TripSummaryModel _trip(
  String id, {
  int? startIn,
  int days = 3,
  int counted = 5,
  int total = 13,
  int decided = 1,
  int needYou = 0,
  int waitingForReply = 0,
  String? nextKey = 'stay:1:2',
  int? nextDay = 2,
  String updatedAt = '2026-11-01T10:00:00Z',
  String status = 'Planned',
  String? lastEventAt,
  List<String>? cities,
}) =>
    TripSummaryModel.fromJson({
      'id': id,
      'title': '',
      'status': status,
      'cityName': cities?.first ?? 'Nainital',
      'dayCount': days,
      'spotCount': 4,
      'taxiDays': 0,
      'stayDays': 0,
      'category': 'attraction',
      if (startIn != null) 'startDate': _d(startIn),
      if (startIn != null) 'endDate': _d(startIn + days - 1),
      'updatedAt': updatedAt,
      if (cities != null) 'legCount': cities.length,
      'legCities': ?cities,
      'progress': {
        'total': total,
        'counted': counted,
        'decided': decided,
        'waiting': waitingForReply,
        'waitingForReply': waitingForReply,
        'needYou': needYou,
        'needsYou': needYou > 0,
        'attention': 0,
        'percent': total == 0 ? 0 : counted * 100 ~/ total,
        if (nextKey != null) 'next': {'kind': nextKey.split(':').first, 'day': nextDay, 'key': nextKey},
        'lastEventAt': ?lastEventAt,
      },
    });

void main() {
  group('pick order', () {
    test('running trip wins over a sooner draft and a recent one', () {
      final pick = TripBarRules.pick([
        _trip('soon', startIn: 4),
        _trip('running', startIn: -1),
        _trip('undated', updatedAt: '2026-11-09T10:00:00Z'),
      ], _today);
      expect(pick?.trip.id, 'running');
      expect(pick?.more, 2);
      expect(pick?.line, TripBarLine.next);
    });

    test('check-out day still counts as running', () {
      final pick = TripBarRules.pick([
        _trip('soon', startIn: 4),
        _trip('leaving', startIn: -3, days: 3),
      ], _today);
      expect(pick?.trip.id, 'leaving');
    });

    test('soonest in-progress start when nothing runs', () {
      final pick = TripBarRules.pick([
        _trip('later', startIn: 20),
        _trip('undated', updatedAt: '2026-11-09T10:00:00Z'),
        _trip('sooner', startIn: 6),
      ], _today);
      expect(pick?.trip.id, 'sooner');
      expect(pick?.more, 2);
    });

    test('most recently updated when no trip has dates', () {
      final pick = TripBarRules.pick([
        _trip('old', updatedAt: '2026-10-01T10:00:00Z'),
        _trip('new', updatedAt: '2026-11-08T10:00:00Z'),
      ], _today);
      expect(pick?.trip.id, 'new');
      expect(pick?.more, 1);
    });

    test('ready trip shows only today and tomorrow', () {
      expect(TripBarRules.pick([_trip('r', startIn: 5, counted: 13, nextKey: null)], _today), isNull);
      final tomorrow = TripBarRules.pick([_trip('r', startIn: 1, counted: 13, nextKey: null)], _today);
      expect(tomorrow?.line, TripBarLine.tomorrow);
      final today = TripBarRules.pick([_trip('r', startIn: 0, counted: 13, nextKey: null)], _today);
      expect(today?.line, TripBarLine.today);
    });

    test('ready trip far away does not count for more', () {
      final pick = TripBarRules.pick([
        _trip('p', startIn: 8),
        _trip('r', startIn: 5, counted: 13, nextKey: null),
      ], _today);
      expect(pick?.trip.id, 'p');
      expect(pick?.more, 0);
    });

    test('past and completed trips never show', () {
      expect(
        TripBarRules.pick([
          _trip('past', startIn: -6, days: 3),
          _trip('done', startIn: 3, status: 'Completed'),
        ], _today),
        isNull,
      );
    });

    test('hidden trip gives way to the next one', () {
      final pick = TripBarRules.pick(
        [_trip('a', startIn: 3), _trip('b', startIn: 9)],
        _today,
        isHidden: (t) => t.id == 'a',
      );
      expect(pick?.trip.id, 'b');
      expect(pick?.more, 0);
    });
  });

  group('grouping', () {
    test('in progress below total, ready at total, past dropped', () {
      final g = TripBarRules.group([
        _trip('p1', startIn: 3),
        _trip('r1', startIn: 4, counted: 13, nextKey: null),
        _trip('p2'),
        _trip('gone', startIn: -10, days: 2),
      ], _today);
      expect(g.inProgress.map((t) => t.id), ['p1', 'p2']);
      expect(g.ready.map((t) => t.id), ['r1']);
    });

    test('check-out day is not past, the day after is', () {
      expect(TripBarRules.isPast(_trip('a', startIn: -3, days: 3), _today), isFalse);
      expect(TripBarRules.isPast(_trip('b', startIn: -4, days: 3), _today), isTrue);
    });
  });

  group('hide', () {
    final hiddenAt = DateTime.utc(2026, 11, 2, 6);

    test('stays hidden without a new event', () {
      expect(TripBarRules.stillHidden(_trip('a', startIn: 9), TripBarHide(hiddenAt, needYou: 1), _today), isTrue);
    });

    test('a newer event brings it back', () {
      final t = _trip('a', startIn: 9, lastEventAt: '2026-11-05T10:00:00Z');
      expect(TripBarRules.stillHidden(t, TripBarHide(hiddenAt), _today), isFalse);
    });

    test('more steps needing you bring it back', () {
      final t = _trip('a', startIn: 9, needYou: 2);
      expect(TripBarRules.stillHidden(t, TripBarHide(hiddenAt, needYou: 1), _today), isFalse);
    });

    test('trip tomorrow brings it back, unless hidden that close', () {
      final t = _trip('a', startIn: 1);
      expect(TripBarRules.stillHidden(t, TripBarHide(hiddenAt), _today), isFalse);
      expect(TripBarRules.stillHidden(t, TripBarHide(DateTime.utc(2026, 11, 10, 6)), _today), isTrue);
    });
  });

  group('labels', () {
    test('start while nothing decided, continue after', () {
      expect(TripBarRules.actionLabel(_trip('a', decided: 0, nextKey: 'gettingThere', nextDay: null)),
          'Start: Getting there');
      expect(TripBarRules.actionLabel(_trip('a')), 'Continue · Day 2 · Stay');
      expect(TripBarRules.actionLabel(_trip('a', counted: 13, nextKey: null)), 'Your trip is ready · Summary');
      expect(TripBarRules.actionLabel(_trip('a'), past: true), 'Summary');
    });

    test('city change title uses the leg cities', () {
      final t = _trip('a', nextKey: 'travel:2', nextDay: null, cities: ['Nainital', 'Almora']);
      expect(TripBarRules.nextTitle(t), 'Nainital → Almora');
    });

    test('continue passes the next key to the list', () {
      expect(TripBarRules.continueArgs(_trip('a')), {'tripId': 'a', 'step': 'stay:1:2'});
      expect(TripBarRules.continueArgs(_trip('a', counted: 13, nextKey: null)), {'tripId': 'a'});
    });
  });
}
