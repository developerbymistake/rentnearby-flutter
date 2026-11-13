import 'dart:async';

import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_summary_model.dart';
import 'package:bakhli/features/trip/widgets/trip_summary_day_card.dart';
import 'package:bakhli/features/trip/widgets/trip_summary_hero.dart';
import 'package:bakhli/features/trip/widgets/trip_summary_stats.dart';
import 'package:bakhli/features/trip/widgets/trip_summary_todo.dart';
import 'package:bakhli/features/trip/screens/trip_summary_screen.dart';
import 'package:bakhli/features/trip/trip_strings.dart';
import 'package:bakhli/features/trip/utils/trip_summary_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_test/flutter_test.dart';

TripSummaryRecord record({int total = 0, bool withNight = true}) => TripSummaryRecord.fromJson({
      'tripId': 't1',
      'title': 'Nainital with family and friends',
      'city': 'Nainital',
      'startDate': '2026-12-01',
      'endDate': '2026-12-03',
      'adults': 2,
      'kids': 1,
      'agreedTotal': total,
      'days': [
        {'day': 1, 'spots': ['Naini Lake', 'Mall Road'], 'minutes': 200},
        {'day': 2, 'spots': ['Snow View']},
        {'day': 3, 'spots': ['Bhimtal']},
      ],
      'nights': [
        if (withNight) {'night': 1, 'listingName': 'Hill View', 'displayStatus': 'confirmedByBoth'},
      ],
      'arrangements': [
        {'key': 'gettingThere', 'title': 'Getting there', 'state': 'confirmed'},
        {'key': 'stay:1', 'title': 'Stay in Nainital', 'state': 'todo'},
        {'key': 'taxi', 'title': 'Local taxi', 'state': 'asked'},
        {'key': 'comingBack', 'title': 'Coming back', 'state': 'skipped'},
      ],
    });

Future<void> pump(WidgetTester t, Widget child, double w, {double scale = 1}) async {
  t.view.physicalSize = Size(w, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(w, 900), textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
    ),
  ));
  await t.pump(const Duration(milliseconds: 700));
}

