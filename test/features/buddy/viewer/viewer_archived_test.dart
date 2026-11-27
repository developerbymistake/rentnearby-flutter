import 'package:bakhli/design/tokens/design_scale.dart';
import 'package:bakhli/features/buddy/buddy_live.dart';
import 'package:bakhli/features/buddy/viewer/controllers/viewer_trip_controller.dart';
import 'package:bakhli/features/buddy/viewer/data/viewer_trip_cache.dart';
import 'package:bakhli/features/buddy/viewer/models/viewer_models.dart' as vm;
import 'package:bakhli/features/buddy/viewer/screens/viewer_day_plan_screen.dart';
import 'package:bakhli/features/buddy/viewer/screens/viewer_map_screen.dart';
import 'package:bakhli/features/buddy/viewer/screens/viewer_trip_screen.dart';
import 'package:bakhli/features/buddy/viewer/viewer_deps.dart';
import 'package:bakhli/features/buddy/viewer/widgets/shared_trip_card.dart';
import 'package:bakhli/features/trip/trip_strings_archived.dart';
import 'package:bakhli/features/trip/utils/trip_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../trip/support/archived_fixtures.dart';
import 'viewer_fixtures.dart';

Map<String, dynamic> s14ArchivedJson() => {
      ...s14Json(),
      'archived': true,
      'summary': archivedSummaryJson(),
      'legs': <Object>[],
      'days': <Object>[],
    };

vm.ViewerTrip s14Archived() => vm.ViewerTrip.fromJson(s14ArchivedJson());

Future<void> _pump(WidgetTester t, Widget home) async {
  t.view.devicePixelRatio = 2;
  t.view.physicalSize = const Size(784, 1600);
  addTearDown(t.view.reset);
  await t.pumpWidget(app(home));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    DS.applyApproved();
    opened.clear();
    useMemoryCache();
    TripClock.clockUtc = () => DateTime.utc(2026, 11, 27, 6);
  });
  tearDown(() {
    DS.debugReset();
    ViewerDeps.debugReset();
    ViewerTripCache.debugReset();
    TripClock.resetClock();
    BuddyLive.reset();
    Get.reset();
  });

  testWidgets('archived overview: note and summary instead of itinerary, taxi and stay; travellers and expenses kept; no chat', (t) async {
    final api = FakeViewerApi()..queueViews([viewOk(s14Archived())]);
    registerViewerFakes(api: api, ledger: FakeViewerLedger());
    await _pump(t, ViewerTripScreen(tripId: tripId, api: api));
    expect(find.byKey(const ValueKey('trip_archived_note')), findsOneWidget);
    expect(find.text(TripStringsArchived.note), findsOneWidget);
    expect(find.byKey(const ValueKey('trip_archived_card')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip_archived_city_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('viewer_itinerary_card')), findsNothing);
    expect(find.byKey(const ValueKey('viewer_taxi_card')), findsNothing);
    expect(find.byKey(const ValueKey('viewer_stay_card')), findsNothing);
    expect(find.byKey(const ValueKey('viewer_trip_chat')), findsNothing);
    expect(find.byKey(const ValueKey('trip_archived_travellers')), findsNothing);
    expect(find.byKey(const ValueKey('trip_archived_expenses')), findsNothing);
    expect(find.byKey(const ValueKey('viewer_travellers_card'), skipOffstage: false), findsOneWidget);
    expect(find.byKey(const ValueKey('viewer_expenses_card'), skipOffstage: false), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a normal trip still shows the itinerary card', (t) async {
    final api = FakeViewerApi()..queueViews([viewOk(s14())]);
    registerViewerFakes(api: api, ledger: FakeViewerLedger());
    await _pump(t, ViewerTripScreen(tripId: tripId, api: api));
    expect(find.byKey(const ValueKey('viewer_itinerary_card')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip_archived_note')), findsNothing);
  });

  test('the offline copy keeps archived and summary', () {
    ViewerTripCache.write(tripId, s14Archived(), '"v1"');
    final back = ViewerTripCache.read(tripId)!.trip;
    expect(back.archived, isTrue);
    expect(back.archive!.cities.map((c) => c.name), ['Nainital', 'Mukteshwar']);
  });

  testWidgets('archived day plan shows the note and the summary, no empty itinerary', (t) async {
    final api = FakeViewerApi()..queueViews([viewOk(s14Archived())]);
    registerViewerFakes(api: api, ledger: FakeViewerLedger());
    await _pump(t, ViewerDayPlanScreen(tripId: tripId, api: api));
    expect(find.byKey(const ValueKey('trip_archived_note')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip_archived_route')), findsOneWidget);
    expect(find.byKey(const ValueKey('viewer_map')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('archived map shows the note instead of an empty map', (t) async {
    t.view.devicePixelRatio = 2;
    t.view.physicalSize = const Size(784, 1600);
    addTearDown(t.view.reset);
    final c = Get.put(ViewerTripController(tripId, api: FakeViewerApi(), ledger: FakeViewerLedger()), tag: tripId);
    c.trip.value = s14Archived();
    await t.pumpWidget(app(ViewerMapScreen(tripId: tripId, mapBuilder: (_, v) => const ColoredBox(color: Colors.white))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('trip_archived_note')), findsOneWidget);
    expect(find.text(TripStringsArchived.note), findsOneWidget);
  });

  testWidgets('a shared card of an archived trip carries the Archived tag', (t) async {
    final json = (sample('s15_shared')['items'] as List).first as Map<String, dynamic>;
    await _pump(
      t,
      Scaffold(
        body: ListView(children: [
          SharedTripCard(trip: vm.SharedTripCard.fromJson({...json, 'archived': true})),
          SharedTripCard(trip: vm.SharedTripCard.fromJson({...json, 'tripId': 'other'})),
        ]),
      ),
    );
    expect(find.byKey(const ValueKey('shared_card_archived')), findsOneWidget);
    expect(find.text(TripStringsArchived.archivedTag), findsOneWidget);
  });
}
