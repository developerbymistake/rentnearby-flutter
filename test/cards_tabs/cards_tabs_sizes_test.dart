import 'dart:async';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/stay_photo_card.dart';
import 'package:bakhli/design/extra/taxi_calm_card.dart';
import 'package:bakhli/features/nearby/controllers/nearby_centre_controller.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/nearby/widgets/place_search_bar.dart';
import 'package:bakhli/features/stay/guest/v2/stay_feed_item.dart';
import 'package:bakhli/features/stay/guest/v2/stay_landing_controller_v2.dart';
import 'package:bakhli/features/stay/guest/v2/stay_landing_screen_v2.dart';
import 'package:bakhli/features/stay/stay_types_controller.dart';
import 'package:bakhli/features/taxi/guest/taxi_card.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_controller_v2.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_screen_v2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../e2e_journeys/nearby/nearby_support.dart';
import '../support/real_phone.dart';

const _widths = [320.0, 360.0, 411.0];
const _scales = [1.0, 1.3];
const _counts = [0, 1, 2, 12];

StayFeedItem _stay(int i) => StayFeedItem.fromJson({
      'id': 's$i',
      'userId': 'u',
      'name': 'Stay number $i',
      'cityName': i.isEven ? 'Kausani' : 'Bhimtal',
      'districtName': 'Nainital',
      'stateName': 'Uttarakhand',
      'minPricePerNight': 1500 + i,
      'isFeatured': i == 0,
      'distanceKm': i == 0 ? 1.0 : 9.0 + i * 10,
      'labelKey': i == 0 ? 'inCity' : 'near',
      if (i % 4 == 1) ...{
        'priceChip': {'kind': 'Off', 'text': '15% off'},
        'oldPricePerNight': 1500 + i,
        'offerPricePerNight': 1275 + i,
        'offerPercent': 15,
      },
    });

Map<String, dynamic> _taxi(int i) => {
      'id': 't$i',
      'driverName': 'Driver number $i',
      'vehicleTypeName': i % 3 == 1 ? 'Tempo Traveller' : 'Innova',
      'plateDisplay': 'UK04',
      'routeCount': 2,
      'createdAt': '2026-11-01T00:00:00Z',
      'cityName': 'Haldwani',
      'stateName': 'Uttarakhand',
      'distanceKm': 5.0 + i,
      'labelKey': 'near',
      'seats': i % 3 == 1 ? 12 : 7,
      'isFeatured': i == 0,
      'localDayRate': 1600 + i,
      'localDayKm': 80,
    };

class _Types extends StayTypesController {
  @override
  void ensureLoaded() {}
}

class _Stays extends StayLandingControllerV2 {
  _Stays(this.n, {this.gate});
  final int n;
  final Completer<void>? gate;
  @override
  int? get tabIndex => null;
  @override
  RxInt? get tabRx => null;
  @override
  Future<NearbyPage<StayFeedItem>> fetchPage(String? token) async {
    if (gate != null) await gate!.future;
    final items = [for (var i = 0; i < n; i++) _stay(i)];
    return NearbyPage(items: items, featured: items.where((s) => s.item.isFeatured).toList());
  }
}

class _Repo extends TaxiFeedRepository {
  _Repo(this.n, {this.gate});
  final int n;
  final Completer<void>? gate;
  @override
  Future<NearbyPage<TaxiFeedItem>> local({required double lat, required double lng, String? pageToken, int pageSize = 20, String? category}) async {
    if (gate != null) await gate!.future;
    final items = [for (var i = 0; i < n; i++) TaxiFeedItem.fromJson(_taxi(i))];
    return NearbyPage(items: items, featured: items.where((t) => t.item.isFeatured).toList());
  }
}

void _base() {
  Get.reset();
  (Get.put<LocationController>(JLoc()) as JLoc).userLocation.value = const LatLng(29.2, 79.5);
  Get.put<AuthController>(JAuth());
  Get.put<TabConfigController>(JTabs());
  Get.put(NearbyCentreController());
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await t.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _openStays(WidgetTester t, int n, double w, double s, {Completer<void>? gate}) async {
  _base();
  Get.put<StayTypesController>(_Types());
  final c = Get.put<StayLandingControllerV2>(_Stays(n, gate: gate), tag: StayLandingControllerV2.tag) as _Stays;
  c.reload();
  await pumpPhone(t, const StayLandingScreenV2(), size: Size(w, 1400), textScale: s);
}

Future<void> _openTaxi(WidgetTester t, int n, double w, double s, {Completer<void>? gate}) async {
  _base();
  Get.find<AuthController>().tabIndex.value = 3;
  Get.put(TaxiListControllerV2(root: true, repo: _Repo(n, gate: gate)), tag: TaxiListControllerV2.tag);
  await pumpPhone(t, const TaxiListScreenV2(root: true), size: Size(w, 1400), textScale: s);
}

void main() {
  tearDown(Get.reset);

  for (final w in _widths) {
    for (final s in _scales) {
      for (final n in _counts) {
        testWidgets('stays tab, $n rows at ${w.toInt()} @$s', (t) async {
          await _openStays(t, n, w, s);
          await _settle(t);
          expect(t.takeException(), isNull);
          expect(find.byType(PlaceSearchBar), findsOneWidget);
          expect(find.byType(ChipCPRow), findsOneWidget);
          if (n > 0) {
            expect(find.byType(ListingFilterChip), findsOneWidget);
            expect(find.byType(StayPhotoCard), findsWidgets);
            expect(find.byType(WideCard), findsNothing);
          }
          expect(find.byType(MapPill3D), findsOneWidget);
        });

        testWidgets('taxi tab, $n rows at ${w.toInt()} @$s', (t) async {
          await _openTaxi(t, n, w, s);
          await _settle(t);
          expect(t.takeException(), isNull);
          expect(find.byType(PlaceSearchBarView), findsNWidgets(2));
          if (n > 0) {
            expect(find.byType(WorkoutCard), findsOneWidget);
            expect(find.byType(WideCard), findsNothing);
          }
          if (n > 1) {
            expect(find.byType(TitleRow3D), findsWidgets);
            expect(find.byType(TaxiCalmCard), findsWidgets);
          }
        });
      }
    }
  }

  testWidgets('skeletons are unchanged while loading', (t) async {
    final gate = Completer<void>();
    await _openStays(t, 3, 360, 1.0, gate: gate);
    expect(find.byType(WideCardSkeleton), findsWidgets);
    expect(find.byType(StayPhotoCard), findsNothing);
    gate.complete();
    await _settle(t);
    final taxiGate = Completer<void>();
    await _openTaxi(t, 3, 360, 1.0, gate: taxiGate);
    expect(find.byType(TaxiCardSkeleton), findsWidgets);
    expect(find.byType(TaxiCalmCard), findsNothing);
    taxiGate.complete();
    await _settle(t);
  });
}
