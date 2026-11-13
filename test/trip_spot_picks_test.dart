import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/utils/trip_spot_picks.dart';
import 'package:flutter_test/flutter_test.dart';

TripSpotModel _s(String id, String cat, int rank, {bool featured = false, double lat = 29.0, double lng = 79.0}) =>
    TripSpotModel(
      id: id,
      source: 's',
      name: id,
      latitude: lat,
      longitude: lng,
      category: cat,
      visitMinutes: 60,
      rank: rank,
      isFeatured: featured,
    );

void main() {
  group('mustSee', () {
    test('hidden without a featured spot', () {
      expect(TripSpotPicks.mustSee([_s('a', 'lake', 1), _s('b', 'lake', 2)]), isEmpty);
    });

    test('featured first then rank, capped at 8', () {
      final items = [
        for (var i = 1; i <= 12; i++) _s('s$i', 'lake', i, featured: i == 10 || i == 11),
      ];
      final out = TripSpotPicks.mustSee(items).map((e) => e.id).toList();
      expect(out.take(2), ['s10', 's11']);
      expect(out.length, 8);
      expect(out[2], 's1');
    });
  });

  group('nearest', () {
    final from = _s('a', 'lake', 1);
    final near = _s('b', 'lake', 2, lat: 29.01);
    final far = _s('c', 'lake', 3, lat: 29.2);

    test('straight line when the book is empty', () {
      final n = TripSpotPicks.nearest(from, [far, near], TripMinutesBook())!;
      expect(n.spot.id, 'b');
      expect(n.minutes, isNull);
      expect(TripSpotPicks.nearbyText(from, n), matches(RegExp(r'^b is about [\d.]+ km from a\. Add it\?$')));
    });

    test('road minutes win over straight line when known', () {
      final book = TripMinutesBook()
        ..put(const TripSpotMinutes(['a', 'b', 'c'], [
          [0, 40, 10],
          [40, 0, 5],
          [10, 5, 0],
        ]));
      final n = TripSpotPicks.nearest(from, [near, far], book)!;
      expect(n.spot.id, 'c');
      expect(n.minutes, 10);
      expect(TripSpotPicks.nearbyText(from, n), 'c is 10 min from a. Add it?');
    });

    test('null for no candidates', () {
      expect(TripSpotPicks.nearest(from, [from], TripMinutesBook()), isNull);
    });
  });

  group('route', () {
    final a = _s('a', 'lake', 1);
    final b = _s('b', 'lake', 2, lat: 29.1);
    final c = _s('c', 'lake', 3, lat: 29.2);

    test('hidden below 2 places', () {
      expect(TripSpotPicks.route([a], TripMinutesBook()), isNull);
    });

    test('km only without minutes, never shown as minutes', () {
      final r = TripSpotPicks.route([a, b, c], TripMinutesBook())!;
      expect(r.minutes, isNull);
      expect(r.km, greaterThan(20));
      expect(TripSpotPicks.routeText(r), matches(RegExp(r'^Your 3 places · about \d+ km$')));
    });

    test('minutes follow nearest-neighbour order', () {
      final book = TripMinutesBook()
        ..put(const TripSpotMinutes(['a', 'b', 'c'], [
          [0, 30, 10],
          [30, 0, 15],
          [10, 15, 0],
        ]));
      final r = TripSpotPicks.route([a, b, c], book)!;
      expect(r.minutes, 25);
      expect(TripSpotPicks.routeText(r), 'Your 3 places · about 25 min of driving');
    });

    test('a missing pair falls back to km', () {
      final book = TripMinutesBook()
        ..put(const TripSpotMinutes(['a', 'b', 'c'], [
          [0, 30, null],
          [30, 0, 15],
          [null, 15, 0],
        ]));
      expect(TripSpotPicks.route([a, b, c], book)!.minutes, isNull);
    });
  });

  group('TripSpotMinutes.fromJson', () {
    test('unavailable returns null', () {
      expect(TripSpotMinutes.fromJson({'available': false}), isNull);
    });

    test('parses nulls and rounds', () {
      final m = TripSpotMinutes.fromJson({
        'available': true,
        'ids': ['a', 'b'],
        'minutes': [
          [0, 12],
          [null, 0],
        ],
      })!;
      final book = TripMinutesBook()..put(m);
      expect(book.between('a', 'b'), 12);
      expect(book.between('b', 'a'), 12);
    });

    test('shape mismatch returns null', () {
      expect(TripSpotMinutes.fromJson({'available': true, 'ids': ['a', 'b'], 'minutes': [[0, 1]]}), isNull);
    });
  });
}
