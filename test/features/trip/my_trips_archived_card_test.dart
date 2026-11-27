import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/screens/my_trips_screen.dart';
import 'package:bakhli/features/trip/trip_strings.dart';
import 'package:bakhli/features/trip/trip_strings_a5.dart';
import 'package:bakhli/features/trip/trip_strings_archived.dart';
import 'package:bakhli/features/trip/trip_strings_v2_plan.dart';
import 'package:bakhli/features/trip/utils/trip_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../journeys/fake_api.dart';
import 'support/archived_fixtures.dart';

class _FakeMyTrips extends MyTripsController {
  final deleted = <String>[];

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> load() async {
    pastOpen.value = true;
    past.assignAll([TripSummaryModel.fromJson(archivedListItemJson()), _normalPast()]);
  }

  @override
  Future<void> loadPast() async {}

  @override
  Future<void> loadMore() async {}

  @override
  Future<bool> delete(String id) async {
    deleted.add(id);
    return true;
  }
}

TripSummaryModel _normalPast() => TripSummaryModel(
      id: 'p1',
      title: 'Mussoorie',
      status: TripStatuses.planned,
      cityName: 'Mussoorie',
      dayCount: 3,
      spotCount: 6,
      category: 'trip',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 7),
      updatedAt: DateTime(2026, 10, 7),
      progress: const TripProgress(total: 2, done: 1, percent: 50),
    );

final _opened = <Object?>[];

Future<_FakeMyTrips> _pump(WidgetTester t) async {
  t.view.physicalSize = const Size(400, 2000) * 3;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  TripClock.clockUtc = () => DateTime.utc(2026, 11, 27, 6, 30);
  addTearDown(TripClock.resetClock);
  _opened.clear();
  final c = _FakeMyTrips();
  Get.put<MyTripsController>(c);
  await t.pumpWidget(GetMaterialApp(
    home: const MyTripsScreen(),
    getPages: [
      GetPage(name: AppRoutes.tripArchived, page: () {
        _opened.add(Get.arguments);
        return const Scaffold(body: Text('archived stub'));
      }),
      GetPage(name: AppRoutes.tripPlan, page: () => const Scaffold(body: Text('plan stub'))),
      GetPage(name: AppRoutes.tripOverview, page: () => const Scaffold(body: Text('overview stub'))),
    ],
  ));
  await c.load();
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(seconds: 2));
  return c;
}

Finder get _archivedCard => find.byKey(const ValueKey('parc-1'));
Finder get _normalCard => find.byKey(const ValueKey('pp1'));

Future<void> _openMenu(WidgetTester t, Finder card) async {
  await t.ensureVisible(card);
  await t.tap(find.descendant(of: card, matching: find.byKey(const ValueKey('hub-card-menu'))));
  await t.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('archived_card_gs').path);
    await GetStorage.init();
  });
  tearDown(Get.reset);

  testWidgets('an archived past card shows the title, dates, cities and the Archived tag, no ring or strip', (t) async {
    installFakeApi(const []);
    await _pump(t);
    await t.ensureVisible(_archivedCard);
    expect(find.descendant(of: _archivedCard, matching: find.text('Nainital & Mukteshwar')), findsOneWidget);
    expect(find.descendant(of: _archivedCard, matching: find.byKey(const ValueKey('hub-card-archived'))), findsOneWidget);
    expect(find.descendant(of: _archivedCard, matching: find.text(TripStringsArchived.archivedTag)), findsOneWidget);
    expect(find.descendant(of: _archivedCard, matching: find.byKey(const ValueKey('hub-card-archived-route'))), findsOneWidget);
    expect(find.descendant(of: _archivedCard, matching: find.text('4 days · 9 places')), findsOneWidget);
    expect(find.descendant(of: _archivedCard, matching: find.textContaining('May')), findsOneWidget);
    expect(find.descendant(of: _normalCard, matching: find.byKey(const ValueKey('hub-card-archived'))), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('the archived card menu offers only Delete; a normal past card keeps Share and Mark complete', (t) async {
    installFakeApi(const []);
    await _pump(t);
    await _openMenu(t, _archivedCard);
    expect(find.text(TripStrings.delete), findsOneWidget);
    expect(find.text(TripStringsA5.share), findsNothing);
    expect(find.text(TripStrings.markComplete), findsNothing);
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    await _openMenu(t, _normalCard);
    expect(find.text(TripStringsA5.share), findsOneWidget);
    expect(find.text(TripStrings.markComplete), findsOneWidget);
  });

  testWidgets('tapping the archived card opens the summary route with the trip id', (t) async {
    installFakeApi(const []);
    await _pump(t);
    await t.ensureVisible(_archivedCard);
    await t.tap(find.descendant(of: _archivedCard, matching: find.text('Nainital & Mukteshwar')));
    await t.pumpAndSettle();
    expect(_opened, [
      {'tripId': 'arc-1'},
    ]);
    expect(find.text('archived stub'), findsOneWidget);
    expect(find.text('plan stub'), findsNothing);
  });

  testWidgets('deleting an archived trip does not load the trip and still deletes it', (t) async {
    final api = installFakeApi(const []);
    final c = await _pump(t);
    await _openMenu(t, _archivedCard);
    await t.tap(find.text(TripStrings.delete));
    await t.pumpAndSettle();
    expect(find.text(TripStringsV2Plan.deleteTitle), findsOneWidget);
    await t.tap(find.text(TripStringsV2Plan.delete).last);
    await t.pumpAndSettle();
    expect(api.calls('GET', '/trips/arc-1'), isEmpty);
    expect(c.deleted, ['arc-1']);
  });

  test('an archived trip never raises the trip bar or Continue, even from a stale active list', () {
    TripClock.clockUtc = () => DateTime.utc(2026, 5, 11, 6, 30);
    addTearDown(TripClock.resetClock);
    final c = _FakeMyTrips();
    final running = TripSummaryModel.fromJson({
      ...archivedListItemJson(),
      'status': TripStatuses.planned,
      'completedAt': null,
    });
    c.active.assignAll([running]);
    expect(c.runningTrip, isNull);
    expect(c.continueTrips, isEmpty);
    expect(c.barPick, isNull);
    expect([...c.groups.inProgress, ...c.groups.ready], isEmpty);
    final plain = TripSummaryModel.fromJson({...archivedListItemJson(), 'status': TripStatuses.planned, 'completedAt': null, 'archived': false});
    c.active.assignAll([plain]);
    expect(c.runningTrip?.id, 'arc-1');
  });
}
