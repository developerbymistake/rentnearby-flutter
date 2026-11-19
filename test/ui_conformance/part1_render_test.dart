import 'dart:io';
import 'dart:ui' as ui;

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_spots_controller.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/screens/trip_customize_screen.dart';
import 'package:bakhli/features/trip/screens/trip_overview_screen.dart';
import 'package:bakhli/features/trip/screens/trip_plan_screen.dart';
import 'package:bakhli/features/trip/screens/trip_spots_screen.dart';
import 'package:bakhli/features/trip/trip_strings_customize.dart';
import 'package:bakhli/features/trip/widgets/trip_leg_header.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../features/trip/support/engine_rig.dart';
import '../features/trip/trip_day_plan_screen_test.dart' show pumpDayPlan;
import '../support/five_sizes.dart';
import '../support/real_phone.dart';

const _mode = String.fromEnvironment('UI_SCALE', defaultValue: 'normal');
const _out = r'F:\Dhasu\TaxiRequest_resume\evidence\ui';
const _phone = Size(360, 800);
const _tall = Size(360, 2600);

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Spots extends TripSpotsController {
  _Spots(super.cityKey, this.seed);
  final List<TripSpotModel> seed;
  @override
  Future<void> load() async {
    items.assignAll(seed);
    total.value = seed.length;
  }
}

typedef _S = (String, String, int);

const List<_S> _nainital = [
  ('Naini Lake', 'lake', 90),
  ('Naina Devi Temple', 'temple', 45),
  ('Snow View Point', 'viewpoint', 90),
  ('Mall Road', 'market', 60),
  ('Tiffin Top', 'viewpoint', 60),
  ('Hanuman Garhi', 'temple', 45),
  ('Bhimtal Lake', 'lake', 120),
  ('Sattal', 'lake', 150),
  ('Kainchi Dham', 'temple', 90),
  ('Nainital Zoo', 'zoo', 90),
  ('Himalaya Darshan', 'viewpoint', 60),
  ('Raj Bhavan', 'garden', 60),
  ('Eco Cave Gardens', 'park', 90),
];

const List<_S> _ranikhet = [
  ('Chaubatia Gardens', 'garden', 90),
  ('Jhula Devi Temple', 'temple', 45),
  ('Ranikhet Golf Course', 'park', 90),
];

// Spread along a line so the drive rows and clock times show as in the mock.
double _lat(_S s) => 29.38 + 0.02 * (_nainital.contains(s) ? _nainital.indexOf(s) : _ranikhet.indexOf(s));

TripSpotRef _ref(_S s) => TripSpotRef(
      id: s.$1.toLowerCase().replaceAll(' ', '_'),
      name: s.$1,
      latitude: _lat(s),
      longitude: 79.45,
      category: s.$2,
      visitMinutes: s.$3,
    );

// perDay[i] = how many Nainital places on day i, taken in mock order.
TripPlan _plan(List<int> perDay, {bool ranikhet = true}) {
  final days = <TripDay>[];
  var n = 0;
  for (var i = 0; i < perDay.length; i++) {
    days.add(TripDay(day: i + 1, leg: 1, spots: [for (var k = 0; k < perDay[i]; k++) _ref(_nainital[n++])]));
  }
  if (ranikhet) days.add(TripDay(day: days.length + 1, leg: 2, spots: [for (final s in _ranikhet) _ref(s)]));
  return TripPlan(
    legs: [
      const TripCityLeg(index: 1, cityKey: 1, cityName: 'Nainital', latitude: 29.38, longitude: 79.45),
      if (ranikhet) const TripCityLeg(index: 2, cityKey: 2, cityName: 'Ranikhet', latitude: 29.64, longitude: 79.43),
    ],
    days: days,
    settings: TripSettings(startDate: DateTime(2030, 12, 18), adults: 2),
    steps: const TripSteps(startFrom: TripStartFrom(name: 'Kathgodam', lat: 29.26, lon: 79.52)),
  );
}

String _name(String frame, String variant) => 'p1_${frame}_${variant}_$_mode';

