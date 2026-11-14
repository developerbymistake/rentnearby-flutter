import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/report_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/sheet_close_button.dart';
import 'package:bakhli/features/stay/guest/stay_bottom_sheet.dart';
import 'package:bakhli/features/stay/models/stay_nearby_model.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/widgets/trip_city_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_spot_detail_sheet.dart';
import 'package:bakhli/models/city_model.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/screens/profile_screen.dart';
import 'package:bakhli/widgets/location_search_sheet.dart';
import 'package:bakhli/widgets/location_switch_sheet.dart';
import 'package:bakhli/widgets/nearest_confirm_sheet.dart';
import 'package:bakhli/widgets/report_listing_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'e2e_journeys/nearby/nearby_support.dart';
import 'support/real_phone.dart';

class _Run {
  bool done = false;
  Object? result = 'unset';
}

late BuildContext _ctx;

Future<_Run> _open(WidgetTester t, Future<Object?> Function(BuildContext) open) async {
  final run = _Run();
  await pumpPhone(
    t,
    Scaffold(
      body: Builder(builder: (c) {
        _ctx = c;
        return const SizedBox.expand();
      }),
    ),
    size: const Size(360, 800),
    devicePixelRatio: 1.5,
  );
  open(_ctx).then((r) {
    run.result = r;
    run.done = true;
  });
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
  await settlePhone(t);
  return run;
}

Future<void> _tapClose(WidgetTester t, _Run run) async {
  expect(find.byType(SheetCloseButton), findsOneWidget);
  expect(t.widget<Icon>(find.byIcon(Icons.close_rounded)).color, DesignColors.error);
  await t.tap(find.byType(SheetCloseButton));
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
  await settlePhone(t);
  expect(find.byType(SheetCloseButton), findsNothing);
  expect(run.done, isTrue);
  expect(run.result, isNull);
  expect(t.takeException(), isNull);
}

Rect _x(WidgetTester t) => t.getRect(find.byType(SheetCloseButton));

class _Catalog extends TripCityCatalog {
  final list = [
    const TripCityModel(cityKey: 1, name: 'Nainital', districtName: 'Nainital', stateName: 'Uttarakhand', latitude: 1, longitude: 1, isPopularDestination: true),
    const TripCityModel(cityKey: 2, name: 'Almora', districtName: 'Almora', stateName: 'Uttarakhand', latitude: 1, longitude: 1),
  ];
  @override
  void warmFromDisk() {}
  @override
  bool get hasData => true;
  @override
  Future<List<TripCityModel>> load({bool force = false}) async => list;
  @override
  List<TripCityModel> search(String q) => TripCitySearch.filter(list, q);
  @override
  List<TripCityModel> popular({String? stateName}) => list.where((c) => c.isPopularDestination).toList();
}

class _Reports extends ReportController {
  @override
  // ignore: must_call_super
  void onInit() {
    reportReasons.value = [ReportReasonModel(id: 'r0', name: 'Wrong price')];
  }

  @override
  Future<void> loadReportReasons() async {}
}

class _Loc extends JLoc {
  @override
  Future<List<CityModel>> loadCitiesForDistrict(String districtId, {bool forceRefresh = false}) => Future.value([
        for (final n in ['Bhimtal', 'Haldwani', 'Nainital']) CityModel(id: n, districtId: districtId, name: n, latitude: 29.3, longitude: 79.5),
      ]);

  @override
  Future<List<DistrictModel>> loadAllDistricts({bool forceRefresh = false}) => Future.value([
        DistrictModel(id: 'nt', name: 'Nainital', stateName: 'Uttarakhand'),
        DistrictModel(id: 'al', name: 'Almora', stateName: 'Uttarakhand'),
      ]);
}

void _locBase() {
  Get.reset();
  final loc = Get.put<LocationController>(_Loc());
  loc.selectedDistrict.value = DistrictModel(id: 'nt', name: 'Nainital', stateName: 'Uttarakhand');
  Get.put<AuthController>(JAuth());
  Get.put<TabConfigController>(JTabs());
}

class _ProfileAuth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  bool get jobsBrowseEnabled {
    user.value;
    return true;
  }

  @override
  bool get taxisEnabled {
    user.value;
    return true;
  }
}

