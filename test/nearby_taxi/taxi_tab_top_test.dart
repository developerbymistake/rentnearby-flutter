import 'dart:io';
import 'dart:ui' as ui;

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/nearby/controllers/nearby_centre_controller.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_controller_v2.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_screen_v2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../e2e_journeys/nearby/nearby_support.dart';
import '../ui_golden/golden_support.dart';

class _Repo extends TaxiFeedRepository {
  @override
  Future<NearbyPage<TaxiFeedItem>> local({required double lat, required double lng, String? pageToken, int pageSize = 20, String? category}) async =>
      NearbyPage(items: [
        TaxiFeedItem.fromJson({
          'id': 'a',
          'driverName': 'Ramesh Kumar',
          'vehicleTypeName': 'Innova',
          'plateDisplay': 'UK04',
          'routeCount': 2,
          'createdAt': '2026-11-01T00:00:00Z',
          'cityName': 'Haldwani',
          'stateName': 'Uttarakhand',
          'distanceKm': 5.0,
          'labelKey': 'near',
          'minFare': 900,
          'seats': 7,
          'localDayRate': 2500,
          'localDayKm': 80,
        })
      ]);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });
  tearDown(Get.reset);

  for (final w in [300.0, 360.0]) {
    testWidgets('taxi tab has only the From and To inputs and no extra search controls at $w dp', (t) async {
      Get.reset();
      (Get.put<LocationController>(JLoc()) as JLoc).userLocation.value = const LatLng(29.2, 79.5);
      Get.put<AuthController>(JAuth());
      Get.put<TabConfigController>(JTabs());
      Get.put(NearbyCentreController());
      Get.put(TaxiListControllerV2(root: false, repo: _Repo()), tag: TaxiListControllerV2.tag);
      await pumpJourney(t, const TaxiListScreenV2(root: false), width: w, scale: 1.3, height: 760);
      expect(find.text('From'), findsOneWidget);
      expect(find.text('To'), findsOneWidget);
      expect(find.textContaining('Showing near'), findsNothing);
      expect(find.text('Search any place'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.search_rounded), findsNWidgets(2));
      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(t.takeException(), isNull);
      final ro = t.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
      await t.runAsync(() async {
        final img = await ro.toImage(pixelRatio: 1);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await Directory('F:/Dhasu/UI_Template_resume/Repair/shots').create(recursive: true);
        await File('F:/Dhasu/UI_Template_resume/Repair/shots/taxi_tab_top_${w.toInt()}.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
    });
  }
}