void main() {
  test('percent and todo come from shown rows', () {
    final r = record();
    expect(r.percentDone, 33);
    expect(r.stillToDo.map((a) => a.key.id), ['stay:1', 'taxi']);
  });

  testWidgets('total shown only when agreedTotal > 0', (t) async {
    await pump(t, TripSummaryStats(record: record()), 360);
    expect(find.text('Agreed total'), findsNothing);
    await pump(t, TripSummaryStats(record: record(total: 5400)), 360);
    expect(find.text('Agreed total'), findsOneWidget);
  });

  testWidgets('day chips for stay and taxi', (t) async {
    final r = record();
    final d1 = r.days.first;
    final d2 = r.days[1];
    expect(TripDayChips.stay(r, d1)!.label, contains('Confirmed'));
    expect(TripDayChips.stay(r, d2)!.label, startsWith('Stay:'));
    expect(TripDayChips.stay(r, r.days.last), isNull);
    expect(TripDayChips.taxi(r, d1)!.label, startsWith('Taxi:'));
    expect(TripDayChips.taxi(r, d2), isNull);
    await pump(t, TripSummaryDayCard(day: d1, stay: TripDayChips.stay(r, d1), taxi: TripDayChips.taxi(r, d1)), 360);
    expect(find.textContaining('Stay:'), findsOneWidget);
    expect(find.textContaining('Taxi:'), findsOneWidget);
  });

  testWidgets('still to do row opens that step', (t) async {
    TripEasyRowKey? opened;
    await pump(t, TripSummaryTodo(record: record(), onOpen: (k) => opened = k), 360);
    expect(find.text('Still to do'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('todo-stay:1')));
    expect(opened?.id, 'stay:1');
  });

  for (final w in [300.0, 360.0, 412.0, 560.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('no overflow at $w dp scale $scale', (t) async {
        final r = record(total: 125000);
        await pump(
          t,
          Column(children: [
            TripSummaryHero(record: r),
            TripSummaryStats(record: r),
            TripSummaryTodo(record: r, onOpen: (_) {}),
            for (final d in r.days) TripSummaryDayCard(day: d, stay: TripDayChips.stay(r, d), taxi: TripDayChips.taxi(r, d)),
          ]),
          w,
          scale: scale,
        );
        expect(t.takeException(), isNull);
      });
    }
  }

  group('whole screen', () {
    Future<void> pumpScreen(
      WidgetTester t,
      Future<TripSummarySnapshot> Function(String) loader, {
      double w = 360,
      double scale = 1,
      bool Function(Object)? isGone,
      Future<void>? Function(String, String)? opener,
    }) async {
      t.view.physicalSize = Size(w, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(GetMaterialApp(
        builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
        home: TripSummaryScreen(tripId: 't1', loader: loader, isGone: isGone ?? (_) => false, opener: opener),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 900));
    }

    final share = find.text('Share trip');

    testWidgets('loading shows skeleton then content', (t) async {
      final gate = Completer<TripSummarySnapshot>();
      await pumpScreen(t, (_) => gate.future);
      expect(find.text('Still to do'), findsNothing);
      expect(share, findsNothing);
      gate.complete(TripSummarySnapshot(record()));
      await t.pump();
      await t.pump(const Duration(milliseconds: 900));
      expect(find.text('Still to do'), findsOneWidget);
      expect(share, findsOneWidget);
    });

    testWidgets('error shows Retry and Retry reloads', (t) async {
      var calls = 0;
      await pumpScreen(t, (_) async {
        calls++;
        if (calls == 1) throw DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.badResponse);
        return TripSummarySnapshot(record());
      });
      expect(find.text(TripStrings.couldNotLoad), findsOneWidget);
      expect(share, findsNothing);
      await t.tap(find.text('Retry'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 900));
      expect(calls, 2);
      expect(find.text('Still to do'), findsOneWidget);
    });

    testWidgets('gone trip shows the not found view and no share bar', (t) async {
      await pumpScreen(t, (_) async => throw Exception('gone'), isGone: (_) => true);
      expect(find.text(TripStrings.tripNotFoundTitle), findsOneWidget);
      expect(share, findsNothing);
    });

    testWidgets('offline copy shows the saved strip', (t) async {
      await pumpScreen(t, (_) async => TripSummarySnapshot(record(), cachedAt: DateTime(2026, 11, 12, 9, 30)));
      expect(find.textContaining('Offline copy'), findsOneWidget);
      expect(find.text('Still to do'), findsOneWidget);
    });

    testWidgets('pull to refresh loads again', (t) async {
      var calls = 0;
      await pumpScreen(t, (_) async {
        calls++;
        return TripSummarySnapshot(record());
      });
      await t.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      expect(calls, 2);
    });

    testWidgets('empty record shows nothing here and no share bar', (t) async {
      await pumpScreen(t, (_) async => TripSummarySnapshot(TripSummaryRecord.fromJson({'tripId': 't1', 'city': 'Nainital'})));
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(share, findsNothing);
    });

    testWidgets('Still to do row opens the plan then reloads the summary', (t) async {
      var loads = 0;
      String? opened;
      await pumpScreen(
        t,
        (_) async {
          loads++;
          return TripSummarySnapshot(record());
        },
        opener: (id, row) async => opened = row,
      );
      expect(loads, 1);
      await t.ensureVisible(find.byKey(const ValueKey('todo-stay:1')));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byKey(const ValueKey('todo-stay:1')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 900));
      expect(opened, 'stay:1');
      expect(loads, 2);
    });

    testWidgets('completed trip hides Still to do, shows Trip completed, keeps days and share', (t) async {
      final r = TripSummaryRecord.fromJson({
        'tripId': 't1',
        'city': 'Nainital',
        'startDate': '2026-12-01',
        'endDate': '2026-12-03',
        'status': 'completed',
        'days': [
          {'day': 1, 'spots': ['Naini Lake']},
        ],
        'arrangements': [
          {'key': 'stay:1', 'title': 'Stay in Nainital', 'state': 'todo'},
        ],
      });
      await pumpScreen(t, (_) async => TripSummarySnapshot(r));
      expect(find.text('Still to do'), findsNothing);
      expect(find.text('Trip completed'), findsOneWidget);
      expect(find.text('Naini Lake'), findsOneWidget);
      expect(share, findsOneWidget);
    });

    for (final w in [300.0, 360.0, 412.0, 560.0]) {
      testWidgets('full screen without overflow at $w dp scale 2', (t) async {
        await pumpScreen(t, (_) async => TripSummarySnapshot(record(total: 125000), cachedAt: DateTime(2026, 11, 12, 9, 30)), w: w, scale: 2);
        expect(t.takeException(), isNull);
        expect(find.text('Still to do'), findsOneWidget);
      });
    }
  });
}
