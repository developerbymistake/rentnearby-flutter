import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_bar_rules.dart';
import 'package:bakhli/features/trip/utils/trip_parts.dart';
import 'package:flutter_test/flutter_test.dart';

const _stay = TripEasyRowKind.stay;
const _taxi = TripEasyRowKind.taxi;

TripParts _p(List<(TripEasyRowKind, TripRowState)> rows, {bool itinerary = true}) =>
    TripParts.from(hasItinerary: itinerary, rows: rows);

TripSummaryModel _summary(List<TripEasyRowModel> rows, {int spots = 4, List<String>? cities}) => TripSummaryModel(
      id: 't',
      title: '',
      status: 'Planned',
      cityName: 'Nainital',
      dayCount: 3,
      spotCount: spots,
      category: 'trip',
      updatedAt: DateTime(2026, 11, 1),
      legCount: cities?.length ?? 1,
      legCities: cities,
      progress: TripProgress(total: 5, done: 0, percent: 0, rows: rows),
    );

TripEasyRowModel _row(TripEasyRowKind k, TripRowState s, [int? leg]) => TripEasyRowModel(key: TripEasyRowKey(k, leg), state: s);

void main() {
  group('percent', () {
    test('unsaved or empty plan with nothing arranged is 0', () {
      expect(_p([(_stay, TripRowState.todo), (_taxi, TripRowState.todo)], itinerary: false).percent, 0);
    });

    test('saved itinerary only is 33', () {
      final p = _p([(_stay, TripRowState.todo), (_taxi, TripRowState.todo)]);
      expect((p.handled, p.percent, p.complete), (1, 33, false));
    });

    test('asked counts as arranged', () {
      expect(_p([(_stay, TripRowState.todo), (_taxi, TripRowState.asked)]).percent, 67);
      expect(_p([(_stay, TripRowState.asked), (_taxi, TripRowState.todo)]).percent, 67);
    });

    test('skipped counts as handled', () {
      final p = _p([(_stay, TripRowState.skipped), (_taxi, TripRowState.skipped)]);
      expect((p.percent, p.complete, p.stay, p.taxi), (100, true, TripPartState.skipped, TripPartState.skipped));
    });

    test('everything arranged is 100', () {
      expect(_p([(_stay, TripRowState.confirmed), (_taxi, TripRowState.own)]).percent, 100);
    });

    test('attention and todo are open', () {
      final p = _p([(_stay, TripRowState.attention), (_taxi, TripRowState.attention)]);
      expect((p.stay, p.taxi), (TripPartState.open, TripPartState.open));
    });
  });

  group('stay over many cities', () {
    test('one city asked is enough', () {
      expect(_p([(_stay, TripRowState.asked), (_stay, TripRowState.todo), (_taxi, TripRowState.todo)]).stay, TripPartState.arranged);
    });

    test('skipped needs every city skipped', () {
      expect(_p([(_stay, TripRowState.skipped), (_stay, TripRowState.todo)]).stay, TripPartState.open);
      expect(_p([(_stay, TripRowState.skipped), (_stay, TripRowState.skipped)]).stay, TripPartState.skipped);
    });
  });

  group('next', () {
    test('stay comes before taxi', () {
      expect(_p([(_stay, TripRowState.todo), (_taxi, TripRowState.todo)]).next, TripPart.stay);
      expect(_p([(_stay, TripRowState.asked), (_taxi, TripRowState.todo)]).next, TripPart.taxi);
      expect(_p([(_stay, TripRowState.asked), (_taxi, TripRowState.asked)]).next, isNull);
    });
  });

  group('summary', () {
    test('old travel rows do not change the answer', () {
      final reduced = _summary([_row(_stay, TripRowState.asked, 1), _row(_taxi, TripRowState.todo)]);
      final old = _summary([
        _row(TripEasyRowKind.gettingThere, TripRowState.todo),
        _row(_stay, TripRowState.asked, 1),
        _row(_taxi, TripRowState.todo),
        _row(TripEasyRowKind.comingBack, TripRowState.todo),
      ]);
      expect(old.parts, reduced.parts);
      expect(old.parts.percent, 67);
    });

    test('zero places keeps the itinerary open', () {
      expect(_summary(const [], spots: 0).parts.itinerary, TripPartState.open);
    });

    test('ready and next title follow the parts, not the server totals', () {
      final done = _summary([_row(_stay, TripRowState.skipped, 1), _row(_taxi, TripRowState.skipped)]);
      expect(TripBarRules.isReady(done), isTrue);
      expect(TripBarRules.nextTitle(done), isNull);
      final open = _summary([_row(_stay, TripRowState.asked, 1), _row(_stay, TripRowState.todo, 2), _row(_taxi, TripRowState.todo)],
          cities: ['Nainital', 'Almora']);
      expect(TripBarRules.isReady(open), isFalse);
      expect(TripBarRules.nextTitle(open), 'Local taxi');
      final stayFirst = _summary([_row(_stay, TripRowState.asked, 1), _row(_stay, TripRowState.todo, 2), _row(_taxi, TripRowState.skipped)],
          cities: ['Nainital', 'Almora']);
      expect(stayFirst.parts.next, isNull);
      final stayOpen = _summary([_row(_stay, TripRowState.todo, 1), _row(_stay, TripRowState.todo, 2), _row(_taxi, TripRowState.todo)],
          cities: ['Nainital', 'Almora']);
      expect(TripBarRules.nextTitle(stayOpen), contains('Nainital'));
    });

    test('Complete my plan shows only on a live trip with places below 100', () {
      final open = _summary([_row(_stay, TripRowState.todo, 1), _row(_taxi, TripRowState.todo)]);
      expect(TripBarRules.canCompletePlan(open, past: false), isTrue);
      expect(TripBarRules.canCompletePlan(open, past: true), isFalse);
      expect(TripBarRules.canCompletePlan(_summary([_row(_taxi, TripRowState.todo)], spots: 0), past: false), isFalse);
      final done = _summary([_row(_stay, TripRowState.asked, 1), _row(_taxi, TripRowState.skipped)]);
      expect(TripBarRules.canCompletePlan(done, past: false), isFalse);
    });
  });
}
