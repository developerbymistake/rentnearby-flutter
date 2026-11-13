import 'dart:io';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/stay/models/stay_nearby_model.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_feed_screen.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_guide.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_guide_args.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/widgets/trip_driver_row.dart';
import 'package:bakhli/features/trip/widgets/trip_list_look.dart';
import 'package:bakhli/features/trip/widgets/trip_shortlist_bar.dart';
import 'package:bakhli/features/trip/widgets/trip_status.dart';
import 'package:bakhli/features/trip/widgets/trip_stay_row.dart';
import 'package:bakhli/models/place_result_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../journeys/fake_api.dart';
import '../support/real_phone.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void _guideSteps() {
  Get.put<TabConfigController>(_Tabs());
  final plan = Get.put(TripPlanController());
  plan.plan.value = journeyPlan([2]);
  plan.guideSync();
}

class _Repo extends TripShortlistRepository {
  _Repo(this.pre);
  final List<ShortlistItem> pre;
  @override
  Future<TripShortlist> list(String tripId) async => TripShortlist(items: pre, max: 3);
  @override
  Future<List<ShortlistItem>> add(String tripId, String stepKey, String listingId, ShortlistItem item) async =>
      (pre..removeWhere((i) => i.listingId == listingId)..add(item)).toList();
  @override
  Future<void> remove(String tripId, String stepKey, String listingId) async => pre.removeWhere((i) => i.listingId == listingId);
}

Map<String, Object?> _place(String key, String name) => {'key': key, 'name': name, 'lat': 29.3, 'lng': 79.5};

Map<String, Object?> _driver(String id, String name, String vehicle, int seats, int fare, {bool featured = false, bool based = false}) => {
      'taxiId': id,
      'driverName': name,
      'vehicleTypeName': vehicle,
      'seats': seats,
      'fromName': 'Haldwani',
      'toName': 'Almora',
      'listedFare': fare,
      'basedHere': based,
      'isFeatured': featured,
    };

Map<String, Object?> _leg(int i, String from, String to, int fare, String driver, int others) => {
      'legKey': 'l$i',
      'index': i,
      'from': _place('f$i', from),
      'to': _place('t$i', to),
      'listedFare': fare,
      'topDrivers': [_driver('x$i', driver, 'Dzire', 4, fare)],
      'driverCount': 1 + others,
    };

Map<String, dynamic> _json({required bool drivers, required bool plans}) => {
      'version': 'v1',
      'from': _place('a', 'Haldwani'),
      'to': _place('b', 'Almora'),
      if (plans) 'bestWay': {'kind': 'plan', 'id': 'p-two', 'reason': ''},
      if (drivers) 'bestWay': {'kind': 'driver', 'id': 'd1', 'reason': ''},
      'allTheWay': drivers
          ? [
              _driver('d1', 'Pradeep Kumar', 'Dzire', 4, 2600, featured: true, based: true),
              _driver('d2', 'Rakesh Singh', 'Innova', 7, 3100),
              _driver('d3', 'Mohan Rawat Bhandari Negi', 'Tempo Traveller', 12, 4200),
            ]
          : [],
      'plans': plans
          ? [
              {
                'planKey': 'p-two',
                'cars': 2,
                'total': 2300,
                'legs': [_leg(1, 'Haldwani', 'Bhowali', 900, 'Rakesh Singh', 2), _leg(2, 'Bhowali', 'Almora', 1400, 'Pradeep Kumar', 1)],
              },
              {
                'planKey': 'p-three',
                'cars': 3,
                'total': 2750,
                'legs': [
                  _leg(3, 'Haldwani', 'Bhimtal', 700, 'Suresh', 0),
                  _leg(4, 'Bhimtal', 'Bhowali', 650, 'Dinesh', 0),
                  _leg(5, 'Bhowali', 'Almora', 1400, 'Pradeep', 0),
                ],
              },
            ]
          : [],
    };

class _Ways extends TaxiWaysController {
  _Ways(this.json, {bool trip = true})
      : super(
          from: PlaceResult(name: 'Haldwani', subtitle: '', latLng: const LatLng(29.2, 79.5)),
          to: PlaceResult(name: 'Almora', subtitle: '', latLng: const LatLng(29.6, 79.7)),
          tripId: trip ? 't' : null,
          tripRole: trip ? 'gettingThere' : null,
          fromTrip: trip,
          date: DateTime(2030, 1, 5),
          people: 2,
        );
  final Map<String, dynamic> json;

