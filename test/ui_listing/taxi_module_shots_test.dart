import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/nearby/controllers/nearby_centre_controller.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/taxi/guest/taxi_card.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_controller_v2.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_list_screen_v2.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/features/trip/widgets/trip_status.dart';
import 'package:bakhli/models/place_result_model.dart';
import 'package:bakhli/widgets/listing_contact_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../e2e_journeys/nearby/nearby_support.dart';
import '../support/real_phone.dart';
import '../ui_golden/golden_support.dart';

Map<String, dynamic> _j(String id, String name, String vehicle, int seats,
        {int? rate, int? fare, String? to, bool featured = false, String? trip, bool reversed = false, double km = 5, String label = 'near', String city = 'Haldwani'}) =>
    {
      'id': id,
      'driverName': name,
      'vehicleTypeName': vehicle,
      'plateDisplay': 'UK04',
      'routeCount': 2,
      'createdAt': '2026-11-01T00:00:00Z',
      'cityName': city,
      'stateName': 'Uttarakhand',
      'distanceKm': km,
      'labelKey': label,
      'seats': seats,
      'isFeatured': featured,
      'localDayRate': rate,
      'localDayKm': rate == null ? null : 80,
      'matchedFare': fare,
      'matchedToName': to,
      'matchedTripType': trip,
      'matchReversed': reversed,
      'tripReplyLabel': 'app',
    };

TaxiFeedItem _f(Map<String, dynamic> j) => TaxiFeedItem.fromJson(j);

bool _long = false;

class _Repo extends TaxiFeedRepository {
  @override
  Future<NearbyPage<TaxiFeedItem>> local({required double lat, required double lng, String? pageToken, int pageSize = 20, String? category}) async {
    final hero = _f(_j('h', _long ? 'Pradeep Kumar Singh Rawat Travels' : 'Pradeep Kumar', 'Dzire', 4, fare: 2400, to: 'Nainital', featured: true, km: _long ? 40 : 5, label: _long ? 'far' : 'near', city: _long ? 'Ramgarh' : 'Haldwani'));
    final f2 = _f(_j('f2', 'Rakesh Singh', 'Innova', 7, fare: 2400, to: 'Nainital', featured: true, trip: 'RoundTrip'));
    return NearbyPage(
      featured: [hero, f2],
      items: [
        _f(_j('b', _long ? 'Sunil Kumar Negi Tour and Travels Almora' : 'Sunil Negi', 'Tempo Traveller', 12, rate: 16, city: 'Almora', km: 2)),
        _f(_j('c', 'Mohan Rawat', 'Sedan', 4, fare: 1800, to: 'Haldwani', reversed: true, label: 'inCity', city: 'Bhimtal', km: 1)),
        _f(_j('d', 'Kishan Bisht', 'Alto', 4, km: 24, label: 'far', city: 'Mukteshwar')),
      ],
    );
  }

  @override
  Future<TaxiRouteFeed> route({required double fromLat, required double fromLng, required double toLat, required double toLng, String? category}) async =>
      TaxiRouteFeed(tiers: [
        TaxiTier(key: TaxiTierKey.onRoute, items: [
          _f(_j('r1', 'Pradeep Kumar', 'Dzire', 4, fare: 2600, to: 'Almora', trip: 'RoundTrip')),
          _f(_j('r2', 'Rakesh Singh', 'Innova', 7, fare: 3100, to: 'Almora', reversed: true)),
        ]),
        TaxiTier(key: TaxiTierKey.basedNearFrom, collapsed: true, items: [_f(_j('r3', 'Mohan', 'Sedan', 4, rate: 14))]),
      ]);
}

TaxiBrowseItem _item(String name, {int? fare, int? rate, String vehicle = 'Innova', bool featured = false}) => TaxiBrowseItem.fromJson(
    _j(name, name, vehicle, 7, fare: fare, rate: rate, to: fare == null ? null : 'Almora', featured: featured, trip: fare == null ? null : 'RoundTrip'));

const _d = NearbyDistance(km: 5, label: NearbyLabel.near, city: 'Haldwani');
const _far = NearbyDistance(km: 24, label: NearbyLabel.far, city: 'Mukteshwar', state: 'Uttarakhand');

Widget _cards() => Scaffold(
      backgroundColor: ListingPalette.coral.page,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TaxiCard(item: _item('Rakesh Singh', fare: 2400, featured: true), onOpen: () {}, distance: _d),
            TaxiCard(item: _item('Sunil Kumar Negi Tour and Travels Almora', rate: 16, vehicle: 'Tempo Traveller'), tone: ListingTone.cB, onOpen: () {}, distance: _far),
            TaxiCard(item: _item('No Fare Driver'), tone: ListingTone.cC, onOpen: () {}),
            TaxiCard(item: _item('Trip Driver', fare: 2600), onOpen: () {}, onSelect: () {}, onBook: () {}, onEnquire: () {}),
            TaxiCard(item: _item('Selected Driver', fare: 2600), tone: ListingTone.cB, onOpen: () {}, onSelect: () {}, selected: true, onBook: () {}, onEnquire: () {}, enquiryStatus: TripDisplayStatus.asked),
            TaxiCard(item: _item('Booked Driver', rate: 14), tone: ListingTone.cC, onOpen: () {}, onSelect: () {}, onBook: () {}, booked: true, onEnquire: () {}),
            const TaxiCardSkeleton(),
          ]),
        ),
      ),
    );

