import 'dart:io';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/b/widgets/sliding_tabs.dart';
import 'package:bakhli/features/trip/trip_strings_dayplan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/real_phone.dart';

Widget _tabs(int days, int Function() selected, void Function(int) onDay) => Scaffold(
      body: StatefulBuilder(
        builder: (_, set) => SlidingTabs(
          key: const ValueKey('trip_map_day_chips'),
          labels: [for (var d = 1; d <= days; d++) TripStringsDayplan.dayTab(d)],
          selected: selected() - 1,
          tone: ListingTone.indigo,
          margin: DS.sym(h: 18),
          onTap: (i) => set(() => onDay(i + 1)),
        ),
      ),
    );

void main() {
  final src = File('lib/features/trip/screens/trip_map_screen.dart').readAsStringSync();

  setUp(DS.applyApproved);
  tearDown(DS.debugReset);

  test('the day pick is the sliding toggle of Day 1..N (no All), the 3-dot day menu is gone', () {
    expect(src, contains("ValueKey('trip_map_day_chips')"));
    final start = src.indexOf('SlidingTabs(');
    expect(start, greaterThan(0));
    final tabs = src.substring(start, src.indexOf('onTap: (i) => _select(i + 1)', start));
    expect(tabs, contains("key: const ValueKey('trip_map_day_chips')"));
    expect(tabs, contains('labels: [for (var d = 1; d <= p.days.length; d++) TripStringsDayplan.dayTab(d)]'));
    expect(tabs, contains('selected: selected == TripDayChips.all ? -1 : selected - 1'));
    expect(tabs, isNot(contains('includeAll')));
    expect(tabs, isNot(contains('icon')));
    expect(src, isNot(contains('TripDayChips(')));
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

  testWidgets('tabs show Day 1..N only, the pill moves to the tapped day and reports it', (t) async {
    var picked = 1;
    await pumpPhone(t, _tabs(3, () => picked, (d) => picked = d));
    await t.pumpAndSettle();
    for (final d in ['Day 1', 'Day 2', 'Day 3']) {
      expect(find.text(d), findsOneWidget);
    }
    expect(find.text('All'), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);
    Rect pill() => t.getRect(find.descendant(of: find.byType(AnimatedPositioned), matching: find.byType(DecoratedBox)).first);
    expect(pill().center.dx, closeTo(t.getRect(find.byKey(SlidingTabs.tabKey(0))).center.dx, 0.5));
    await t.tap(find.text('Day 2'));
    await t.pumpAndSettle();
    expect(picked, 2);
    expect(pill().center.dx, closeTo(t.getRect(find.byKey(SlidingTabs.tabKey(1))).center.dx, 0.5));
    expect(t.takeException(), isNull);
  });

  testWidgets('many days: the row scrolls sideways and the selected day stays visible', (t) async {
    var picked = 9;
    await pumpPhone(t, _tabs(9, () => picked, (d) => picked = d));
    await t.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final row = t.getRect(find.byType(SlidingTabs));
    final last = t.getRect(find.byKey(SlidingTabs.tabKey(8)));
    expect(last.left, greaterThanOrEqualTo(row.left - 0.5));
    expect(last.right, lessThanOrEqualTo(row.right + 0.5));
    await t.drag(find.byType(SingleChildScrollView), const Offset(2000, 0));
    await t.pumpAndSettle();
    await t.tap(find.byKey(SlidingTabs.tabKey(0)));
    await t.pumpAndSettle();
    expect(picked, 1);
    final first = t.getRect(find.byKey(SlidingTabs.tabKey(0)));
    expect(first.left, greaterThanOrEqualTo(row.left - 0.5));
    expect(t.takeException(), isNull);
  });
}