  @override
  Future<void> load() async => result.value = TaxiWaysResult.fromJson(json);
}

StayNearbyModel _stay(String id, String name, String city, double km, int? price,
        {bool active = true, bool featured = false, String? meals, String? type = 'Homestay'}) =>
    StayNearbyModel(
      id: id,
      name: name,
      stayTypeName: type,
      latitude: 29.3,
      longitude: 79.5,
      minPricePerNight: price,
      distanceKm: km,
      isActive: active,
      isFeatured: featured,
      meals: meals,
      checkInTime: '12:00',
      cityName: city,
      districtName: 'Nainital',
    );

TaxiBrowseItem _taxi(String id, String name, String vehicle, int seats, int? rate, {String reply = 'new', bool featured = false}) => TaxiBrowseItem(
      id: id,
      driverName: name,
      vehicleTypeName: vehicle,
      seats: seats,
      plateDisplay: 'UK04 TA',
      cityName: 'Nainital',
      routeCount: 1,
      matchReversed: false,
      createdAt: DateTime(2026, 10, 1),
      localDayRate: rate,
      tripReplyLabel: reply,
      isFeatured: featured,
    );

void _shortlist(List<ShortlistItem> pre) {
  Get.put(TripShortlistController(repo: _Repo(pre), tripId: () async => 't', offline: () => false, warn: (_) {}));
}

Widget _page({required ListingTone tone, required String title, required String sub, required String step, required List<Widget> rows, Widget? bar}) => Scaffold(
      backgroundColor: identical(tone, ListingTone.coral) ? ListingPalette.coral.page : ListingPalette.forest.page,
      bottomNavigationBar: bar,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Builder(
            builder: (c) => Padding(
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(c).top, bottom: 6),
              child: TopBar3D(tone: tone, title: title, subtitle: sub, stepChip: step, onBack: () {}),
            ),
          ),
          ...rows,
          const SizedBox(height: 24),
        ],
      ),
    );

