import 'dart:io';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/stay/models/stay_nearby_model.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_guide.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_supply_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/models/trip_guide_args.dart';
import 'package:bakhli/features/trip/screens/trip_stay_screen.dart';
import 'package:bakhli/features/trip/screens/trip_taxi_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../journeys/fake_api.dart';
import '../support/real_phone.dart';

class _Repo extends TripShortlistRepository {
  @override
  Future<TripShortlist> list(String tripId) async => const TripShortlist(items: [], max: 3);
}

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Supply extends TripSupplyController {
  @override
  bool get staysOutOfDate => false;
  @override
  Future<void> ensureStays(int legIndex) async => stayLeg.value = legIndex;
  @override
  Future<void> ensureTaxis(int legIndex, {int? day}) async => taxiLeg.value = legIndex;
}

StayNearbyModel _stay(String id, String name, double km, int? price, {String? type = 'Homestay', String? meals}) => StayNearbyModel(
      id: id,
      name: name,
      stayTypeName: type,
      latitude: 29.3,
      longitude: 79.5,
      minPricePerNight: price,
      distanceKm: km,
      isActive: true,
      meals: meals,
      checkInTime: '12:00',
      cityName: 'Kausani',
      districtName: 'Almora',
    );

TaxiBrowseItem _taxi(String id, String name, String vehicle, int seats, int? rate) => TaxiBrowseItem(
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
      tripReplyLabel: 'new',
    );

Future<void> _leave(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 5));
}

Future<void> _open(WidgetTester t, Widget screen, Map<String, dynamic> args) async {
  await pumpPhone(
    t,
    Builder(
      builder: (c) => TextButton(
        onPressed: () => Navigator.of(c).push(MaterialPageRoute(settings: RouteSettings(arguments: {'legIndex': 1, ...args}), builder: (_) => screen)),
        child: const Text('go'),
      ),
    ),
  );
  await t.tap(find.text('go'));
  await t.pump();
  await settlePhone(t);
}

void main() {
  shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\flow-lists';
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
  });
  setUp(() {
    Get.testMode = true;
    debugDisableShadows = false;
    installFakeApi([]);
  });
  tearDown(Get.reset);

  void boot() {
    Get.put<TabConfigController>(_Tabs());
    final plan = Get.put(TripPlanController());
    plan.plan.value = journeyPlan([2]);
    plan.guideSync();
    Get.put<TripSupplyController>(_Supply());
    Get.put(TripShortlistController(repo: _Repo(), tripId: () async => 't', offline: () => false, warn: (_) {}));
  }

  testWidgets('real trip stay screen', (t) async {
    boot();
    final s = Get.find<TripSupplyController>() as _Supply;
    s.stays.assignAll([
      _stay('s1', 'Deodar Cottage', 1.4, 1500, meals: 'Breakfast'),
      _stay('s2', 'Himalayan View Homestay', 9, 1800),
      _stay('s3', 'Pine Ridge Stay', 24, null, type: null),
    ]);
    await _open(t, const TripStayScreen(), GuideArgs('stay:1').toArgs());
    await shot(t, 'real_stay_screen');
    expect(find.textContaining(RegExp(r'^\d of \d+$')), findsOneWidget);
    expect(find.text('Stays near'), findsOneWidget);
    expect(find.textContaining(' centre'), findsOneWidget);
    debugDisableShadows = true;
    await _leave(t);
  });

  testWidgets('real trip taxi screen', (t) async {
    boot();
    final s = Get.find<TripSupplyController>() as _Supply;
    s.taxis.assignAll([
      _taxi('a', 'Pradeep Kumar', 'Dzire', 4, 2600),
      _taxi('b', 'Mohan Rawat', 'Tempo Traveller', 12, null),
    ]);
    await _open(t, const TripTaxiScreen(), GuideArgs('taxi').toArgs());
    await shot(t, 'real_taxi_screen');
    expect(find.textContaining(RegExp(r'^\d of \d+$')), findsOneWidget);
    debugDisableShadows = true;
    await _leave(t);
  });
}
