import 'dart:async';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/nearby/controllers/nearby_centre_controller.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/stay/guest/v2/stay_feed_item.dart';
import 'package:bakhli/features/stay/guest/v2/stay_landing_controller_v2.dart';
import 'package:bakhli/features/stay/guest/v2/stay_landing_screen_v2.dart';
import 'package:bakhli/features/stay/models/stay_type_model.dart';
import 'package:bakhli/features/stay/stay_types_controller.dart';
import 'package:bakhli/models/city_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../e2e_journeys/nearby/nearby_support.dart';
import '../support/real_phone.dart';

Map<String, dynamic> _j(String id, String name, String city, double km, int? price,
        {bool featured = false, String label = 'near', String? type = 'Homestay', String? meals = 'Breakfast', String? room = 'Deluxe room'}) =>
    {
      'id': id,
      'userId': 'u',
      'name': name,
      'cityName': city,
      'districtName': 'Nainital',
      'stateName': 'Uttarakhand',
      'minPricePerNight': price,
      'isFeatured': featured,
      'distanceKm': km,
      'labelKey': label,
      'stayTypeName': type,
      'mealsChip': meals,
      'roomNameChip': room,
    };

class _Types extends StayTypesController {
  @override
  void ensureLoaded() {}
}

class _Auth extends JAuth {
  @override
  bool get staysEnabled {
    user.value;
    return true;
  }
}

class _Stays extends StayLandingControllerV2 {
  _Stays(this.rows, {this.pending = false});
  final List<Map<String, dynamic>> rows;
  final bool pending;
  @override
  int? get tabIndex => null;
  @override
  RxInt? get tabRx => null;
  @override
  Future<NearbyPage<StayFeedItem>> fetchPage(String? token) async {
    if (pending) await Completer<void>().future;
    return NearbyPage(items: [for (final r in rows) StayFeedItem.fromJson(r)]);
  }
}

final _normal = [
  _j('a', 'Deodar Cottage', 'Kausani', 1.4, 1500, featured: true, label: 'inCity'),
  _j('b', 'Himalayan View Homestay', 'Bhimtal', 9, 1800, meals: 'AllMeals', room: 'Garden room'),
  _j('c', 'Pine Ridge Stay', 'Mukteshwar', 64, 2400, type: 'Hotel', room: 'Suite', label: 'far'),
];

final _edge = [
  _j('l', 'The Very Long Named Himalayan Riverside Heritage Homestay And Cottages', 'Someverylongvillagename', 3, 12500,
      meals: 'AllMeals', room: 'Premium family suite with balcony'),
  _j('e', 'No Chips Stay', 'Bhowali', 6, null, type: null, meals: null, room: null),
  _j('f', 'Featured Lodge', 'Ramgarh', 84, 900, featured: true, label: 'far'),
];

void _base({bool pendingUser = false}) {
  Get.reset();
  final loc = Get.put<LocationController>(JLoc()) as JLoc;
  loc.userLocation.value = const LatLng(29.2, 79.5);
  loc.selectedDistrict.value = DistrictModel(id: 'd', name: 'Nainital');
  loc.autoCity.value = CityModel(id: 'c', districtId: 'd', name: 'Haldwani');
  final auth = Get.put<AuthController>(_Auth());
  if (pendingUser) auth.user.value = UserModel.fromJson({'id': 'u', 'createdAt': '2026-01-01T00:00:00Z', 'stayStatus': 'PendingReview'});
  Get.put<TabConfigController>(JTabs());
  Get.put(NearbyCentreController());
  final types = Get.put<StayTypesController>(_Types());
  types.types.value = const [
    StayTypeModel(id: '1', name: 'Homestay', sortOrder: 1),
    StayTypeModel(id: '2', name: 'Hotel', sortOrder: 2),
    StayTypeModel(id: '3', name: 'Resort', sortOrder: 3),
    StayTypeModel(id: '4', name: 'Camp', sortOrder: 4),
  ];
}