void main() {
  shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\flow-lists';
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
  });
  setUp(() {
    Get.testMode = true;
    debugDisableShadows = false;
  });
  tearDown(Get.reset);

  const cases = [(Size(360, 800), 1.0, '360'), (Size(360, 800), 1.3, '360x13'), (Size(300, 640), 1.0, '300'), (Size(300, 640), 1.3, '300x13')];

  for (final (size, scale, tag) in cases) {
    testWidgets('stay pick list $tag', (t) async {
      _shortlist([
        const ShortlistItem(stepKey: 'stay:1', kind: 'Stay', listingId: 's1', name: 'Deodar Cottage'),
        const ShortlistItem(stepKey: 'stay:1', kind: 'Stay', listingId: 's2', name: 'Himalayan View'),
      ]);
      await TripShortlistController.to.load();
      var calls = 0;
      var picks = 0;
      final stays = [
        _stay('s1', 'Deodar Cottage', 'Kausani', 1.4, 1500, featured: true, meals: 'Breakfast'),
        _stay('s2', 'Himalayan View Homestay and Garden Rooms by the Lake', 'Bhimtal', 9, 1800, meals: 'Breakfast · Dinner'),
        _stay('s3', 'Pine Ridge Stay', 'Mukteshwar', 24, null, type: null),
      ];
      await pumpPhone(
        t,
        _page(
          tone: ListingTone.forest,
          title: 'Stay in Nainital',
          sub: 'Pick up to 3 stays',
          step: '2 of 5',
          rows: [
            for (final (i, s) in stays.indexed)
              Obx(() => TripStayRow(
                    stay: s,
                    index: i,
                    onOpen: () {},
                    onCall: () => calls++,
                    onShortlist: () => picks++,
                    shortlisted: TripShortlistController.to.has('stay:1', s.id),
                    noReply: i == 2,
                  )),
          ],
          bar: TripShortlistBar(step: 'stay:1', onDone: () {}),
        ),
        size: size,
        textScale: scale,
      );
      await settlePhone(t);
      await shot(t, 'stay_list_$tag');
      expect(find.text('2 of 3 shortlisted'), findsOneWidget);
      expect(find.text('Shortlisted'), findsWidgets);
      await t.ensureVisible(find.text('Call').first);
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.text('Call').first);
      expect(calls, 1);
      await t.drag(find.byType(ListView), const Offset(0, -600));
      await t.pump(const Duration(milliseconds: 300));
      await shot(t, 'stay_list_${tag}_y600');
      await t.ensureVisible(find.text('Shortlist'));
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.text('Shortlist'));
      expect(picks, 1);
      expect(t.takeException(), isNull);
      debugDisableShadows = true;
    });

    testWidgets('driver pick list $tag', (t) async {
      _shortlist([const ShortlistItem(stepKey: 'taxi', kind: 'Taxi', listingId: 'a', name: 'Pradeep')]);
      await TripShortlistController.to.load();
      final taxis = [
        _taxi('a', 'Pradeep Kumar', 'Dzire', 4, 2600, reply: 'app', featured: true),
        _taxi('b', 'Rakesh Singh Bisht from Haldwani Taxi Union', 'Innova Crysta', 7, 3100),
        _taxi('c', 'Mohan Rawat', 'Tempo Traveller', 12, null),
      ];
      await pumpPhone(
        t,
        _page(
          tone: ListingTone.coral,
          title: 'Taxi for sightseeing',
          sub: 'Nainital + Almora',
          step: '3 of 5',
          rows: [
            for (final (i, x) in taxis.indexed)
              Obx(() => TripDriverRow(
                    item: x,
                    tone: ListingTone.list(ListingTone.coral, i),
                    days: 2,
                    status: i == 2 ? TripDisplayStatus.asked : null,
                    onOpen: () {},
                    onCall: () {},
                    onAsk: () {},
                    onMenu: (_) {},
                    onShortlist: () {},
                    shortlisted: TripShortlistController.to.has('taxi', x.id),
                    contactBusy: i == 1,
                  )),
          ],
          bar: TripShortlistBar(step: 'taxi', onDone: () {}, tone: KitTone.taxi),
        ),
        size: size,
        textScale: scale,
      );
      await settlePhone(t);
      await shot(t, 'driver_list_$tag');
      await t.drag(find.byType(ListView), const Offset(0, -600));
      await t.pump(const Duration(milliseconds: 300));
      await shot(t, 'driver_list_${tag}_y600');
      expect(t.takeException(), isNull);
      debugDisableShadows = true;
    });

    testWidgets('ways drivers guide $tag', (t) async {
      _shortlist([const ShortlistItem(stepKey: 'gettingThere', kind: 'Car', listingId: 'd1', name: 'Pradeep')]);
      _guideSteps();
      final c = _Ways(_json(drivers: true, plans: false));
      Get.put(c, tag: 'ways-test');
      await pumpPhone(t, TaxiWaysFeedScreen(debugController: c, debugGuide: const GuideArgs('gettingThere')), size: size, textScale: scale);
      await settlePhone(t);
      await shot(t, 'ways_drivers_$tag');
      expect(find.textContaining(RegExp(r'^1 of \d+$')), findsOneWidget);
      expect(find.bySemanticsLabel('My journeys'), findsNothing);
      final scroll = t.state<ScrollableState>(find.byType(Scrollable).first);
      scroll.position.jumpTo(500);
      await t.pump(const Duration(milliseconds: 200));
      await shot(t, 'ways_drivers_${tag}_y500');
      expect(t.takeException(), isNull);
      debugDisableShadows = true;
    });

    testWidgets('ways plans guide $tag', (t) async {
      _shortlist(const []);
      _guideSteps();
      final c = _Ways(_json(drivers: false, plans: true));
      Get.put(c, tag: 'ways-test');
      await pumpPhone(t, TaxiWaysFeedScreen(debugController: c, debugGuide: const GuideArgs('gettingThere')), size: size, textScale: scale);
      await settlePhone(t);
      await shot(t, 'ways_plans_$tag');
      expect(find.textContaining(RegExp(r'^1 of \d+$')), findsOneWidget);
      expect(find.text('Save plan', skipOffstage: false), findsNWidgets(2));
      expect(find.text('Open journey', skipOffstage: false), findsNWidgets(2));
      expect(find.text('Ask both drivers', skipOffstage: false), findsOneWidget);
      expect(find.text('Ask all 3 drivers', skipOffstage: false), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-only-note')), findsOneWidget);
      expect(find.text('I will arrange it myself'), findsWidgets);
      final scroll = t.state<ScrollableState>(find.byType(Scrollable).first);
      for (final y in [500.0, 1000.0]) {
        scroll.position.jumpTo(y.clamp(0, scroll.position.maxScrollExtent));
        await t.pump(const Duration(milliseconds: 200));
        await shot(t, 'ways_plans_${tag}_y${y.toInt()}');
      }
      expect(t.takeException(), isNull);
      debugDisableShadows = true;
    });
  }

  testWidgets('ways plans in trip, no guide (Save plan)', (t) async {
    _shortlist(const []);
    final c = _Ways(_json(drivers: true, plans: true));
    Get.put(c, tag: 'ways-test');
    await pumpPhone(t, TaxiWaysFeedScreen(debugController: c));
    await settlePhone(t);
    final scroll = t.state<ScrollableState>(find.byType(Scrollable).first);
    for (final y in [0.0, 600.0, 1200.0, 1800.0]) {
      scroll.position.jumpTo(y.clamp(0, scroll.position.maxScrollExtent));
      await t.pump(const Duration(milliseconds: 200));
      await shot(t, 'ways_trip_y${y.toInt()}');
    }
    expect(find.text('Save plan', skipOffstage: false), findsWidgets);
    expect(find.text('Ask both drivers', skipOffstage: false), findsOneWidget);
    expect(find.text('Open journey', skipOffstage: false), findsNWidgets(2));
    expect(t.takeException(), isNull);
    debugDisableShadows = true;
  });

  for (final taxi in [true, false]) {
    testWidgets('review sheet taxi=$taxi', (t) async {
      bool? got;
      await pumpPhone(
        t,
        Scaffold(
          backgroundColor: taxi ? ListingPalette.coral.page : ListingPalette.forest.page,
          body: Builder(
            builder: (c) => Center(
              child: TextButton(
                onPressed: () async => got = await TripShortlistReview.show(c,
                    taxi: taxi, count: 3, names: taxi ? ['Pradeep Kumar', 'Rakesh Singh', 'Mohan Rawat'] : ['Deodar Cottage', 'Himalayan View Homestay', 'Pine Ridge']),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await settlePhone(t);
      await shot(t, 'review_${taxi ? 'taxi' : 'stay'}');
      expect(find.text(taxi ? 'Pradeep' : 'Deodar Cottage'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      await t.tap(find.text('Send to all'));
      await t.pump(const Duration(milliseconds: 600));
      expect(got, isTrue);
      debugDisableShadows = true;
    });
  }

  testWidgets('dock bar states', (t) async {
    _shortlist([
      for (final id in ['a', 'b', 'c']) ShortlistItem(stepKey: 'taxi', kind: 'Taxi', listingId: id, name: id),
    ]);
    await TripShortlistController.to.load();
    await pumpPhone(
      t,
      Scaffold(
        backgroundColor: ListingPalette.coral.page,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TripShortlistBar(step: 'taxi', onDone: () {}, tone: KitTone.taxi),
            const SizedBox(height: 16),
            TripShortlistBar(step: 'none', onDone: () {}),
          ],
        ),
      ),
    );
    await settlePhone(t);
    expect(find.byKey(const ValueKey('shortlist-bar-note')), findsOneWidget);
    await shot(t, 'dock_states');
    debugDisableShadows = true;
  });

  testWidgets('skip pill and top bar', (t) async {
    var skipped = 0;
    await pumpPhone(
      t,
      Scaffold(
        backgroundColor: ListingPalette.forest.page,
        body: TripListTopBar(tone: ListingTone.forest, title: 'Stay in Nainital', subtitle: '2 nights · 12 Jan to 14 Jan · 2 people', onBack: () {}, skipLabel: 'Skip', onSkip: () => skipped++),
      ),
    );
    await settlePhone(t);
    await t.tap(find.text('Skip'));
    expect(skipped, 1);
    expect(find.byTooltip('Back'), findsOneWidget);
    await shot(t, 'topbar_skip');
    debugDisableShadows = true;
  });
}
