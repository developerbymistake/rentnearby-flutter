import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/controllers/app_version_controller.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/nearby/controllers/nearby_centre_controller.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/nearby/nearby_strings.dart';
import 'package:bakhli/features/nearby/widgets/nearby_state_views.dart';
import 'package:bakhli/features/stay/guest/stay_filter_sort_sheet.dart';
import 'package:bakhli/features/stay/guest/v2/stay_feed_item.dart';
import 'package:bakhli/features/stay/guest/v2/stay_landing_controller_v2.dart';
import 'package:bakhli/features/stay/guest/v2/stay_landing_screen_v2.dart';
import 'package:bakhli/features/stay/models/stay_type_model.dart';
import 'package:bakhli/features/stay/stay_types_controller.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_controller_v2.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_screen_v2.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/screens/my_trips_screen.dart';
import 'package:bakhli/features/trip/screens/trip_dates_sheet.dart';
import 'package:bakhli/features/trip/trip_strings.dart';
import 'package:bakhli/features/trip/trip_strings_v2_find.dart';
import 'package:bakhli/features/trip/utils/trip_clock.dart';
import 'package:bakhli/models/app_version_config_model.dart';
import 'package:bakhli/models/city_model.dart';
import 'package:bakhli/services/top_route_observer.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:bakhli/widgets/app_loading_overlay.dart';
import 'package:bakhli/widgets/force_update_screen.dart';
import 'package:bakhli/widgets/global_location_gates.dart';
import 'package:bakhli/widgets/location_search_sheet.dart';
import 'package:bakhli/widgets/location_switch_sheet.dart';
import 'package:bakhli/widgets/nearest_confirm_sheet.dart';
import 'package:bakhli/widgets/onboarding_closed_dialog.dart';
import 'package:bakhli/widgets/role_correction_dialog.dart';
import 'package:bakhli/widgets/soft_update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../e2e_journeys/nearby/nearby_support.dart';
import '../support/real_phone.dart';

const _dir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\shared-sheets';

class _Auth extends JAuth {
  @override
  String get postLoginRoute => AppRoutes.main;
}

class _Loc extends JLoc {
  String cities = 'ok';
  String districts = 'ok';

  @override
  Future<List<CityModel>> loadCitiesForDistrict(String districtId, {bool forceRefresh = false}) {
    if (cities == 'wait') return Completer<List<CityModel>>().future;
    if (cities == 'fail') return Future.error(Exception('x'));
    return Future.value([
      for (final n in ['Bhimtal', 'Bhowali', 'Haldwani', 'Kathgodam', 'Nainital', 'Ramgarh'])
        CityModel(id: n, districtId: districtId, name: n, latitude: 29.3, longitude: 79.5),
    ]);
  }

  @override
  Future<List<DistrictModel>> loadAllDistricts({bool forceRefresh = false}) {
    if (districts == 'wait') return Completer<List<DistrictModel>>().future;
    if (districts == 'fail') return Future.error(Exception('x'));
    return Future.value([
      DistrictModel(id: 'al', name: 'Almora', stateName: 'Uttarakhand'),
      DistrictModel(id: 'bg', name: 'Bageshwar', stateName: 'Uttarakhand', isActive: false),
      DistrictModel(id: 'dd', name: 'Dehradun', stateName: 'Uttarakhand'),
      DistrictModel(id: 'nt', name: 'Nainital', stateName: 'Uttarakhand'),
      DistrictModel(id: 'pt', name: 'Pithoragarh', stateName: 'Uttarakhand'),
      DistrictModel(id: 'sh', name: 'Shimla', stateName: 'Himachal Pradesh'),
    ]);
  }

  @override
  List<String> get browsableStates => const ['Himachal Pradesh', 'Uttarakhand'];
}

class _Types extends StayTypesController {
  @override
  void ensureLoaded() {}
}

