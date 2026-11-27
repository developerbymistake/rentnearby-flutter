import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/trip_strings_archived.dart';
import 'package:bakhli/features/trip/widgets/trip_archived_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/archived_fixtures.dart';

final _opened = <String>[];

Future<void> _pump(WidgetTester t, TripModel trip, {Size size = const Size(390, 844), double textScale = 1}) async {
  _opened.clear();
  t.view.physicalSize = size * 3;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  GetPage stub(String name) => GetPage(name: name, page: () {
        _opened.add(name);
        return Scaffold(body: Text('stub $name'));
      });
  await t.pumpWidget(GetMaterialApp(
    home: TripArchivedView(trip: trip),
    getPages: [stub(AppRoutes.tripTravellers), stub(AppRoutes.tripMoneySummary)],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: true),
      child: child!,
    ),
  ));
  await t.pump();
}

TripModel _trip({Object? summary = const _Full()}) =>
    TripModel.fromJson(summary is _Full ? archivedTripJson() : archivedTripJson(summary: summary));

class _Full {
  const _Full();
}

void main() {
  tearDown(Get.reset);

  testWidgets('a full summary shows the note, the trip card, every city, taxi, travellers and expenses', (t) async {
    await _pump(t, _trip());
    expect(find.text(TripStringsArchived.title), findsOneWidget);
    expect(find.byKey(const ValueKey('trip_archived_note')), findsOneWidget);
    expect(find.text(TripStringsArchived.note), findsOneWidget);
    expect(find.byKey(const ValueKey('trip_archived_card')), findsOneWidget);
    expect(find.text('10-13 May 2026 · 4 days · 9 places · 3 travellers'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip_archived_city_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip_archived_city_1')), findsOneWidget);
    expect(find.text('Nainital · 2 nights'), findsOneWidget);
    expect(find.text('Naini Lake, Snow View Point +3 more'), findsOneWidget);
    expect(find.text('Stay: Lake Inn'), findsOneWidget);
    expect(find.text('Mukteshwar · 1 night'), findsOneWidget);
    expect(find.text('Chauli ki Jali'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip_archived_stay_1')), findsNothing);
    expect(find.byKey(const ValueKey('trip_archived_taxi')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip_archived_travellers')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip_archived_expenses')), findsOneWidget);
    expect(find.text(TripStringsArchived.spent(12450)), findsOneWidget);
  });

  testWidgets('no plan, map, stay, taxi request, edit, share or chat action is offered', (t) async {
    await _pump(t, _trip());
    for (final word in ['View plan', 'Map', 'Edit', 'Share', 'Copy', 'Chat', 'Find a taxi', 'Book your stay']) {
      expect(find.text(word), findsNothing, reason: word);
    }
  });

  testWidgets('a partial summary hides taxi, expenses, stays and travellers', (t) async {
    await _pump(t, _trip(summary: {
      'version': 1,
      'cities': [
        {'name': 'Shimla', 'nights': 2, 'spots': ['Mall Road']},
      ],
      'memberCount': 1,
    }));
    expect(find.byKey(const ValueKey('trip_archived_city_0')), findsOneWidget);
    expect(find.text('Mall Road'), findsOneWidget);
    expect(find.textContaining('+'), findsNothing);
    expect(find.byKey(const ValueKey('trip_archived_stay_0')), findsNothing);
    expect(find.byKey(const ValueKey('trip_archived_taxi')), findsNothing);
    expect(find.byKey(const ValueKey('trip_archived_travellers')), findsNothing);
    expect(find.byKey(const ValueKey('trip_archived_expenses')), findsNothing);
  });

  testWidgets('no summary falls back to the trip title, cities, dates and counts', (t) async {
    await _pump(t, _trip(summary: null));
    expect(find.text(TripStringsArchived.note), findsOneWidget);
    expect(find.text('Nainital & Mukteshwar'), findsWidgets);
    expect(find.text('10-13 May 2026 · 4 days · 9 places'), findsOneWidget);
    expect(find.text('Nainital'), findsOneWidget);
    expect(find.text('Mukteshwar'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip_archived_taxi')), findsNothing);
    expect(find.byKey(const ValueKey('trip_archived_expenses')), findsNothing);
  });

  testWidgets('+N more shows only when the city had more places than listed', (t) async {
    await _pump(t, _trip(summary: {
      'cities': [
        {'name': 'A', 'spots': ['x', 'y'], 'spotCount': 2},
        {'name': 'B', 'spots': ['z'], 'spotCount': 4},
      ],
    }));
    expect(find.text('x, y'), findsOneWidget);
    expect(find.text('z +3 more'), findsOneWidget);
  });

  testWidgets('a narrow phone with large text and long names does not overflow', (t) async {
    final long = 'Very long city name that keeps going and going' * 2;
    await _pump(
      t,
      _trip(summary: {
        'title': 'A trip with a really long title that will not fit on one line at all',
        'startDate': '2026-05-10',
        'endDate': '2026-06-13',
        'dayCount': 30,
        'spotCount': 99,
        'cities': [
          for (var i = 0; i < 4; i++)
            {
              'name': '$long $i',
              'nights': 12,
              'spots': [for (var j = 0; j < 6; j++) '$long spot $j'],
              'spotCount': 40,
              'stays': ['$long stay', '$long second stay'],
            },
        ],
        'taxiBooked': true,
        'memberCount': 12,
        'expensesTotal': 123456789,
      }),
      size: const Size(320, 640),
      textScale: 1.3,
    );
    expect(t.takeException(), isNull);
    await t.drag(find.byType(ListView), const Offset(0, -2000));
    await t.pump();
    expect(t.takeException(), isNull);
  });

  testWidgets('travellers row opens the travellers page', (t) async {
    await _pump(t, _trip());
    await t.ensureVisible(find.byKey(const ValueKey('trip_archived_travellers')));
    await t.tap(find.byKey(const ValueKey('trip_archived_travellers')));
    await t.pumpAndSettle();
    expect(_opened, [AppRoutes.tripTravellers]);
    expect(Get.arguments, {'tripId': 'arc-1'});
  });

  testWidgets('expenses row opens the money summary', (t) async {
    await _pump(t, _trip());
    await t.ensureVisible(find.byKey(const ValueKey('trip_archived_expenses')));
    await t.tap(find.byKey(const ValueKey('trip_archived_expenses')));
    await t.pumpAndSettle();
    expect(_opened, [AppRoutes.tripMoneySummary]);
    expect(Get.arguments, {'tripId': 'arc-1'});
  });

  testWidgets('TripArchiveSections without people and money hides those rows (viewer use)', (t) async {
    final trip = _trip();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: TripArchiveSections(summary: trip.archive!, showPeopleAndMoney: false))),
    ));
    expect(find.byKey(const ValueKey('trip_archived_route')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip_archived_taxi')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip_archived_travellers')), findsNothing);
    expect(find.byKey(const ValueKey('trip_archived_expenses')), findsNothing);
    expect(find.text('10-13 May 2026 · 4 days · 9 places'), findsOneWidget);
  });
}
