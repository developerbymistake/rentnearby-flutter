import 'package:bakhli/features/buddy/viewer/models/viewer_models.dart';
import 'package:bakhli/features/trip/models/trip_archive_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/trip_strings_archived.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/archived_fixtures.dart';

void main() {
  group('TripArchiveSummary.tryParse', () {
    test('a full summary parses every field', () {
      final s = TripArchiveSummary.tryParse(archivedSummaryJson())!;
      expect(s.version, 1);
      expect(s.title, 'Nainital & Mukteshwar');
      expect(s.startDate, DateTime(2026, 5, 10));
      expect(s.endDate, DateTime(2026, 5, 13));
      expect(s.dayCount, 4);
      expect(s.spotCount, 9);
      expect(s.cities.map((c) => c.name), ['Nainital', 'Mukteshwar']);
      expect(s.cities.first.nights, 2);
      expect(s.cities.first.spots, ['Naini Lake', 'Snow View Point']);
      expect(s.cities.first.moreSpots, 3);
      expect(s.cities.first.stays, ['Lake Inn']);
      expect(s.cities.last.moreSpots, 0);
      expect(s.taxiBooked, isTrue);
      expect(s.memberCount, 3);
      expect(s.expensesTotal, 12450);
    });

    test('a partial summary leaves the missing parts empty', () {
      final s = TripArchiveSummary.tryParse({'version': 1, 'cities': [{'name': 'Shimla'}]})!;
      expect(s.title, isNull);
      expect(s.startDate, isNull);
      expect(s.cities.single.name, 'Shimla');
      expect(s.cities.single.nights, 0);
      expect(s.cities.single.spots, isEmpty);
      expect(s.cities.single.spotCount, isNull);
      expect(s.cities.single.moreSpots, 0);
      expect(s.taxiBooked, isFalse);
      expect(s.memberCount, isNull);
      expect(s.expensesTotal, isNull);
    });

    test('garbage values are ignored, never thrown', () {
      final s = TripArchiveSummary.tryParse({
        'version': 'x',
        'title': 42,
        'startDate': 'not a date',
        'dayCount': -3,
        'cities': [
          'Nainital',
          {'name': ''},
          {'name': '  '},
          {'name': 'Almora', 'nights': 'two', 'spots': [1, '', 'Kasar Devi'], 'stays': 'Inn'},
        ],
        'taxiBooked': 'yes',
        'memberCount': 'three',
        'expensesTotal': -10,
      })!;
      expect(s.version, 1);
      expect(s.title, isNull);
      expect(s.startDate, isNull);
      expect(s.dayCount, isNull);
      expect(s.cities.single.name, 'Almora');
      expect(s.cities.single.nights, 0);
      expect(s.cities.single.spots, ['Kasar Devi']);
      expect(s.cities.single.stays, isEmpty);
      expect(s.taxiBooked, isFalse);
      expect(s.memberCount, isNull);
      expect(s.expensesTotal, isNull);
    });

    test('not a map gives null', () {
      expect(TripArchiveSummary.tryParse(null), isNull);
      expect(TripArchiveSummary.tryParse('summary'), isNull);
      expect(TripArchiveSummary.tryParse([1, 2]), isNull);
    });

    test('spot names are capped at 6', () {
      final s = TripArchiveSummary.tryParse({
        'cities': [
          {'name': 'Manali', 'spots': ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'], 'spotCount': 8},
        ],
      })!;
      expect(s.cities.single.spots, hasLength(TripArchiveCity.maxSpots));
      expect(s.cities.single.moreSpots, 2);
    });

    test('toJson round trip keeps the summary', () {
      final s = TripArchiveSummary.tryParse(archivedSummaryJson())!;
      final back = TripArchiveSummary.tryParse(s.toJson())!;
      expect(back.toJson(), s.toJson());
      expect(s.toJson()['startDate'], '2026-05-10');
      expect(s.toJson()['cities'], archivedSummaryJson()['cities']);
    });

    test('toJson omits taxi and expenses when there are none', () {
      final j = const TripArchiveSummary(cities: [TripArchiveCity(name: 'Shimla')]).toJson();
      expect(j.containsKey('taxiBooked'), isFalse);
      expect(j.containsKey('expensesTotal'), isFalse);
      expect(j.containsKey('memberCount'), isFalse);
    });

    test('fallback builds from the trip columns', () {
      final s = TripArchiveSummary.fallback(title: ' ', legCities: const ['Nainital', '', 'Almora'], dayCount: 0, spotCount: 4);
      expect(s.title, isNull);
      expect(s.cities.map((c) => c.name), ['Nainital', 'Almora']);
      expect(s.dayCount, isNull);
      expect(s.spotCount, 4);
    });
  });

  group('TripModel archived', () {
    test('archived trip with an empty plan parses, keeps the summary and the route', () {
      final t = TripModel.fromJson(archivedTripJson());
      expect(t.archived, isTrue);
      expect(t.archivedAt, DateTime.utc(2026, 8, 20));
      expect(t.archive, isNotNull);
      expect(t.archive!.cities, hasLength(2));
      expect(t.legCities, ['Nainital', 'Mukteshwar']);
      expect(t.plan.days, isEmpty);
      expect(t.archiveOrFallback, same(t.archive));
    });

    test('archived trip with plan null does not crash', () {
      final t = TripModel.fromJson(archivedTripJson(plan: null));
      expect(t.archived, isTrue);
      expect(t.plan.days, isEmpty);
      expect(t.plan.legs.single.cityKey, 7);
      expect(t.plan.legs.single.cityName, 'Nainital');
    });

    test('archived trip with the plan missing does not crash', () {
      final t = TripModel.fromJson(archivedTripJson(withPlan: false));
      expect(t.archived, isTrue);
      expect(t.plan.days, isEmpty);
      expect(t.plan.legs, hasLength(1));
    });

    test('archived without a summary falls back to the trip columns', () {
      final t = TripModel.fromJson(archivedTripJson(summary: null));
      expect(t.archive, isNull);
      final s = t.archiveOrFallback;
      expect(s.title, 'Nainital & Mukteshwar');
      expect(s.cities.map((c) => c.name), ['Nainital', 'Mukteshwar']);
      expect(s.dayCount, 4);
      expect(s.spotCount, 9);
      expect(s.startDate, DateTime(2026, 5, 10));
    });

    test('a normal trip is not archived and ignores a stray summary', () {
      final json = archivedTripJson()..remove('archived')..remove('archivedAt');
      final t = TripModel.fromJson(json);
      expect(t.archived, isFalse);
      expect(t.archivedAt, isNull);
      expect(t.archive, isNull);
    });

    test('archived false is not archived', () {
      final t = TripModel.fromJson({...archivedTripJson(), 'archived': false});
      expect(t.archived, isFalse);
      expect(t.archive, isNull);
    });

    test('copyWith keeps the archived fields', () {
      final t = TripModel.fromJson(archivedTripJson()).copyWith(title: 'x');
      expect(t.archived, isTrue);
      expect(t.archivedAt, isNotNull);
      expect(t.archive!.cities, hasLength(2));
    });
  });

  group('TripSummaryModel archived', () {
    test('list item carries archived', () {
      final s = TripSummaryModel.fromJson(archivedListItemJson());
      expect(s.archived, isTrue);
      expect(s.archivedAt, DateTime.utc(2026, 8, 20));
      expect(s.routeLine, isNot(isEmpty));
    });

    test('missing archived = not archived', () {
      final s = TripSummaryModel.fromJson(archivedListItemJson()..remove('archived')..remove('archivedAt'));
      expect(s.archived, isFalse);
      expect(s.archivedAt, isNull);
    });

    test('withMuted and asCompleted keep archived', () {
      final s = TripSummaryModel.fromJson(archivedListItemJson());
      expect(s.withMuted(DateTime(2026)).archived, isTrue);
      expect(s.asCompleted(DateTime(2026)).archived, isTrue);
    });

    test('TripListPage parses an archived item beside a normal one', () {
      final normal = archivedListItemJson(id: 'n1')..remove('archived');
      final page = TripListPage.fromJson({'items': [archivedListItemJson(), normal], 'hasMore': false});
      expect(page.items.map((i) => i.archived), [true, false]);
    });
  });

  group('Viewer models archived', () {
    Map<String, dynamic> viewer({bool archived = true}) => {
          'tripId': 'arc-1',
          'title': 'Nainital & Mukteshwar',
          'status': 'Completed',
          'role': 'Viewer',
          'owner': {'name': 'Asha'},
          'legCities': ['Nainital', 'Mukteshwar'],
          'dayCount': 4,
          'spotCount': 9,
          'legs': <Object>[],
          'days': <Object>[],
          if (archived) 'archived': true,
          if (archived) 'summary': archivedSummaryJson(),
        };

    test('ViewerTrip parses archived and summary, and toJson keeps them for the offline copy', () {
      final t = ViewerTrip.fromJson(viewer());
      expect(t.archived, isTrue);
      expect(t.archive!.cities, hasLength(2));
      final back = ViewerTrip.fromJson(t.toJson());
      expect(back.archived, isTrue);
      expect(back.archive!.toJson(), t.archive!.toJson());
    });

    test('ViewerTrip without archived is not archived and toJson adds nothing', () {
      final t = ViewerTrip.fromJson(viewer(archived: false));
      expect(t.archived, isFalse);
      expect(t.archive, isNull);
      expect(t.toJson().containsKey('archived'), isFalse);
      expect(t.toJson().containsKey('summary'), isFalse);
    });

    test('SharedTripCard parses archived; missing = false', () {
      expect(SharedTripCard.fromJson({'tripId': 'a', 'archived': true}).archived, isTrue);
      expect(SharedTripCard.fromJson({'tripId': 'a'}).archived, isFalse);
    });
  });

  group('TripStringsArchived', () {
    test('nights and city line', () {
      expect(TripStringsArchived.nights(1), '1 night');
      expect(TripStringsArchived.nights(3), '3 nights');
      expect(TripStringsArchived.cityLine('Nainital', 2), 'Nainital · 2 nights');
      expect(TripStringsArchived.cityLine('Nainital', 0), 'Nainital');
    });

    test('days and places drop zero parts', () {
      expect(TripStringsArchived.daysPlaces(4, 9), '4 days · 9 places');
      expect(TripStringsArchived.daysPlaces(1, 1), '1 day · 1 place');
      expect(TripStringsArchived.daysPlaces(0, 3), '3 places');
      expect(TripStringsArchived.daysPlaces(0, 0), '');
    });

    test('stays and more spots', () {
      expect(TripStringsArchived.stays(const ['Lake Inn', 'Pine Stay']), 'Stay: Lake Inn, Pine Stay');
      expect(TripStringsArchived.moreSpots(3), '+3 more');
    });

    test('title from cities when the trip has no title', () {
      expect(TripStringsArchived.citiesTitle('Nainital', 'Mukteshwar', 2), 'Nainital & Mukteshwar');
      expect(TripStringsArchived.citiesTitle('Delhi', 'Manali', 3), 'Delhi to Manali');
    });
  });
}