StayFeedItem _stay(String id, String name, String city) => StayFeedItem.fromJson({
      'id': id,
      'userId': 'u',
      'name': name,
      'cityName': city,
      'districtName': 'Nainital',
      'stateName': 'Uttarakhand',
      'minPricePerNight': 1500,
      'distanceKm': 2.0,
      'labelKey': 'inCity',
    });

class _Stays extends StayLandingControllerV2 {
  _Stays(this.mode);
  final String mode;
  @override
  int? get tabIndex => null;
  @override
  RxInt? get tabRx => null;
  @override
  Future<NearbyPage<StayFeedItem>> fetchPage(String? token) {
    if (mode == 'wait') return Completer<NearbyPage<StayFeedItem>>().future;
    if (mode == 'fail') return Future.error(Exception('x'));
    if (mode == 'one') return Future.value(NearbyPage(items: [_stay('a', 'Deodar Cottage', 'Kausani')]));
    return Future.value(const NearbyPage(items: []));
  }
}

class _Repo extends TaxiFeedRepository {
  const _Repo(this.fail);
  final bool fail;
  @override
  Future<NearbyPage<TaxiFeedItem>> local({required double lat, required double lng, String? pageToken, int pageSize = 20, String? category}) async {
    if (fail) throw Exception('x');
    return const NearbyPage(items: []);
  }
}

class _Plan extends TripPlanController {
  final _gate = Completer<SettingsSaveResult>();
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<SettingsSaveResult> saveSettings(TripSettings next) => _gate.future;
}

class _Trips extends MyTripsController {
  _Trips(this.mode);
  final String mode;
  @override
  Future<void> ensureLoaded() async {}
  @override
  Future<void> refreshIfStale() async {}
  @override
  Future<void> load({bool refresh = false}) async {
    isLoading.value = mode == 'wait';
    loadFailed.value = mode == 'fail';
    plannerOff.value = mode == 'off';
  }
}

class _Ver extends AppVersionController {
  _Ver({String version = '1.0.1'}) : super(installedBuild: 62, installedVersionName: '1.0.0') {
    config.value = AppVersionConfigModel(
      platform: 'android',
      enabled: true,
      minBuild: 64,
      minVersionName: '1.0.1',
      latestBuild: 64,
      latestVersionName: version,
      storeUrl: null,
      message: null,
      forceCacheMaxAge: Duration.zero,
      fetchedAt: DateTime(2026),
    );
  }
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  // ignore: must_call_super
  void onClose() {}
}

_Loc _base({int tab = AppTabs.stays}) {
  Get.reset();
  final loc = Get.put<LocationController>(_Loc()) as _Loc;
  loc.userLocation.value = const LatLng(29.2, 79.5);
  loc.selectedDistrict.value = DistrictModel(id: 'nt', name: 'Nainital', stateName: 'Uttarakhand');
  Get.put<AuthController>(_Auth()).tabIndex.value = tab;
  Get.put<TabConfigController>(JTabs());
  Get.put(NearbyCentreController());
  return loc;
}

Future<void> _wait(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await t.pump(const Duration(milliseconds: 300));
  }
  await settlePhone(t);
}

late BuildContext _ctx;

Widget _page(ListingTone tone) => Scaffold(
      backgroundColor: tone.tint,
      body: Builder(builder: (c) {
        _ctx = c;
        return const SizedBox.expand();
      }),
    );

typedef _Size = ({double w, double s, String tag});
const List<_Size> _sizes = [(w: 360, s: 1.0, tag: ''), (w: 360, s: 1.3, tag: '_1.3'), (w: 300, s: 1.0, tag: '_300')];
const List<_Size> _one = [(w: 360, s: 1.0, tag: '')];

Future<void> _snap(WidgetTester t, String name) async {
  await shot(t, name);
}

void _shots(String name, List<_Size> sizes, Future<void> Function(WidgetTester t, _Size z) body, {Future<void> Function(WidgetTester t)? after}) {
  for (final z in sizes) {
    testWidgets('$name${z.tag}', (t) async {
      shotsDir = _dir;
      debugDisableShadows = false;
      await body(t, z);
      await _snap(t, '$name${z.tag}');
      expect(t.takeException(), isNull);
      if (after != null) await after(t);
      await t.pump(const Duration(seconds: 6));
      debugDisableShadows = true;
    });
  }
}