void _base() {
  Get.reset();
  (Get.put<LocationController>(JLoc()) as JLoc).userLocation.value = const LatLng(29.2, 79.5);
  Get.put<AuthController>(JAuth());
  Get.put<TabConfigController>(JTabs());
  Get.put(NearbyCentreController());
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await t.pump(const Duration(milliseconds: 400));
  }
  await settlePhone(t);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });
  setUp(() => shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\taxi');
  tearDown(Get.reset);

  for (final cfg in [(1.0, 360.0, false), (1.3, 360.0, true), (1.0, 300.0, true)]) {
    final tag = '${cfg.$1}_${cfg.$2.toInt()}';
    testWidgets('taxi tab $tag', (t) async {
      debugDisableShadows = false;
      _long = cfg.$3;
      _base();
      Get.find<AuthController>().tabIndex.value = 3;
      Get.put(TaxiListControllerV2(root: true, repo: _Repo()), tag: TaxiListControllerV2.tag);
      await pumpPhone(t, const TaxiListScreenV2(root: true), size: Size(cfg.$2, 2600), textScale: cfg.$1);
      await _settle(t);
      await shot(t, 'tab_$tag');
      expect(find.text('WhatsApp'), findsNothing);
      expect(t.takeException(), isNull);
      debugDisableShadows = true;
    });

    testWidgets('taxi cards $tag', (t) async {
      debugDisableShadows = false;
      await pumpPhone(t, _cards(), size: Size(cfg.$2, 2900), textScale: cfg.$1);
      await settlePhone(t);
      await shot(t, 'cards_$tag');
      expect(t.takeException(), isNull);
      debugDisableShadows = true;
    });
  }

  testWidgets('taxi route body 360', (t) async {
    debugDisableShadows = false;
    _base();
    Get.find<AuthController>().tabIndex.value = 3;
    final c = Get.put(TaxiListControllerV2(root: true, repo: _Repo()), tag: TaxiListControllerV2.tag);
    await pumpPhone(t, const TaxiListScreenV2(root: true), size: const Size(360, 2000));
    await _settle(t);
    c.setTo(PlaceResult(name: 'Almora', subtitle: '', latLng: const LatLng(29.6, 79.66)));
    await _settle(t);
    await shot(t, 'route_1.0_360');
    expect(t.takeException(), isNull);
    debugDisableShadows = true;
  });

  testWidgets('taxi pushed copy shows the back bar', (t) async {
    debugDisableShadows = false;
    _base();
    Get.put(TaxiListControllerV2(root: false, repo: _Repo()), tag: TaxiListControllerV2.tag);
    await pumpPhone(t, const TaxiListScreenV2(root: false), size: const Size(360, 900));
    await _settle(t);
    await shot(t, 'pushed_1.0_360');
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(t.takeException(), isNull);
    debugDisableShadows = true;
  });

  testWidgets('browse Call and Enquiry use the contact helper, trip cells keep their callbacks', (t) async {
    var open = 0, enq = 0, sel = 0, book = 0;
    final fetched = <String>[], routes = <String>[];
    ListingContactActions.busy.clear();
    ListingContactActions.debugDeps = ListingContactDeps(
      fetchContact: (kind, id) async {
        fetched.add(id);
        return null;
      },
      currentUserId: () => 'me',
      dial: (_) async {},
      createConversation: (_, _) async => null,
      openRoute: (r, _) => routes.add(r),
      info: (_) {},
    );
    addTearDown(() => ListingContactActions.debugDeps = null);
    await pumpPhone(
      t,
      Scaffold(
        body: ListView(children: [
          TaxiCard(item: _item('Browse', fare: 100), onOpen: () => open++),
          TaxiCard(item: _item('Trip', fare: 100), onOpen: () => open++, onSelect: () => sel++, onBook: () => book++, onEnquire: () => enq++),
        ]),
      ),
      size: const Size(360, 1400),
    );
    await t.tap(find.text('Call').first);
    await t.pump();
    await t.tap(find.text('Enquiry').first);
    await t.pump();
    expect(open, 0);
    expect(fetched, hasLength(1));
    expect(routes, hasLength(2));
    await t.tap(find.text('Enquiry').last);
    await t.tap(find.text('Select'));
    await t.tap(find.text('I booked'));
    expect((enq, sel, book), (1, 1, 1));
  });
}