const _hostKey = ValueKey('conf_root');

Future<void> _snap(WidgetTester t, String frame, String variant) async {
  shotsDir = _out;
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await t.pump(const Duration(milliseconds: 50));
  final own = find.byKey(_hostKey);
  if (own.evaluate().isEmpty) {
    await shot(t, _name(frame, variant));
    return;
  }
  final boundary = t.renderObject<RenderRepaintBoundary>(own);
  final file = File('$_out/${_name(frame, variant)}.png');
  await t.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: t.view.devicePixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

// Day plan with the real Customize route, inside a capturable boundary.
Future<TripPlanController> _planWithCustomize(WidgetTester t, TripPlan plan, Size size) async {
  final c = _rig(plan);
  await loadRealFonts();
  final view = t.view;
  view.devicePixelRatio = 3;
  view.physicalSize = Size(size.width * 3, size.height * 3);
  view.padding = FakeViewPadding(top: phoneTopInset * 3, bottom: phoneBottomInset * 3);
  view.viewPadding = view.padding;
  addTearDown(() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    view.resetPadding();
    view.resetViewPadding();
  });
  await t.pumpWidget(RepaintBoundary(
    key: _hostKey,
    child: GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      scrollBehavior: const AppScrollBehavior(),
      getPages: [
        GetPage(name: '/', page: () => const TripPlanScreen()),
        GetPage(name: AppRoutes.tripCustomize, page: () => TripCustomizeScreen(legIndex: (Get.arguments as Map)['leg'] as int)),
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    ),
  ));
  await settlePhone(t);
  return c;
}

final List<String> _toasts = [];

TripPlanController _rig(TripPlan plan, {TripPlanLock lock = TripPlanLock.none}) {
  Get.put<TabConfigController>(_Tabs());
  final c = TripPlanController();
  c.plan.value = plan;
  c.trip.value = engineTrip(plan, lock: lock).copyWith(nameChosen: true);
  Get.put<TripPlanController>(c, permanent: true);
  return c;
}

