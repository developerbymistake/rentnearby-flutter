import 'dart:io';

import 'package:bakhli/features/taxi/ways/ask_drivers_sheet.dart';
import 'package:bakhli/features/taxi/ways/change_driver_sheet.dart';
import 'package:bakhli/features/taxi/ways/journey_plan_controller.dart';
import 'package:bakhli/features/taxi/ways/journey_plan_screen.dart';
import 'package:bakhli/features/taxi/ways/journey_road_screen.dart';
import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/taxi/ways/widgets/travel_confirm_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../journeys/fake_api.dart';
import '../support/real_phone.dart';

Map<String, Object?> _place(String key, String name) => {'key': key, 'name': name, 'lat': 29.3, 'lng': 79.5};

Map<String, Object?> _wd(String id, String name, String vehicle, int seats, int fare, {bool app = false}) => {
      'taxiId': id,
      'driverName': name,
      'vehicleTypeName': vehicle,
      'seats': seats,
      'listedFare': fare,
      'phone': '9876500000',
      if (app) 'tripReplyLabel': 'app',
    };

WayPlan _plan() => WayPlan.fromJson({
      'planKey': 'p-two',
      'cars': 2,
      'total': 2300,
      'legs': [
        {
          'legKey': 'l1',
          'index': 1,
          'from': _place('hld', 'Haldwani'),
          'to': _place('bhw', 'Bhowali'),
          'listedFare': 900,
          'distanceKm': 32,
          'passes': ['Kathgodam', 'Jeolikot'],
          'hasRoadLine': true,
          'topDrivers': [_wd('x1', 'Rakesh Singh', 'Dzire', 4, 900, app: true), _wd('x2', 'Sunil Negi', 'Dzire', 4, 780), _wd('x3', 'Kailash', 'Ertiga', 6, 1050)],
          'driverCount': 3,
        },
        {
          'legKey': 'l2',
          'index': 2,
          'from': _place('bhw', 'Bhowali'),
          'to': _place('alm', 'Almora'),
          'meetingPlace': 'Bhowali taxi stand',
          'listedFare': 1400,
          'distanceKm': 54,
          'topDrivers': [_wd('y1', 'Pradeep Kumar', 'Innova', 7, 1400, app: true), _wd('y2', 'Harish', 'Innova', 7, 1500)],
          'driverCount': 2,
        },
      ],
    });

JourneyOpenArgs _args({bool trip = false, bool empty = false}) => JourneyOpenArgs(
      plan: empty ? const WayPlan(planKey: 'p-two', cars: 2, total: 0, legs: []) : _plan(),
      planKey: 'p-two',
      from: const WayPlace(key: 'hld', name: 'Haldwani', lat: 29.2, lng: 79.5),
      to: const WayPlace(key: 'alm', name: 'Almora', lat: 29.6, lng: 79.7),
      date: DateTime(2030, 11, 14),
      people: 2,
      tripId: trip ? 't' : null,
      tripRole: trip ? 'gettingThere' : null,
      synthetic: true,
    );

Route<dynamic>? _route;

Widget _host(Object? args, Widget screen) => Navigator(
      onGenerateRoute: (s) => _route = MaterialPageRoute<void>(settings: RouteSettings(arguments: args), builder: (_) => screen),
    );

const _cases = [(Size(360, 800), 1.0, '360'), (Size(360, 800), 1.3, '360x13'), (Size(300, 640), 1.0, '300')];

Future<void> _scroll(WidgetTester t, double y) async {
  final s = t.state<ScrollableState>(find.byType(Scrollable).first);
  for (var i = 0; i < 3; i++) {
    s.position.jumpTo(y.clamp(0, s.position.maxScrollExtent));
    await t.pump(const Duration(milliseconds: 200));
  }
  await settlePhone(t);
}

