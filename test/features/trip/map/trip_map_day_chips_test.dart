import 'dart:io';

import 'package:bakhli/features/trip/widgets/trip_day_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/real_phone.dart';

void main() {
  final src = File('lib/features/trip/screens/trip_map_screen.dart').readAsStringSync();

  test('the day pick is a visible chips row (no All), the 3-dot day menu is gone', () {
    expect(src, contains("ValueKey('trip_map_day_chips')"));
    final chips = src.substring(src.indexOf('TripDayChips('), src.indexOf("padding: DS.sym(h: 18),", src.indexOf('TripDayChips(')));
    expect(chips, isNot(contains('includeAll')));
    expect(src, isNot(contains('_dayMenu')));
    expect(src, isNot(contains('PopupMenuButton')));
    expect(src, isNot(contains('TripStringsV2Plan.allCities')));
  });

  test('Day 1 is selected when the map opens without a day', () {
    expect(src, contains('_plan.selectedMapDay.value = day ?? 1;'));
    expect(src, isNot(contains('defaultMapDay')));
    final plan = File('lib/features/trip/screens/trip_plan_screen.dart').readAsStringSync();
    expect(plan, contains('TripNavigation.openMap(day: 1,'));
  });

  testWidgets('chips show Day 1..N only and report the tapped day', (t) async {
    var picked = 1;
    await pumpPhone(
      t,
      Scaffold(
        body: StatefulBuilder(
          builder: (_, set) => TripDayChips(dayCount: 3, selected: picked, compact: true, onChanged: (d) => set(() => picked = d)),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    for (final d in ['Day 1', 'Day 2', 'Day 3']) {
      expect(find.text(d), findsOneWidget);
    }
    expect(find.text('All'), findsNothing);
    await t.tap(find.text('Day 2'));
    await t.pump(const Duration(milliseconds: 300));
    expect(picked, 2);
    expect(t.takeException(), isNull);
  });
}