Future<void> _openCustomize(WidgetTester t, Size size, {TripDraftPicker? picker}) async {
  await pumpPhone(
    t,
    Scaffold(
      body: Center(
        child: TextButton(
          key: const ValueKey('open'),
          onPressed: () => Get.to(() => TripCustomizeScreen(legIndex: 1, picker: picker, toast: (ok, m) => _toasts.add(m))),
          child: const Text('open'),
        ),
      ),
    ),
    size: size,
  );
  await t.tap(find.byKey(const ValueKey('open')));
  await t.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

Future<void> _deleteDay(WidgetTester t, int index, {bool capMenu = false, String? frame}) async {
  final menu = find.byKey(ValueKey('customize-day-menu-$index'));
  await t.ensureVisible(menu);
  await t.pumpAndSettle();
  await t.tap(menu);
  await t.pumpAndSettle();
  if (capMenu) await _snap(t, frame!, 'menu_open');
  await t.tap(find.text(TripStringsCustomize.deleteDay).last);
  await t.pumpAndSettle();
}

TripModel _overviewTrip({String? view}) => TripModel(
      id: 't1',
      title: 'Uttarakhand Hills Trip',
      status: TripStatuses.planned,
      cityKey: 1,
      cityName: 'Nainital',
      cityLatitude: 29.4,
      cityLongitude: 79.4,
      dayCount: 9,
      spotCount: 31,
      legCount: 5,
      plan: TripPlan.singleCity(cityKey: 1, cityName: 'Nainital', settings: const TripSettings(adults: 2), days: [TripDay(day: 1)]),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      taxiRequest: view == null ? null : TripTaxiRequestRef(requestId: 'r1', state: 'Open', view: view, version: 1),
      nameChosen: true,
    );

Widget _overview({String? view}) =>
    TripOverviewScreen(trip: _overviewTrip(view: view), onViewPlan: () {}, onTaxi: (_) {}, onDone: () {}, onBack: () {});

List<TripSpotModel> _pickSeed() => [
      for (final s in [..._nainital.take(3), _nainital[12], _nainital[4], _nainital[7], _nainital[8]])
        TripSpotModel(id: _ref(s).id, source: 'osm', name: s.$1, latitude: _lat(s), longitude: 79.45, category: s.$2, visitMinutes: s.$3, rank: 1),
    ];

Future<void> _openPicker(WidgetTester t, Size size) async {
  Get.put<TabConfigController>(_Tabs());
  Get.put<TripSpotsController>(_Spots(1, _pickSeed()), tag: '1');
  await pumpPhone(t, const Scaffold(body: SizedBox()), size: size);
  Get.to<Object?>(() => const TripSpotsScreen(), arguments: {
    'city': const TripCityModel(cityKey: 1, name: 'Nainital', latitude: 29.38, longitude: 79.45),
    'pickForDraft': true,
    'dayNumber': 3,
    'dayCount': 0,
    'existingIds': {for (final s in _nainital.take(3)) _ref(s).id},
  });
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
}

final Map<String, List<String>> _overflows = {};

void _record(String frame, Size size, Object? e) {
  if (e != null) _overflows.putIfAbsent(frame, () => []).add('${sizeLabel(size)}: $e'.split('\n').first);
}

// Real blurred shadows in the captures, like on a phone.
void _tw(String name, WidgetTesterCallback body) => testWidgets(name, (t) async {
      debugDisableShadows = false;
      try {
        await body(t);
      } finally {
        debugDisableShadows = true;
      }
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (call) async => Directory.systemTemp.createTempSync('conf_gs').path);
    await GetStorage.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    Directory(_out).createSync(recursive: true);
  });
  tearDown(Get.reset);
  tearDownAll(() {
    File('$_out\\p1_overflows_$_mode.txt').writeAsStringSync(
        _overflows.isEmpty ? 'none\n' : _overflows.entries.map((e) => '${e.key}\n  ${e.value.join('\n  ')}').join('\n'));
  });

  group('render 360x800', () {
    for (final s in [_phone, _tall]) {
      final v = s == _phone ? 'viewport' : 'full';
      _tw('03 day plan $v', (t) async {
        await pumpDayPlan(t, _plan([4, 4, 4]), size: s);
        await _snap(t, '03_day_plan', v);
      });

      _tw('04 locked $v', (t) async {
        await pumpDayPlan(
            t,
            _plan([4, 4, 4]),
            size: s,
            lock: const TripPlanLock(locked: true, reason: TripPlanLockReasons.taxiBookingActive, requestId: 'b1'));
        await _snap(t, '04_day_plan_locked', v);
      });

      _tw('05 section open $v', (t) async {
        await pumpDayPlan(t, _plan([4, 4, 4], ranikhet: false), size: s);
        await _snap(t, '05_city_section_open', v);
      });

      _tw('06 section folded $v', (t) async {
        await pumpDayPlan(t, _plan([4, 4, 4]), size: s);
        await t.tap(find.byKey(TripLegSectionHeader.foldKey).first);
        await t.pumpAndSettle();
        await t.drag(find.byType(Scrollable).first, const Offset(0, -260));
        await t.pumpAndSettle();
        await _snap(t, '06_city_section_folded', v);
      });

      _tw('07 customize $v', (t) async {
        _rig(_plan([6, 6, 0]));
        await _openCustomize(t, s);
        await _snap(t, '07_customize_nainital', v);
      });

      _tw('13 delete blocked $v', (t) async {
        _rig(_plan([5, 4, 4]));
        await _openCustomize(t, s);
        await _deleteDay(t, 2, capMenu: v == 'viewport', frame: '13_delete_day_blocked');
        await t.drag(find.byType(Scrollable).first, const Offset(0, 4000));
        await t.pumpAndSettle();
        await _snap(t, '13_delete_day_blocked', v);
      });

      _tw('14 delete done $v', (t) async {
        _rig(_plan([4, 4, 3]));
        await _openCustomize(t, s);
        await _deleteDay(t, 2);
        await t.drag(find.byType(Scrollable).first, const Offset(0, 4000));
        await t.pumpAndSettle();
        await _snap(t, '14_delete_day_done', v);
      });
    }

    _tw('08 drag across days', (t) async {
      _rig(_plan([4, 2, 6]));
      await _openCustomize(t, _phone);
      final row = find.byKey(const ValueKey('customize-row-naina_devi_temple'));
      final g = await t.startGesture(t.getCenter(row));
      await t.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await g.moveBy(const Offset(0, 4));
      await t.pump();
      final target = find.byKey(const ValueKey('customize-row-tiffin_top'));
      final at = t.getCenter(target);
      await g.moveTo(at);
      await t.pump();
      await g.moveTo(at + const Offset(0, 2));
      await t.pump(const Duration(milliseconds: 200));
      await _snap(t, '08_drag_across_days', 'viewport');
      await g.cancel();
      await t.pumpAndSettle();
    });

    _tw('09 empty day', (t) async {
      _rig(_plan([6, 6, 0]));
      await _openCustomize(t, _phone);
      await _scrollTo(t, find.byKey(const ValueKey('customize-add-day')));
      await _snap(t, '09_empty_day', 'viewport');
    });

    _tw('10 day empty error', (t) async {
      _rig(_plan([6, 6]));
      await _openCustomize(t, _phone);
      await _scrollTo(t, find.byKey(const ValueKey('customize-add-day')));
      await t.tap(find.byKey(const ValueKey('customize-add-day')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('customize-update')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await t.pumpAndSettle();
      await _snap(t, '10_day_empty_error', 'viewport');
    });

    _tw('11 remove place', (t) async {
      _rig(_plan([6, 5, 1]));
      await _openCustomize(t, _phone);
      final row = find.byKey(const ValueKey('customize-row-raj_bhavan'));
      await _scrollTo(t, row);
      await t.tap(row);
      await t.pumpAndSettle();
      await _snap(t, '11_remove_place', 'selected');
      await t.tap(find.byKey(const ValueKey('customize-remove-raj_bhavan')));
      await t.pumpAndSettle();
      await _snap(t, '11_remove_place', 'sheet');
    });

    _tw('12 add places', (t) async {
      await _openPicker(t, _phone);
      final c = Get.find<TripSpotsController>(tag: '1');
      c.toggle('eco_cave_gardens');
      c.toggle('tiffin_top');
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 500));
      await _snap(t, '12_add_places', 'viewport');
      await t.pump(const Duration(seconds: 2));
      await t.pump(const Duration(seconds: 2));
      await _snap(t, '12_add_places', 'settled');
      await t.drag(find.byType(Scrollable).last, const Offset(0, -3000));
      await t.pump(const Duration(seconds: 2));
      await _snap(t, '12_add_places', 'scrolled');
    });

    for (final s in [_phone, _tall]) {
      final v = s == _phone ? 'viewport' : 'full';
      _tw('15/16/18 after update $v', (t) async {
        final c = await _planWithCustomize(t, _plan([4, 4, 4]), s);
        await t.tap(find.byKey(TripLegSectionHeader.customizeKey).first);
        await t.pumpAndSettle();
        final drop = find.byKey(const ValueKey('customize-row-naina_devi_temple'));
        await t.tap(drop);
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('customize-remove-naina_devi_temple')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('customize-remove-confirm')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('customize-update')));
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
        await t.pump(const Duration(milliseconds: 600));
        await _snap(t, '15_day_plan_after_update', v);
        expect(c.plan.value!.legDayCount(2), 1);
        await t.pump(const Duration(seconds: 6));
      });

      _tw('18 after delete $v', (t) async {
        await _planWithCustomize(t, _plan([4, 4, 3]), s);
        await t.tap(find.byKey(TripLegSectionHeader.customizeKey).first);
        await t.pumpAndSettle();
        await _deleteDay(t, 2);
        await t.tap(find.byKey(const ValueKey('customize-update')));
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
        await t.pump(const Duration(milliseconds: 600));
        await _snap(t, '18_day_plan_after_delete', v);
        await t.pump(const Duration(seconds: 6));
      });
    }

    _tw('19 overview', (t) async {
      await pumpPhone(t, _overview(), size: _phone);
      await _snap(t, '19_trip_overview', 'viewport');
    });

    _tw('20 overview booked', (t) async {
      await pumpPhone(t, _overview(view: 'Booked'), size: _phone);
      await _snap(t, '20_trip_overview_booked', 'viewport');
    });
  });

  group('responsive', () {
    const sizes = [Size(320, 568), Size(360, 640), Size(411, 891), Size(600, 960)];
    for (final size in sizes) {
      final l = sizeLabel(size);
      _tw('03/04/06 day plan $l', (t) async {
        await pumpDayPlan(t, _plan([4, 4, 4]), size: size);
        _record('03_day_plan', size, t.takeException());
        await _snap(t, '03_day_plan', l);
        await _scrollTo(t, find.byKey(TripLegSectionHeader.foldKey).first);
        await t.tap(find.byKey(TripLegSectionHeader.foldKey).first);
        await t.pumpAndSettle();
        _record('06_folded', size, t.takeException());
        await t.pumpWidget(const SizedBox.shrink());
        Get.reset();
        await pumpDayPlan(t, _plan([4, 4, 4]), size: size,
            lock: const TripPlanLock(locked: true, reason: TripPlanLockReasons.taxiBookingActive, requestId: 'b1'));
        _record('04_locked', size, t.takeException());
        await _snap(t, '04_day_plan_locked', l);
        await t.pump(const Duration(seconds: 6));
      });

      _tw('07/09/10/13/14 customize $l', (t) async {
        _rig(_plan([6, 6, 0]));
        await _openCustomize(t, size);
        _record('07_customize', size, t.takeException());
        await _snap(t, '07_customize_nainital', l);
        await _scrollTo(t, find.byKey(const ValueKey('customize-add-day')));
        _record('09_empty_day', size, t.takeException());
        await t.tap(find.byKey(const ValueKey('customize-update')));
        await t.pump();
        await t.pumpAndSettle();
        _record('10_day_empty_error', size, t.takeException());
        await _snap(t, '10_day_empty_error', l);
        await t.pumpWidget(const SizedBox.shrink());
        Get.reset();
        _rig(_plan([5, 4, 4]));
        await _openCustomize(t, size);
        await _deleteDay(t, 2);
        _record('13_delete_blocked', size, t.takeException());
        await t.pumpWidget(const SizedBox.shrink());
        Get.reset();
        _rig(_plan([4, 4, 3]));
        await _openCustomize(t, size);
        await _deleteDay(t, 2);
        _record('14_delete_done', size, t.takeException());
        final row = find.byKey(const ValueKey('customize-row-himalaya_darshan'));
        await _scrollTo(t, row);
        await t.tap(row);
        await t.pumpAndSettle();
        _record('11_remove_selected', size, t.takeException());
        await _snap(t, '11_remove_place', l);
        await t.tap(find.byKey(const ValueKey('customize-remove-himalaya_darshan')));
        await t.pumpAndSettle();
        _record('11_remove_sheet', size, t.takeException());
        await t.pump(const Duration(seconds: 6));
      });

      _tw('12 add places $l', (t) async {
        await _openPicker(t, size);
        final c = Get.find<TripSpotsController>(tag: '1');
        c.toggle('eco_cave_gardens');
        c.toggle('tiffin_top');
        await t.pump(const Duration(milliseconds: 500));
        await t.pump(const Duration(milliseconds: 500));
        _record('12_add_places', size, t.takeException());
        await _snap(t, '12_add_places', l);
      });

      _tw('19/20 overview $l', (t) async {
        await pumpPhone(t, _overview(), size: size);
        _record('19_overview', size, t.takeException());
        await _snap(t, '19_trip_overview', l);
        await t.pumpWidget(const SizedBox.shrink());
        await pumpPhone(t, _overview(view: 'Booked'), size: size);
        _record('20_overview_booked', size, t.takeException());
      });
    }
  });
}