void main() {
  setUpAll(loadRealFonts);
  tearDown(Get.reset);

  testWidgets('trip city sheet: X in the top-right of the header, clear of the art, closes', (t) async {
    Get.put<TripCityCatalog>(_Catalog(), permanent: true);
    final run = await _open(t, (c) => TripCitySheet.pick(c));
    expect(find.text('Nainital'), findsWidgets);
    final x = _x(t);
    final sheet = t.getRect(find.byType(TripCitySheet));
    expect(x.right, closeTo(sheet.right - 4, 0.5));
    expect(x.top, closeTo(sheet.top + 4, 0.5));
    expect(t.getRect(find.byType(Art3D).first).right, lessThanOrEqualTo(x.left + 0.5));
    await _tapClose(t, run);
  });

  testWidgets('trip city sheet in add mode: X closes', (t) async {
    Get.put<TripCityCatalog>(_Catalog(), permanent: true);
    final run = await _open(t, (c) => TripCitySheet.pick(c, mode: TripCitySheetMode.add, afterCity: 'Nainital', inTrip: {1}));
    await _tapClose(t, run);
  });

  testWidgets('trip spot detail sheet: X over the photo, closes', (t) async {
    final spot = TripSpotModel(id: 'a', source: 'osm', name: 'Naini Lake', latitude: 29.38, longitude: 79.45, category: 'lake', visitMinutes: 90);
    final run = await _open(t, (c) async {
      await TripSpotDetailSheet.show(c, spot: spot, selected: false, locked: false, onToggle: () {});
      return null;
    });
    expect(find.text('Naini Lake'), findsOneWidget);
    final sheet = t.getRect(find.byType(TripSpotDetailSheet));
    expect(_x(t).right, closeTo(sheet.right - 12, 0.5));
    expect(_x(t).top, closeTo(sheet.top + 12, 0.5));
    await _tapClose(t, run);
  });

  testWidgets('report listing sheet: X on the band next to Cancel, closes', (t) async {
    Get.put<ReportController>(_Reports());
    final run = await _open(t, (c) async {
      await ReportListingSheet.show(c, listingId: 'x', listingType: 'Stay');
      return null;
    });
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Report this listing'), findsOneWidget);
    expect(_x(t).right, closeTo(360 - 12, 0.5));
    await _tapClose(t, run);
  });

  testWidgets('report listing sheet: Cancel still closes and there is one X', (t) async {
    Get.put<ReportController>(_Reports());
    final run = await _open(t, (c) async {
      await ReportListingSheet.show(c, listingId: 'x', listingType: 'Taxi');
      return null;
    });
    expect(find.byType(SheetCloseButton), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pump(const Duration(milliseconds: 700));
    expect(run.done, isTrue);
  });

  testWidgets('profile edit name sheet: X closes, Cancel stays', (t) async {
    final a = Get.put<AuthController>(_ProfileAuth());
    Get.put<TabConfigController>(JTabs());
    final p = Get.put(PlanController());
    a.profileName.value = 'Rahul Sharma';
    a.profilePhone.value = '9876543210';
    p.myPlan.value = MyPlanModel(paymentEnabled: false);
    await pumpPhone(t, const ProfileScreen());
    await settlePhone(t);
    await t.tap(find.bySemanticsLabel('Edit name'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.byType(SheetCloseButton), findsOneWidget);
    await t.tap(find.byType(SheetCloseButton));
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    expect(find.text('Enter your full name'), findsNothing);
    expect(find.byType(SheetCloseButton), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('stay card sheet: X closes', (t) async {
    final stay = StayNearbyModel(id: 's1', name: 'Deodar Cottage', latitude: 29.4, longitude: 79.5, distanceKm: 2.5, isActive: true, minPricePerNight: 1800);
    final run = await _open(t, (c) async {
      await StayBottomSheet.show(c, stay);
      return null;
    });
    await _tapClose(t, run);
  });

  testWidgets('nearest confirm sheet: X closes', (t) async {
    final run = await _open(t, (c) async {
      await NearestConfirmSheet.show(c, itemLabel: 'stays', onConfirm: () {});
      return null;
    });
    await _tapClose(t, run);
  });

  testWidgets('location switch sheet: X at city level closes', (t) async {
    _locBase();
    final run = await _open(t, (c) async {
      await LocationSwitchSheet.show(c);
      return null;
    });
    await _tapClose(t, run);
  });

  testWidgets('location switch sheet: Back and X both show on district level, Back goes up, X closes', (t) async {
    _locBase();
    final run = await _open(t, (c) async {
      await LocationSwitchSheet.show(c);
      return null;
    });
    await t.tap(find.text('Change district ›'));
    await t.pump(const Duration(milliseconds: 700));
    await settlePhone(t);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byType(SheetCloseButton), findsOneWidget);
    expect(t.getRect(find.byTooltip('Back')).right, lessThan(_x(t).left));
    await t.tap(find.byTooltip('Back'));
    await t.pump(const Duration(milliseconds: 700));
    await settlePhone(t);
    expect(run.done, isFalse);
    expect(find.byType(SheetCloseButton), findsOneWidget);
    await _tapClose(t, run);
  });

  testWidgets('location switch pick sheet: X closes and returns null', (t) async {
    _locBase();
    final run = await _open(t, (c) => LocationSwitchSheet.pick(c));
    await _tapClose(t, run);
  });

  testWidgets('location search sheet: X closes', (t) async {
    _locBase();
    final run = await _open(t, (c) => LocationSearchSheet.show(c));
    expect(find.text('Search location'), findsOneWidget);
    await _tapClose(t, run);
  });
}