Future<void> _open(WidgetTester t, _Size z, ListingTone tone, void Function(BuildContext c) open) async {
  await pumpPhone(t, _page(tone), size: Size(z.w, 800), textScale: z.s);
  open(_ctx);
  await _wait(t);
}

class _PhotonOverrides extends HttpOverrides {
  _PhotonOverrides(this.port);
  final int port;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final c = super.createHttpClient(context);
    c.connectionFactory = (uri, host, p) => Socket.startConnect('127.0.0.1', port);
    return c;
  }
}

String _photonMode = 'results';
int _photonDelay = 0;
late HttpServer _photonServer;

Future<void> _startPhoton() async {
  _photonServer = await HttpServer.bind('127.0.0.1', 0);
  HttpOverrides.global = _PhotonOverrides(_photonServer.port);
  _photonServer.listen((req) async {
    if (_photonDelay > 0) await Future<void>.delayed(Duration(milliseconds: _photonDelay));
    if (_photonMode == 'fail') {
      req.response.statusCode = 500;
      await req.response.close();
      return;
    }
    final features = _photonMode == 'none'
        ? <Object>[]
        : [
            for (final (n, k, d) in [
              ('Tallital', 'suburb', 'Nainital'),
              ('Talla Ramgarh', 'village', 'Nainital'),
              ('Tallital Bazaar', 'neighbourhood', 'Nainital'),
              ('Tal Chhaal', 'locality', 'Almora'),
              ('Tallital Ghat', 'station', 'Nainital'),
            ])
              {
                'geometry': {'coordinates': [79.45, 29.38]},
                'properties': {'name': n, 'osm_value': k, 'county': d, 'state': 'Uttarakhand'},
              },
          ];
    req.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'features': features}));
    await req.response.close();
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _startPhoton();
  });
  tearDownAll(() async {
    HttpOverrides.global = null;
    await _photonServer.close(force: true);
  });
  tearDown(Get.reset);

  // Location switch sheet
  _shots('ls_city', _sizes, (t, z) async {
    _base();
    await _open(t, z, ListingTone.forest, (c) => LocationSwitchSheet.show(c));
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Change district ›'), findsOneWidget);
  });
  _shots('ls_district', _one, (t, z) async {
    _base();
    await _open(t, z, ListingTone.forest, (c) => LocationSwitchSheet.show(c));
    await t.tap(find.text('Change district ›'));
    await _wait(t);
    expect(find.text('Bageshwar · coming soon'), findsOneWidget);
  });
  _shots('ls_state', _one, (t, z) async {
    _base();
    await _open(t, z, ListingTone.forest, (c) => LocationSwitchSheet.show(c));
    await t.tap(find.text('Change district ›'));
    await _wait(t);
    await t.tap(find.text('Change state ›'));
    await _wait(t);
    expect(find.text('All states'), findsOneWidget);
  });
  _shots('ls_pick', _sizes, (t, z) async {
    _base(tab: AppTabs.taxi);
    await _open(t, z, ListingTone.coral, (c) => LocationSwitchSheet.pick(c));
    expect(find.text('Pick a city'), findsOneWidget);
    expect(find.text('Current'), findsNothing);
  });
  _shots('ls_loading', _one, (t, z) async {
    _base().cities = 'wait';
    await _open(t, z, ListingTone.forest, (c) => LocationSwitchSheet.show(c));
  });
  _shots('ls_empty', _one, (t, z) async {
    _base();
    await _open(t, z, ListingTone.forest, (c) => LocationSwitchSheet.show(c));
    await t.enterText(find.byType(TextField), 'Kasauli');
    await _wait(t);
    expect(find.text('No city matches "Kasauli"'), findsOneWidget);
  });
  _shots('ls_error', _sizes, (t, z) async {
    _base().cities = 'fail';
    await _open(t, z, ListingTone.forest, (c) => LocationSwitchSheet.show(c));
    expect(find.text('Could not load cities. Please try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
  _shots('ls_dloading', _one, (t, z) async {
    _base().districts = 'wait';
    await _open(t, z, ListingTone.forest, (c) => LocationSwitchSheet.show(c));
    await t.tap(find.text('Change district ›'));
    await _wait(t);
  });
  _shots('ls_derror', _one, (t, z) async {
    _base().districts = 'fail';
    await _open(t, z, ListingTone.forest, (c) => LocationSwitchSheet.show(c));
    await t.tap(find.text('Change district ›'));
    await _wait(t);
    expect(find.text('Could not load districts. Please try again.'), findsOneWidget);
  });
  _shots('ls_dempty', _one, (t, z) async {
    _base();
    await _open(t, z, ListingTone.forest, (c) => LocationSwitchSheet.show(c));
    await t.tap(find.text('Change district ›'));
    await _wait(t);
    await t.enterText(find.byType(TextField), 'Kullu');
    await _wait(t);
    expect(find.text('No district matches "Kullu"'), findsOneWidget);
  });
  _shots('ls_sloading', _one, (t, z) async {
    _base().districts = 'wait';
    await _open(t, z, ListingTone.forest, (c) => LocationSwitchSheet.show(c));
    await t.tap(find.text('Change district ›'));
    await _wait(t);
    await t.tap(find.text('Change state ›'));
    await _wait(t);
  });
  _shots('ls_sempty', _one, (t, z) async {
    _base();
    await _open(t, z, ListingTone.forest, (c) => LocationSwitchSheet.show(c));
    await t.tap(find.text('Change district ›'));
    await _wait(t);
    await t.tap(find.text('Change state ›'));
    await _wait(t);
    await t.enterText(find.byType(TextField), 'Kashmira');
    await _wait(t);
    expect(find.text('No state matches "Kashmira"'), findsOneWidget);
  });

  // Location search sheet
  _shots('ss_idle', _sizes, (t, z) async {
    _base(tab: AppTabs.taxi);
    await _open(t, z, ListingTone.coral, (c) => LocationSearchSheet.show(c));
    expect(find.text('Search area, locality or landmark'), findsOneWidget);
  });
  _shots('ss_error', _one, (t, z) async {
    _photonMode = 'fail';
    _base(tab: AppTabs.taxi);
    await _open(t, z, ListingTone.coral, (c) => LocationSearchSheet.show(c));
    await t.enterText(find.byType(TextField), 'Tallital');
    await t.pump(const Duration(milliseconds: 700));
    await _wait(t);
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await _wait(t);
  });

  for (final k in ['ss_results', 'ss_none', 'ss_loading']) {
    testWidgets(k, (t) async {
      shotsDir = _dir;
      debugDisableShadows = false;
      _base(tab: AppTabs.taxi);
      _photonMode = k == 'ss_none' ? 'none' : 'results';
      _photonDelay = k == 'ss_loading' ? 1500 : 0;
      await _open(t, _one.first, ListingTone.coral, (c) => LocationSearchSheet.show(c));
      await t.enterText(find.byType(TextField), 'Tallital');
      await t.pump(const Duration(milliseconds: 700));
      if (k != 'ss_loading') {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      }
      await _wait(t);
      await _snap(t, k);
      if (k == 'ss_loading') {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2000)));
        await t.pump(const Duration(seconds: 1));
      }
      await t.pump(const Duration(seconds: 12));
      _photonDelay = 0;
      debugDisableShadows = true;
    });
  }
  for (final k in ['tm_trip', 'tm_stay']) {
    _shots(k, _one, (t, z) async {
      _base(tab: k == 'tm_trip' ? AppTabs.trips : AppTabs.stays);
      final trip = k == 'tm_trip';
      await _open(
        t,
        z,
        trip ? ListingTone.indigo : ListingTone.forest,
        (c) => TemplateTimePopup.pick(
          c,
          initial: const TimeOfDay(hour: 9, minute: 30),
          label: trip ? TripStrings.pickupTime : 'Check-in time',
          tone: trip ? KitTone.taxi : KitTone.stay,
          art: trip ? null : ListingArt.key,
        ),
      );
    });
  }

  // Filter sheet
  for (final clear in [false, true]) {
    _shots(clear ? 'sf_clear' : 'sf_main', clear ? _one : _sizes, (t, z) async {
      _base();
      final types = Get.put<StayTypesController>(_Types());
      types.types.assignAll([
        for (final (i, n) in ['Homestay', 'Villa', 'Resort', 'Cottage', 'Farm stay'].indexed) StayTypeModel(id: n, name: n, sortOrder: i),
      ]);
      final c = Get.put<StayLandingControllerV2>(_Stays('one'), tag: StayLandingControllerV2.tag);
      c.selectedMeals.value = 'Breakfast';
      c.selectedStayTypeId.value = 'Homestay';
      c.sortBy.value = 'price_asc';
      await _open(t, z, ListingTone.forest, (ctx) => StayFilterSortSheet.show(ctx, controller: c));
      if (clear) {
        await t.tap(find.text('Clear'));
        await _wait(t);
      }
    });
  }

  // Dates sheet
  for (final k in ['td_empty', 'td_filled', 'td_stale', 'td_saving', 'cal']) {
    _shots(k, k == 'td_filled' ? _sizes : _one, (t, z) async {
      _base(tab: AppTabs.trips);
      final today = TripClock.today();
      final start = switch (k) {
        'td_empty' => null,
        'td_stale' => today.subtract(const Duration(days: 3)),
        _ => today,
      };
      final p = Get.put<TripPlanController>(_Plan(), permanent: true);
      p.plan.value = TripPlan(
        legs: [TripCityLeg.fromCity(1, const TripCityModel(cityKey: 1, name: 'Nainital', latitude: 29, longitude: 79))],
        days: const [TripDay(day: 1), TripDay(day: 2), TripDay(day: 3)],
        settings: TripSettings(startDate: start, adults: k == 'td_stale' ? 4 : 2, kids: k == 'td_stale' ? 2 : 1),
      );
      await _open(t, z, ListingTone.indigo, (c) {
        if (k == 'td_filled' || k == 'td_saving' || k == 'cal') {
          TripDatesSheet.edit(c);
        } else {
          TripDatesSheet.ensure(c, heading: TripStringsV2Find.datesTitle);
        }
      });
      if (k == 'td_saving') {
        await t.tap(find.text('Save'));
        await t.pump(const Duration(milliseconds: 300));
      }
      if (k == 'cal') {
        await t.tap(find.byType(PillPickerField).first);
        await _wait(t);
        expect(find.byType(TemplateCalendarPopup), findsOneWidget);
      }
    });
  }

  // Dialogs
  _shots('dl_onb_role', _sizes, (t, z) async {
    _base();
    TopRouteObserver.top.value = AppRoutes.stayBasicDetails;
    await _open(t, z, ListingTone.forest, (c) => OnboardingClosedDialog.show(c, onChangeRole: () {}));
    TopRouteObserver.top.value = null;
  });
  _shots('dl_onb', _one, (t, z) async {
    _base();
    TopRouteObserver.top.value = AppRoutes.taxiVehicle;
    await _open(t, z, ListingTone.coral, (c) => OnboardingClosedDialog.show(c));
    TopRouteObserver.top.value = null;
  });
  for (final p in [40, 0]) {
    _shots(p == 40 ? 'dl_rolefix' : 'dl_rolefix0', _one, (t, z) async {
      _base();
      await _open(t, z, ListingTone.forest, (c) => RoleCorrectionDialog.confirm(c, kind: 'Stay', percent: p));
    });
  }
  for (final v in ['1.0.1', '']) {
    _shots(v.isEmpty ? 'dl_soft0' : 'dl_soft', v.isEmpty ? _one : _sizes, (t, z) async {
      _base(tab: AppTabs.home);
      Get.put<AppVersionController>(_Ver(version: v));
      await _open(t, z, ListingTone.indigo, (c) => showDialog<SoftUpdateChoice>(context: c, builder: (_) => const SoftUpdateDialog()));
    });
  }
  for (final taxi in [false, true]) {
    _shots(taxi ? 'sh_nearest_taxi' : 'sh_nearest', taxi ? _one : _sizes, (t, z) async {
      _base(tab: taxi ? AppTabs.taxi : AppTabs.stays);
      await _open(t, z, taxi ? ListingTone.coral : ListingTone.forest,
          (c) => NearestConfirmSheet.show(c, itemLabel: taxi ? 'taxis' : 'stays', onConfirm: () {}));
    });
  }
  _shots('ld_overlay', _one, (t, z) async {
    _base();
    await pumpPhone(t, AppLoadingOverlay(isLoading: true, child: _page(ListingTone.forest)), size: Size(z.w, 800), textScale: z.s);
    await _wait(t);
  });

  // Gates
  for (final g in ['g_offline', 'g_offline_trip', 'g_district', 'g_gps', 'g_perm']) {
    _shots(g, g == 'g_offline' || g == 'g_gps' ? _sizes : _one, (t, z) async {
      final loc = _base(tab: AppTabs.home);
      final obs = TopRouteObserver();
      if (g == 'g_offline_trip') {
        obs.didPush(MaterialPageRoute<void>(settings: const RouteSettings(name: AppRoutes.tripPlan), builder: (_) => const SizedBox()), null);
        obs.didPush(MaterialPageRoute<void>(settings: const RouteSettings(name: AppRoutes.stayDetail), builder: (_) => const SizedBox()), null);
      }
      loc.isOffline.value = g.startsWith('g_offline');
      loc.districtUnavailable.value = g == 'g_district';
      loc.gpsEnabled.value = g != 'g_gps';
      loc.locationPermissionGranted.value = g != 'g_perm';
      await pumpPhone(t, GlobalLocationGates(child: _page(ListingTone.indigo)), size: Size(z.w, 800), textScale: z.s);
      await _wait(t);
      if (g == 'g_offline_trip') {
        expect(find.text('Back to my trip'), findsOneWidget);
        TopRouteObserver.top.value = null;
      }
    });
  }
  _shots('g_force', _sizes, (t, z) async {
    _base(tab: AppTabs.home);
    Get.put<AppVersionController>(_Ver());
    await pumpPhone(t, const ForceUpdateScreen(), size: Size(z.w, 800), textScale: z.s);
    await _wait(t);
    expect(find.text('Your build 62 · Required build 64'), findsOneWidget);
  });

  // List states on the real screens
  for (final k in ['st_stays_empty', 'st_stays_filter', 'st_thin', 'sk_stays']) {
    _shots(k, k == 'st_stays_empty' ? _sizes : _one, (t, z) async {
      _base();
      Get.put<StayTypesController>(_Types());
      final mode = switch (k) { 'st_thin' => 'one', 'sk_stays' => 'wait', _ => 'none' };
      final c = Get.put<StayLandingControllerV2>(_Stays(mode), tag: StayLandingControllerV2.tag);
      if (k == 'st_stays_filter') c.selectedMeals.value = 'Breakfast';
      c.reload();
      await pumpPhone(t, const StayLandingScreenV2(), size: Size(z.w, 800), textScale: z.s);
      await _wait(t);
      if (k == 'st_thin' || k == 'sk_stays') {
        final title = find.text('Stays near you').first;
        final sc = Scrollable.of(t.element(title));
        sc.position.jumpTo(sc.position.pixels + t.getTopLeft(title).dy - 70);
        await _wait(t);
      } else if (k == 'st_stays_empty') {
        final sc = Scrollable.of(t.element(find.text('Stays near you').first));
        sc.position.jumpTo(sc.position.maxScrollExtent);
        await _wait(t);
      }
    });
  }
  for (final k in ['st_taxis_empty', 'st_taxi_error']) {
    _shots(k, k == 'st_taxi_error' ? _sizes : _one, (t, z) async {
      _base(tab: AppTabs.taxi);
      Get.put(TaxiListControllerV2(root: true, repo: _Repo(k == 'st_taxi_error')), tag: TaxiListControllerV2.tag);
      await pumpPhone(t, const TaxiListScreenV2(root: true), size: Size(z.w, 800), textScale: z.s);
      await _wait(t);
    });
  }
  for (final (k, tone, title, body) in [
    ('st_taxi_route', ListingTone.coral, NearbyStrings.routeEmptyTitle, NearbyStrings.routeEmptyBody),
    ('st_jobs_empty', ListingTone.forest, NearbyStrings.jobsEmptyTitle, NearbyStrings.jobsEmptyBody),
  ]) {
    _shots(k, _one, (t, z) async {
      _base(tab: AppTabs.home);
      await pumpPhone(
        t,
        Scaffold(
          backgroundColor: tone.tint,
          body: SafeArea(child: ListView(children: [TitleRow3D(title: k == 'st_jobs_empty' ? 'Jobs near you' : NearbyStrings.driversOnRoute), NearbyEmpty(title: title, body: body, tone: tone)])),
        ),
        size: Size(z.w, 800),
        textScale: z.s,
      );
      await _wait(t);
    });
  }
  for (final k in ['st_trips_empty', 'st_trips_error', 'st_planner_off', 'sk_trips']) {
    _shots(k, k == 'st_trips_empty' ? _sizes : _one, (t, z) async {
      _base(tab: AppTabs.trips);
      final mode = switch (k) { 'st_trips_error' => 'fail', 'st_planner_off' => 'off', 'sk_trips' => 'wait', _ => 'none' };
      Get.put<MyTripsController>(_Trips(mode), permanent: true);
      await pumpPhone(t, const MyTripsScreen(root: true), size: Size(z.w, 800), textScale: z.s);
      await _wait(t);
    }, after: (t) async {
      // MyTripsScreen.dispose creates its lazy entrance controller when only the skeleton was shown (Run A gap).
      Get.find<MyTripsController>().isLoading.value = false;
      await t.pump(const Duration(milliseconds: 100));
    });
  }

  // Toasts: toastification's global holder cannot be captured in the harness, so the same
  // widgets AppToast builds are placed at its lanes (top: status bar + 8, bottom: 96).
  for (final (k, kind, msg) in [
    ('t_ok', ToastKind.success, 'Basic details saved'),
    ('t_err', ToastKind.error, 'No internet connection'),
    ('t_warn', ToastKind.warning, 'This role is not available right now.'),
    ('t_info', ToastKind.info, 'Session expired. Please log in again.'),
    ('t_nodata', null, ''),
  ]) {
    _shots(k, k == 't_ok' ? _sizes : _one, (t, z) async {
      _base();
      await pumpPhone(
        t,
        Builder(
          builder: (c) => Stack(children: [
            Positioned.fill(child: _page(ListingTone.forest)),
            if (kind != null)
              Positioned(left: 16, right: 16, top: ToastLane.topOffset(c), child: Toast3D(kind: kind, message: msg))
            else
              Positioned(
                left: 16,
                right: 16,
                bottom: 96 + MediaQuery.paddingOf(c).bottom,
                child: NoDataToast3D(title: 'No stays here yet', subtitle: 'Try a nearby city, or check again soon.', accent: ListingTone.forest.g2, art: ListingArt.hotel),
              ),
          ]),
        ),
        size: Size(z.w, 800),
        textScale: z.s,
      );
      await _wait(t);
    });
  }
  test('AppToast keeps its static API', () {
    expect(AppToast.overlayKey, isNotNull);
    expect(AppToast.success, isA<Function>());
    expect(AppToast.noData, isA<Function>());
  });
}