Future<void> _open(WidgetTester t, Future<void> Function(BuildContext c) show, {Size size = const Size(360, 800), double scale = 1, bool settle = true}) async {
  await pumpPhone(
    t,
    Scaffold(body: Builder(builder: (c) => Center(child: TextButton(onPressed: () => show(c), child: const Text('open'))))),
    size: size,
    textScale: scale,
  );
  await t.tap(find.text('open'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
  if (settle) await settlePhone(t);
}

Map<int, WayDriver> _chosen(WayPlan p) => {for (final l in p.legs) l.index: l.firstDriver!};

void main() {
  shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\journeys';
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
  tearDown(() => Get.reset(clearRouteBindings: true));

  group('journey plan', () {
    for (final (size, scale, tag) in _cases) {
      testWidgets('plan $tag', (t) async {
        await pumpPhone(t, _host(_args(), const JourneyPlanScreen()), size: size, textScale: scale);
        await settlePhone(t);
        await shot(t, 'plan_$tag');
        expect(find.text('2 other drivers', skipOffstage: false), findsOneWidget);
        expect(find.byTooltip('Save journey'), findsOneWidget);
        await _scroll(t, 3000);
        await shot(t, 'plan_end_$tag');
        expect(t.takeException(), isNull);
        debugDisableShadows = true;
      });
    }

    testWidgets('plan_trip', (t) async {
      await pumpPhone(t, _host(_args(trip: true), const JourneyPlanScreen()));
      await settlePhone(t);
      await shot(t, 'plan_trip');
      expect(find.text('Use for my trip'), findsOneWidget);
      await t.ensureVisible(find.text('Change car here'));
      await _scroll(t, t.state<ScrollableState>(find.byType(Scrollable).first).position.pixels - 160);
      await settlePhone(t);
      await shot(t, 'plan_trip_change');
      debugDisableShadows = true;
    });

    for (final name in ['plan_off', 'plan_load', 'plan_gone', 'plan_empty', 'plan_refresh']) {
      testWidgets(name, (t) async {
        final empty = name != 'plan_off' && name != 'plan_refresh';
        await pumpPhone(t, _host(_args(empty: empty), const JourneyPlanScreen()));
        final c = Get.find<JourneyPlanController>(tag: 'journey-plan-${identityHashCode(_route)}');
        c.offline.value = name == 'plan_off';
        c.loading.value = name == 'plan_load';
        c.notFound.value = name == 'plan_gone';
        c.refreshFailed.value = name == 'plan_refresh';
        await t.pump();
        await settlePhone(t);
        await shot(t, name);
        debugDisableShadows = true;
      });
    }

    testWidgets('plan_broken', (t) async {
      await pumpPhone(t, _host(null, const JourneyPlanScreen()));
      await settlePhone(t);
      await shot(t, 'plan_broken');
      expect(find.text('Go back'), findsOneWidget);
      debugDisableShadows = true;
    });
  });

  group('on the road', () {
    for (final (size, scale, tag) in _cases) {
      testWidgets('road $tag', (t) async {
        await pumpPhone(t, _host(_args(), const JourneyRoadScreen()), size: size, textScale: scale);
        await settlePhone(t);
        await t.tap(find.text('Haldwani to Bhowali').first);
        await t.pump(const Duration(milliseconds: 300));
        await shot(t, 'road_$tag');
        expect(find.byTooltip('Call Rakesh Singh'), findsOneWidget);
        await t.tap(find.text('Haldwani to Bhowali').first);
        await t.pump(const Duration(milliseconds: 300));
        await t.drag(find.text('Rakesh Singh').last, const Offset(0, -600));
        await settlePhone(t);
        expect(find.text('Pradeep Kumar').hitTestable(), findsOneWidget);
        if (tag != '360') {
          await t.drag(find.text('Pradeep Kumar').last, const Offset(0, -400));
          await settlePhone(t);
        }
        await shot(t, 'road_open_$tag');
        expect(find.text('Ask both drivers if they are free').hitTestable(), findsOneWidget);
        expect(t.takeException(), isNull);
        debugDisableShadows = true;
      });
    }

    testWidgets('road_fail', (t) async {
      await pumpPhone(t, _host(_args(empty: true), const JourneyRoadScreen()));
      await settlePhone(t);
      await shot(t, 'road_fail');
      debugDisableShadows = true;
    });
  });

  group('sheets', () {
    for (final (size, scale, tag) in _cases) {
      testWidgets('ask $tag', (t) async {
        installFakeApi([
          FakeRoute.value('POST', '/taxis/ways/ask', null, code: 429, errorType: 'TooManyAsks', headers: {'retry-after': '720'}),
        ]);
        final p = _plan();
        await _open(
          t,
          (c) => AskDriversSheet.show(c, plan: p, chosen: _chosen(p), date: DateTime.now(), people: 2, journeyId: 'j', fromName: 'Haldwani', toName: 'Almora'),
          size: size,
          scale: scale,
        );
        await shot(t, 'ask_$tag');
        await t.tap(find.text('Ask both drivers if they are free'));
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await t.pump(const Duration(milliseconds: 300));
        await shot(t, 'ask_err_$tag');
        expect(find.textContaining('Ask limit reached'), findsOneWidget);
        debugDisableShadows = true;
      });
    }

    for (final (name, code, items) in [('cd', 200, true), ('cd_on', 200, true), ('cd_empty', 200, false), ('cd_fail', 500, false)]) {
      testWidgets(name, (t) async {
        installFakeApi([
          FakeRoute.value('GET', '/taxis/ways/legs/{key}/drivers', {
            'items': items
                ? [
                    _wd('x1', 'Rakesh Singh', 'Dzire', 4, 900, app: true),
                    _wd('x2', 'Sunil Negi', 'Dzire', 4, 780, app: true),
                    _wd('x3', 'Kailash Bisht', 'Ertiga', 6, 1050, app: true),
                    _wd('x4', 'Harish Joshi', 'Tempo Traveller', 12, 1600, app: true),
                  ]
                : [],
            'hasMore': items,
            'total': items ? 8 : 0,
          }, code: code),
        ]);
        final p = _plan();
        await _open(t, (c) => ChangeDriverSheet.show(c, leg: p.legs.first, people: 2, current: p.legs.first.firstDriver));
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await t.pump(const Duration(milliseconds: 600));
        if (name == 'cd_on') {
          await t.tap(find.text('Replies in app'));
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
          await t.pump(const Duration(milliseconds: 600));
        }
        await shot(t, name);
        if (items) expect(find.text('Show 4 more'), findsOneWidget);
        debugDisableShadows = true;
      });
    }

    testWidgets('cd_load', (t) async {
      installFakeApi([]);
      final p = _plan();
      await _open(t, (c) => ChangeDriverSheet.show(c, leg: p.legs.first, people: 2, current: null), settle: false);
      await shot(t, 'cd_load');
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await t.pump(const Duration(milliseconds: 300));
      debugDisableShadows = true;
    });

    for (final (name, remove) in [('tc', false), ('tc_rm', true)]) {
      testWidgets(name, (t) async {
        bool? got;
        await _open(t, (c) async => got = remove ? await TravelConfirmSheet.removeTravel(c, 1) : await TravelConfirmSheet.replaceTravel(c, 1));
        await shot(t, name);
        await t.tap(find.text(remove ? 'Cancel and remove' : 'Replace'));
        await t.pump(const Duration(milliseconds: 600));
        expect(got, isTrue);
        debugDisableShadows = true;
      });
    }
  });
}
