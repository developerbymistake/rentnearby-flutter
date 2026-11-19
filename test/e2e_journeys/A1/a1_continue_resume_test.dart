import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/utils/trip_bar_rules.dart';
import 'package:flutter_test/flutter_test.dart';

TripSummaryModel _summary({Object? guideStep, String next = 'gettingThere', List<String>? cities, Map<String, String>? rows}) =>
    TripSummaryModel.fromJson({
      'id': 'trip-1',
      'title': '',
      'status': 'Planned',
      'cityName': 'Nainital',
      'dayCount': 2,
      'spotCount': 4,
      'category': 'attraction',
      'updatedAt': '2026-11-01T10:00:00Z',
      if (cities != null) 'legCount': cities.length,
      'legCities': ?cities,
      'progress': {
        'total': 4,
        'done': 0,
        'percent': 0,
        'next': {'kind': next.split(':').first, 'key': next},
        'guideStep': ?guideStep,
        'rows': [for (final e in (rows ?? const {}).entries) {'key': e.key, 'state': e.value}],
      },
    });

void main() {
  group('Continue card title', () {
    test('the server next and guide step never name the card, the rows do', () {
      final rows = {'stay:1': 'asked', 'taxi': 'todo'};
      expect(TripBarRules.nextTitle(_summary(guideStep: 'gettingThere', next: 'gettingThere', rows: rows)), 'Local taxi');
      expect(TripBarRules.nextTitle(_summary(next: 'taxi', rows: {'stay:1': 'todo', 'taxi': 'todo'})), 'Stay in Nainital');
    });

    test('question rows never name the card', () {
      final rows = {'gettingThere': 'todo', 'stay:1': 'asked', 'between:2': 'todo', 'stay:2': 'todo', 'taxi': 'skipped', 'comingBack': 'todo'};
      expect(TripBarRules.nextTitle(_summary(cities: ['Nainital', 'Almora'], rows: rows)), isNull);
    });

    test('stay and taxi rows still name the card, stay first', () {
      final cities = ['Nainital', 'Almora'];
      expect(TripBarRules.nextTitle(_summary(cities: cities, rows: {'stay:1': 'skipped', 'stay:2': 'todo', 'taxi': 'todo'})), 'Stay in Almora');
      expect(TripBarRules.nextTitle(_summary(cities: cities, rows: {'stay:1': 'confirmed', 'stay:2': 'todo', 'taxi': 'todo'})), 'Local taxi');
    });

    test('a bad guide step from the server is ignored', () {
      for (final bad in ['finish', 'stay:0', 'stay:100', '', 7, 'row; drop', 'stay:1\n']) {
        final t = _summary(guideStep: bad, next: 'taxi', rows: {'stay:1': 'own', 'taxi': 'todo'});
        expect(t.progress.guideStep, isNull, reason: '$bad');
        expect(TripBarRules.nextTitle(t), 'Local taxi');
      }
    });
  });
}