Future<void> _open(WidgetTester t, List<Map<String, dynamic>> rows, {double w = 360, double h = 800, double scale = 1, bool pending = false}) async {
  final c = Get.put<StayLandingControllerV2>(_Stays(rows, pending: pending), tag: StayLandingControllerV2.tag);
  c.reload();
  await pumpPhone(t, const StayLandingScreenV2(), size: Size(w, h), textScale: scale);
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await t.pump(const Duration(milliseconds: 400));
  }
  await settlePhone(t);
}

Future<void> _scrollShots(WidgetTester t, String name) async {
  await scrollShots(t, find.byType(StayLandingScreenV2), name, [0, 600, 1200, 1800]);
}

void main() {
  setUp(() {
    shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\stays';
    debugDisableShadows = false;
  });
  tearDown(Get.reset);

  testWidgets('stays 360 x1.0', (t) async {
    _base();
    await _open(t, _normal, h: 1180);
    await shot(t, 'stays_360_top');
    expect(find.bySemanticsLabel('Search'), findsOneWidget);
    expect(find.text('Call'), findsWidgets);
    expect(find.text('Enquiry'), findsWidgets);
    expect(find.text('Map view'), findsOneWidget);
    await _scrollShots(t, 'stays_360');
    expect(t.takeException(), isNull);
    debugDisableShadows = true;
  });

  testWidgets('stays 360 x1.3', (t) async {
    _base();
    await _open(t, _normal, scale: 1.3);
    await _scrollShots(t, 'stays_360_x13');
    expect(t.takeException(), isNull);
    debugDisableShadows = true;
  });

  testWidgets('stays 300 edge cases', (t) async {
    _base(pendingUser: true);
    await _open(t, _edge, w: 300);
    await _scrollShots(t, 'stays_300_edge');
    expect(t.takeException(), isNull);
    debugDisableShadows = true;
  });

  testWidgets('stays 360 x1.3 edge cases', (t) async {
    _base();
    await _open(t, _edge, scale: 1.3);
    await _scrollShots(t, 'stays_360_x13_edge');
    expect(t.takeException(), isNull);
    debugDisableShadows = true;
  });

  testWidgets('stays skeleton', (t) async {
    _base();
    await _open(t, const [], pending: true);
    await shot(t, 'stays_skeleton');
    expect(find.byType(WideCardSkeleton), findsWidgets);
    expect(t.takeException(), isNull);
    debugDisableShadows = true;
  });

  testWidgets('stays empty', (t) async {
    _base();
    await _open(t, const []);
    await shot(t, 'stays_empty');
    expect(t.takeException(), isNull);
    debugDisableShadows = true;
  });

  for (final w in [360.0, 300.0]) {
    testWidgets('stays photo vs no photo cards $w', (t) async {
      _base();
      Widget card(bool photo, {bool featured = false, String title = 'Deodar Cottage', List<String> chips = const ['Homestay', 'Breakfast'], bool far = false}) => WideCard(
            tone: ListingTone.forest,
            kind: WideKind.photo,
            photo: photo
                ? const SizedBox.expand(
                    child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6FA8DC), Color(0xFFB7D7A8)]))),
                  )
                : null,
            sticker: ListingArt.key,
            badge: featured ? 'Featured' : null,
            tag: 'For stay',
            title: title,
            subtitle: 'Kausani, Nainital',
            chips: chips,
            priceCaption: 'FROM',
            number: '₹1,500',
            unit: '/night',
            label: far ? 'Mukteshwar, Uttarakhand. About 64 km away' : 'In Kausani',
            labelNote: far ? 'By road it can take longer.' : null,
            actions: [
              WideAction(icon: Icons.phone_rounded, label: 'Call', onTap: () {}),
              WideAction(icon: Icons.mail_rounded, label: 'Enquiry', onTap: () {}),
            ],
          );
      await pumpPhone(
        t,
        Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [
              card(true, featured: true),
              card(false, featured: true),
              card(false, chips: const [], title: 'The Very Long Named Himalayan Riverside Heritage Homestay', far: true),
            ]),
          ),
        ),
        size: Size(w, 1500),
      );
      await settlePhone(t);
      await shot(t, 'stays_photo_${w.toInt()}');
      expect(t.takeException(), isNull);
      debugDisableShadows = true;
    });
  }
}
