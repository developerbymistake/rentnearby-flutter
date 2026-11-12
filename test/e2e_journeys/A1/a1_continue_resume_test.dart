import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_guide.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/utils/trip_bar_rules.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Repo implements TripShortlistRepository {
  @override
  Future<TripShortlist> list(String tripId) async => const TripShortlist(items: []);
  @override
  Future<List<ShortlistItem>> add(String tripId, String stepKey, String listingId, ShortlistItem item) async => [item];
  @override
  Future<void> remove(String tripId, String stepKey, String listingId) async {}
  @override
  Future<void> close(String tripId, String stepKey, {required String reason}) async {}
  @override
  Future<MarkBookedResult> markBooked(String tripId, String stepKey, {String? listingId}) async =>
      const MarkBookedResult(closedEnquiries: 0, closedShortlist: 0);
}

TripSpotRef _spot(String id) =>
    TripSpotRef(id: id, name: id, latitude: 29.4, longitude: 79.4, category: 'attraction', visitMinutes: 60);

TripPlan _plan({TripGuide? guide}) => TripPlan(
      legs: [TripCityLeg(index: 1, cityKey: 1, cityName: 'Nainital', latitude: 29.4, longitude: 79.4)],
      days: [TripDay(day: 1, leg: 1, spots: [_spot('s1')])],
      settings: TripSettings(startDate: DateTime(2030, 11, 1)),
      guide: guide,
    );

TripSummaryModel _summary({Object? guideStep, String next = 'gettingThere', List<String>? cities}) => TripSummaryModel.fromJson({
      'id': 'trip-1',
      'title': '',
      'status': 'Planned',
      'cityName': 'Nainital',
      'dayCount': 2,
      'spotCount': 4,
      'category': 'attraction',
      'updatedAt': '2026-11-01T10:00:00Z',
      if (cities != null) 'legCount': cities.length,
      'legCities': ?cities,
      'progress': {
        'total': 4,
        'done': 0,
        'percent': 0,
        'next': {'kind': next.split(':').first, 'key': next},
        'guideStep': ?guideStep,
      },
    });

Future<TripPlanController> _open(WidgetTester t, TripPlan plan, {double w = 360, double scale = 1}) async {
  final sl = TripShortlistController(repo: _Repo(), tripId: () async => 'trip-1', offline: () => false, warn: (_) {});
  Get.put<TripShortlistController>(sl);
  final c = TripPlanController();
  c.plan.value = plan;
  // What the plan screen does when it is opened with only a trip id.
  c.planStep.value = c.initialStep;
  c.guideRefresh();
  t.view.physicalSize = Size(w, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(w, 800), textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: Scaffold(body: TripGuideView(controller: c, shortlist: sl)),
    ),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('Continue sends only the trip id', () {
    test('even when the server next row differs from the guide step', () {
      final t = _summary(guideStep: 'taxi', next: 'gettingThere');
      expect(TripBarRules.continueArgs(t), {'tripId': 'trip-1'});
    });

    test('guide step wins over the next row in the card title', () {
      expect(TripBarRules.nextTitle(_summary(guideStep: 'taxi', next: 'gettingThere')), 'Local taxi');
    });

    test('without a guide step the next row is the title', () {
      expect(TripBarRules.nextTitle(_summary(next: 'comingBack')), 'Coming back');
    });

    test('a bad guide step from the server is ignored', () {
      for (final bad in ['finish', 'stay:0', 'stay:100', '', 7, 'row; drop', 'stay:1\n']) {
        final t = _summary(guideStep: bad, next: 'taxi');
        expect(t.progress.guideStep, isNull, reason: '$bad');
        expect(TripBarRules.nextTitle(t), 'Local taxi');
      }
    });

    test('a valid multi-city guide step is parsed and titled', () {
      final t = _summary(guideStep: 'between:2', cities: ['Nainital', 'Almora']);
      expect(t.progress.guideStep, 'between:2');
      expect(TripBarRules.nextTitle(t), isNot('Local taxi'));
      expect(TripBarRules.nextTitle(_summary(guideStep: 'stay:2', cities: ['Nainital', 'Almora'])), 'Stay in Almora');
    });
  });

  group('quit on a step, Continue reopens that step', () {
    for (final w in [300.0, 360.0, 412.0]) {
      testWidgets('taxi step @${w.toInt()} large text', (t) async {
        final c = await _open(t, _plan(guide: const TripGuide(step: 'taxi')), w: w, scale: 2);
        expect(find.text('See the sights in Nainital'), findsOneWidget);
        expect(find.text("Let's get you there"), findsNothing);
        expect(c.plan.value!.guide!.step, 'taxi');
        c.onClose();
      });
    }

    testWidgets('a plan with no saved guide (old v6) starts at the first unresolved step', (t) async {
      final c = await _open(t, _plan());
      expect(find.text("Let's get you there"), findsOneWidget);
      c.onClose();
    });

    testWidgets('opening again does not overwrite the saved step', (t) async {
      final c = await _open(t, _plan(guide: const TripGuide(step: 'taxi')));
      c.guideRefresh();
      expect(c.plan.value!.guide!.step, 'taxi');
      c.onClose();
    });
  });

  test('MyTripsController is not needed to build Continue args', () {
    expect(Get.isRegistered<MyTripsController>(), isFalse);
    expect(TripBarRules.continueArgs(_summary()).keys, ['tripId']);
  });
}
