import 'package:bakhli/features/seeker_home/seeker_quick_actions.dart';
import 'package:bakhli/features/seeker_home/strings/seeker_home_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_phone.dart';

final _now = DateTime(2026, 11, 22, 10);

void main() {
  group('FX-23 Add expense picks the trip (D-21)', () {
    test('no open trip: empty (toast and Trips tab)', () {
      final r = SeekerQuickActionTargets.openTrips(
        mine: [(id: 'a', title: 'Old', end: DateTime(2026, 11, 1), completed: false), (id: 'b', title: 'Done', end: null, completed: true)],
        shared: [(id: 'c', title: 'Past shared', end: DateTime(2026, 11, 21))],
        now: _now,
      );
      expect(r, isEmpty);
    });

    test('one open trip: that trip (ending today still counts)', () {
      final r = SeekerQuickActionTargets.openTrips(
        mine: [(id: 'a', title: 'Nainital', end: DateTime(2026, 11, 22), completed: false)],
        shared: const [],
        now: _now,
      );
      expect(r.map((t) => t.id), ['a']);
    });

    test('two open trips (own and shared): both, own first, no duplicates', () {
      final r = SeekerQuickActionTargets.openTrips(
        mine: [(id: 'a', title: 'Nainital', end: null, completed: false)],
        shared: [(id: 'b', title: 'Manali', end: DateTime(2026, 12, 3)), (id: 'a', title: 'Nainital', end: null)],
        now: _now,
      );
      expect(r.map((t) => t.id), ['a', 'b']);
    });

    test('lists not loaded yet: the Home card trip is used', () {
      final r = SeekerQuickActionTargets.openTrips(mine: const [], shared: const [], feedTripId: 't9', feedTitle: 'Rishikesh', now: _now);
      expect(r.single.id, 't9');
    });

    testWidgets('picker lists the trips and returns the tapped one', (t) async {
      String? picked;
      await pumpPhone(
        t,
        Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async => picked = await ExpenseTripPicker.show(ctx, const [ExpenseTripOption('a', 'Nainital'), ExpenseTripOption('b', 'Manali')]),
              child: const Text('open'),
            ),
          ),
        ),
        size: const Size(360, 640),
        textScale: 1.3,
      );
      await t.tap(find.text('open'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text(SeekerHomeStrings.expensePickTitle), findsOneWidget);
      expect(find.text('Nainital'), findsOneWidget);
      await t.tap(find.text('Manali'));
      await t.pump(const Duration(milliseconds: 400));
      expect(picked, 'b');
      expect(t.takeException(), isNull);
    });
  });

  test('FX-25 Trips module off: no Plan a trip and no My trips tiles', () {
    final on = SeekerQuickActions.defaults(tripsOn: true).map((a) => a.title).toList();
    final off = SeekerQuickActions.defaults(tripsOn: false).map((a) => a.title).toList();
    expect(on, containsAll([SeekerHomeStrings.tilePlanTitle, SeekerHomeStrings.tileTripsTitle]));
    expect(off, isNot(contains(SeekerHomeStrings.tilePlanTitle)));
    expect(off, isNot(contains(SeekerHomeStrings.tileTripsTitle)));
    expect(off, contains(SeekerHomeStrings.tileExpenseTitle));
  });
}
