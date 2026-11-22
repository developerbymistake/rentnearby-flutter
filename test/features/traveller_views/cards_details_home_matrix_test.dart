import 'dart:convert';
import 'dart:io';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/report_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/stay/guest/stay_detail_screen.dart';
import 'package:bakhli/features/stay/guest/stay_guest_controller.dart';
import 'package:bakhli/features/stay/models/stay_detail_model.dart';
import 'package:bakhli/features/taxi/guest/taxi_detail_screen.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/models/home_feed_model.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../e2e_journeys/nearby/nearby_support.dart';
import '../../support/owner_fakes.dart';
import '../../support/owner_sizes.dart';
import '../seeker_home/seeker_home_harness.dart';

const _photo = 'https://res.cloudinary.com/demo/image/upload/a.jpg';

class _Api implements HttpClientAdapter {
  _Api(this.taxi);
  final Map<String, dynamic> taxi;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    final hit = o.path.startsWith('/taxis/') && !o.path.startsWith('/taxis/ways');
    final m = hit ? {'status': '200', 'code': 200, 'data': taxi} : {'status': '404', 'code': 404, 'error': {'type': 'NoStub', 'message': 'No stub'}};
    return ResponseBody.fromString(jsonEncode(m), hit ? 200 : 404, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

class _Guest extends StayGuestController {
  _Guest(this.model);
  final StayDetailModel model;
  @override
  Future<StayDetailModel?> getById(String id, {Map<String, dynamic>? dates}) async => model;
}

class _Reports extends ReportController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> loadReportReasons() async {}
}

class _Args extends StatelessWidget {
  const _Args(this.args, this.child);
  final Object args;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    Get.routing.args = args;
    return child;
  }
}

Map<String, dynamic> _stay({bool photos = false}) => {
      'id': 's1',
      'userId': 'o1',
      'name': 'Deodar Cottage Homestay',
      'stayTypeName': 'Homestay',
      'facilities': ['HotWater', 'Heater', 'WiFi', 'Parking', 'HomeFood', 'MountainView'],
      'description': 'A quiet wooden cottage above the lake.',
      'cityName': 'Nainital',
      'latitude': 29.39,
      'longitude': 79.45,
      'photos': photos ? [_photo, '$_photo?2'] : <String>[],
      'rooms': [
        {'id': 'r1', 'roomIndex': 1, 'pricePerNight': 1500, 'maxGuests': 2, 'roomName': 'Deluxe', 'meals': 'Breakfast'},
        {'id': 'r2', 'roomIndex': 2, 'pricePerNight': 2800, 'maxGuests': 4, 'roomName': 'Family Room', 'meals': 'AllMeals'},
      ],
      'rules': {'checkInTime': '12:00', 'checkOutTime': '11:00', 'petsAllowed': false, 'cancellationPolicy': 'Flexible'},
      'minPricePerNight': 1500,
      'ownerPhone': '9876543210',
      'createdAt': '2026-11-20T10:00:00Z',
    };

Map<String, dynamic> _taxi({bool photo = false}) => {
      'id': 't1',
      'userId': 'd1',
      'driverName': 'Rakesh Singh',
      'vehicleTypeName': 'Innova',
      'vehicleCategory': 'SUV',
      'seats': 7,
      'plateDisplay': 'UK 04 TA 1234',
      'cityName': 'Haldwani',
      'routes': [
        {'id': 'r1', 'fromName': 'Haldwani', 'toName': 'Nainital', 'tripType': 'RoundTrip', 'fare': 2400},
        {'id': 'r2', 'fromName': 'Haldwani', 'toName': 'Kathgodam', 'tripType': 'OneWay', 'fare': 600},
        {'id': 'r3', 'fromName': 'Haldwani', 'toName': 'Almora', 'tripType': 'OneWay', 'fare': 3100},
      ],
      'minFare': 600,
      'isAvailable': true,
      'contactPhone': '9876500000',
      if (photo) 'displayPhotoUrl': _photo,
      'createdAt': '2026-11-20T10:00:00Z',
    };

void _detail({Map<String, dynamic>? taxi, StayDetailModel? stay}) {
  Get.reset();
  Get.put<LocationController>(JLoc());
  Get.put<AuthController>(JAuth());
  Get.put<TabConfigController>(JTabs());
  Get.put<ReportController>(_Reports());
  if (stay != null) Get.put<StayGuestController>(_Guest(stay));
  ApiService.init();
  ApiService.dio.httpClientAdapter = _Api(taxi ?? const {});
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _flush(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 30));
}

void _homeWithPhotos() {
  final home = registerHome(feed: fixtureNoTrip());
  final s = home.stays.toList();
  home.stays[0] = HomeStayModel(item: HomeStayModel.fromJson({'id': 's1', 'name': s[0].item.title, 'cityName': 'Kausani', 'thumbnailUrl': _photo, 'minPricePerNight': 1500}).item.withPlace(placeName: 'Kausani', distanceLabel: '1.4 km away'), districtName: '');
  final t = home.taxis.first;
  home.taxis[0] = TaxiBrowseItem(
    id: t.id,
    driverName: 'Pradeep',
    vehicleTypeName: 'Sedan',
    plateDisplay: 'UK04',
    cityName: 'Nainital',
    minFare: 1200,
    routeCount: 1,
    matchReversed: false,
    createdAt: DateTime(2026, 11, 1),
    isFeatured: true,
    displayPhotoUrl: _photo,
    distanceKm: 5,
  );
  home.recentlyAddedStays[0] = HomeStayModel.fromJson({'id': 'r1', 'name': 'Snow Peak Cottage', 'cityName': 'Manali', 'thumbnailUrl': _photo, 'createdAt': '2026-11-20T10:00:00Z'});
}

void main() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late GetStorage box;
  setUpAll(() async {
    await initTestStorage('cards_details_home_matrix');
    box = GetStorage();
    final tmp = Directory.systemTemp.createTempSync('a3_matrix');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async => tmp.path);
  });
  setUp(() async {
    await box.erase();
    await GetStorage(OwnerCache.container).erase();
  });
  tearDown(Get.reset);

  for (final photos in [true, false]) {
    testOwnerSizes(
      'Stay detail ${photos ? 'photo' : 'no photo'}',
      () => const _Args('s1', StayDetailScreen()),
      setUpEach: () => _detail(stay: StayDetailModel.fromJson(_stay(photos: photos))),
      arrange: _settle,
      check: (t, _, _) async {
        expect(find.text('Deodar Cottage Homestay'), findsWidgets);
        await _flush(t);
      },
    );
  }

  for (final (name, photo, args) in [
    ('photo', true, 't1' as Object),
    ('no photo', false, 't1' as Object),
    ('matched', true, {'id': 't1', 'matchedFare': 2400, 'matchedToName': 'Nainital'} as Object),
  ]) {
    testOwnerSizes(
      'Taxi detail $name',
      () => _Args(args, const TaxiDetailScreen()),
      setUpEach: () => _detail(taxi: _taxi(photo: photo)),
      arrange: _settle,
      check: (t, _, _) async {
        expect(find.text('Routes and fares'), findsOneWidget);
        await _flush(t);
      },
    );
  }

  testOwnerSizes(
    'Home loaded, photos mixed',
    () => homeHost(),
    setUpEach: _homeWithPhotos,
    arrange: _settle,
    check: (t, _, _) async {
      expect(find.text('Follow us'), findsOneWidget);
      await _flush(t);
    },
  );
}
