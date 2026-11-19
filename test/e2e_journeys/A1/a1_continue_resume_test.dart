import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/utils/trip_bar_rules.dart';
import 'package:flutter_test/flutter_test.dart';

TripSummaryModel _summary({Object? guideStep, String next = 'gettingThere', List<String>? cities}) => TripSummaryModel.fromJson({
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
      },
    });

void main() {
  group('Continue card title', () {
    test('a guide step from the server never names the card', () {
      expect(TripBarRules.nextTitle(_summary(guideStep: 'gettingThere', next: 'taxi')), 'Local taxi');
      expect(TripBarRules.nextTitle(_summary(guideStep: 'taxi', next: 'gettingThere')), isNull);
    });

    test('question rows never name the card', () {
      for (final next in ['gettingThere', 'comingBack', 'between:2']) {
        expect(TripBarRules.nextTitle(_summary(next: next, cities: ['Nainital', 'Almora'])), isNull, reason: next);
      }
    });

    test('stay and taxi rows still name the card', () {
      expect(TripBarRules.nextTitle(_summary(next: 'taxi')), 'Local taxi');
      expect(TripBarRules.nextTitle(_summary(next: 'stay:2', cities: ['Nainital', 'Almora'])), 'Stay in Almora');
    });

    test('a bad guide step from the server is ignored', () {
      for (final bad in ['finish', 'stay:0', 'stay:100', '', 7, 'row; drop', 'stay:1\n']) {
        final t = _summary(guideStep: bad, next: 'taxi');
        expect(t.progress.guideStep, isNull, reason: '$bad');
        expect(TripBarRules.nextTitle(t), 'Local taxi');
      }
    });
  });
}
