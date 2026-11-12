import 'dart:io';
import 'dart:ui' as ui;
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/nearby/controllers/nearby_centre_controller.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/stay/guest/v2/stay_feed_item.dart';
import 'package:bakhli/features/stay/guest/v2/stay_landing_controller_v2.dart';
import 'package:bakhli/features/stay/guest/v2/stay_landing_screen_v2.dart';
import 'package:bakhli/controllers/report_controller.dart';
import 'package:bakhli/features/stay/guest/stay_detail_screen.dart';
import 'package:bakhli/features/stay/guest/stay_guest_controller.dart';
import 'package:bakhli/features/stay/models/stay_detail_model.dart';
import 'package:bakhli/features/stay/stay_types_controller.dart';
import 'package:bakhli/models/city_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../e2e_journeys/nearby/nearby_support.dart';
import '../golden_support.dart';

const _out = 'F:/Dhasu/UI_Template_resume/Repair/shots';

Map<String, dynamic> _stay(String id, {bool featured = false}) => {
      'id': id,
      'userId': 'u',
      'name': 'Riverside Heritage Homestay $id',
      'stayTypeName': 'Homestay',
      'mealsChip': 'Breakfast',
      'cityName': 'Nainital',
      'districtName': 'Nainital',
      'minPricePerNight': 2400,
      'isFeatured': featured,
      'distanceKm': 3.2,
      'labelKey': 'near',
    };

class _Types extends StayTypesController {
  @override
  void ensureLoaded() {}
}

class _Stays extends StayLandingControllerV2 {
  @override
  int? get tabIndex => null;
  @override
  RxInt? get tabRx => null;
  @override
  Future<NearbyPage<StayFeedItem>> fetchPage(String? token) async => NearbyPage(
        items: [for (var i = 0; i < 6; i++) StayFeedItem.fromJson(_stay('$i', featured: i == 0))],
      );
}

Future<void> _shot(WidgetTester t, String name) async {
  final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot_root')));
  await t.runAsync(() async {
    final img = await ro.toImage(pixelRatio: 1);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    await Directory(_out).create(recursive: true);
    await File('$_out/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> _pump(WidgetTester t, double w, double s) async {
  Get.reset();
  final loc = Get.put<LocationController>(JLoc());
  loc.userLocation.value = const LatLng(29.2, 79.5);
  loc.selectedDistrict.value = DistrictModel(id: 'd', name: 'Nainital');
  loc.autoCity.value = CityModel(id: 'c', districtId: 'd', name: 'Haldwani', latitude: 29.2, longitude: 79.5);
  Get.put<AuthController>(JAuth());
  Get.put<TabConfigController>(JTabs());
  Get.put<StayTypesController>(_Types());
  Get.put(NearbyCentreController());
  final c = Get.put<StayLandingControllerV2>(_Stays(), tag: StayLandingControllerV2.tag);
  c.reload();
  setGoldenView(t, Size(w, 760));
  await t.pumpWidget(RepaintBoundary(
    key: const ValueKey('shot_root'),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'WorkSans'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(s), padding: const EdgeInsets.only(top: 24, bottom: 0)),
        child: child!,
      ),
      home: const StayLandingScreenV2(),
    ),
  ));
  await t.pump(const Duration(milliseconds: 700));
  await t.pump(const Duration(milliseconds: 700));
}

class _Guest extends StayGuestController {
  @override
  Future<StayDetailModel?> getById(String id) async => StayDetailModel.fromJson({
        'id': 's1',
        'userId': 'o',
        'slug': 'riverside',
        'name': 'Riverside Heritage Homestay',
        'stayTypeName': 'Homestay',
        'vehicleAccess': 'CarUpToDoor',
        'facilities': ['Wifi', 'Parking'],
        'description': 'A quiet homestay by the lake with mountain views and home cooked meals.',
        'districtName': 'Nainital',
        'cityName': 'Bhimtal',
        'photos': <String>[],
        'rooms': [
          {'id': 'r1', 'roomIndex': 1, 'pricePerNight': 2400, 'maxGuests': 2, 'roomName': 'Deluxe Valley View Room', 'meals': 'none'},
        ],
        'minPricePerNight': 2400,
        'ownerPhone': '9876543210',
        'createdAt': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      });
}

class _Reports extends ReportController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });
  tearDown(Get.reset);

  for (final w in [300.0, 360.0]) {
    testWidgets('stays landing top at $w', (t) async {
      await _pump(t, w, 1.3);
      expect(t.takeException(), isNull);
      await _shot(t, 'stays_landing_${w.toInt()}_1.3');
    });
  }

  testWidgets('stays landing scrolled', (t) async {
    await _pump(t, 360, 1.3);
    await t.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await t.pump(const Duration(milliseconds: 500));
    expect(t.takeException(), isNull);
    await _shot(t, 'stays_landing_360_scrolled');
  });

  testWidgets('stays filter sheet', (t) async {
    await _pump(t, 360, 1.3);
    await t.tap(find.text('Filter & Sort'));
    await t.pump(const Duration(milliseconds: 800));
    await t.pump(const Duration(milliseconds: 800));
    expect(t.takeException(), isNull);
    await _shot(t, 'stays_filter_360_1.3');
  });

  for (final w in [300.0, 360.0]) {
    testWidgets('stay detail at $w', (t) async {
      Get.reset();
      Get.put<AuthController>(JAuth());
      Get.put<TabConfigController>(JTabs());
      Get.put<ReportController>(_Reports());
      Get.put<StayGuestController>(_Guest());
      Get.routing.args = 's1';
      setGoldenView(t, Size(w, 760));
      await t.pumpWidget(RepaintBoundary(
        key: const ValueKey('shot_root'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'WorkSans'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3), padding: const EdgeInsets.only(top: 24)),
            child: child!,
          ),
          home: const StayDetailScreen(),
        ),
      ));
      await t.pump(const Duration(milliseconds: 900));
      await t.pump(const Duration(milliseconds: 900));
      expect(t.takeException(), isNull);
      await _shot(t, 'stays_detail_${w.toInt()}_1.3');
    });
  }
}
