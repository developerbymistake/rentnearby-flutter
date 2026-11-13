import 'dart:io';

import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_controller.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_feed_screen.dart';
import 'package:bakhli/features/taxi/ways/widgets/taxi_ways_entry_card.dart';
import 'package:bakhli/models/place_result_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../support/real_phone.dart';

Map<String, Object?> _place(String key, String name) => {'key': key, 'name': name, 'lat': 29.3, 'lng': 79.5};

Map<String, Object?> _driver(String id, String name, String vehicle, int seats, int fare) => {
      'taxiId': id,
      'driverName': name,
      'vehicleTypeName': vehicle,
      'seats': seats,
      'fromName': 'Haldwani',
      'toName': 'Almora',
      'listedFare': fare,
    };

Map<String, Object?> _local(String id, String name, String vehicle, int seats, int rate) => {
      'id': id,
      'driverName': name,
      'vehicleTypeName': vehicle,
      'seats': seats,
      'plateDisplay': 'UK04 TA',
      'cityName': 'Almora',
      'routeCount': 1,
      'matchReversed': false,
      'createdAt': '2026-10-01T00:00:00Z',
      'localDayRate': rate,
    };

Map<String, Object?> _stay(String id, String name, String type, int price) => {
      'id': id,
      'name': name,
      'stayTypeName': type,
      'latitude': 29.6,
      'longitude': 79.6,
      'minPricePerNight': price,
      'distanceKm': 1.2,
      'isActive': true,
      'cityName': 'Almora',
    };

Map<String, dynamic> _json({String to = 'Almora', bool drivers = false, bool dest = false, bool reach = false}) => {
      'version': 'v1',
      'from': _place('a', 'Haldwani'),
      'to': _place('b', to),
      'allTheWay': drivers ? [_driver('d1', 'Pradeep Kumar', 'Dzire', 4, 2600), _driver('d2', 'Rakesh Singh', 'Innova', 7, 3100)] : [],
      'plans': [],
      'localTaxis': dest
          ? [_local('l1', 'Mohan', 'Sedan', 4, 1800), _local('l2', 'Kailash', 'SUV', 6, 2600), _local('l3', 'Harish', 'Tempo Traveller', 12, 4000)]
          : [],
      'stays': dest ? [_stay('s1', 'Deodar Cottage', 'Homestay', 1500), _stay('s2', 'Pine Ridge', 'Hotel', 2400)] : [],
      if (reach) 'reachFirstPlace': _place('h', 'Haldwani'),
    };

class _Ways extends TaxiWaysController {
  _Ways(this.json, {bool trip = false, String to = 'Almora'})
      : super(
          from: PlaceResult(name: trip ? 'Almora' : 'Haldwani', subtitle: '', latLng: const LatLng(29.2, 79.5)),
          to: PlaceResult(name: to, subtitle: '', latLng: const LatLng(29.6, 79.7)),
          tripId: trip ? 't' : null,
          tripRole: trip ? 'gettingThere' : null,
          fromTrip: trip,
          date: DateTime.now().add(const Duration(days: 1)),
          people: 2,
        );
  final Map<String, dynamic>? json;
  void Function(_Ways c)? state;

  @override
  Future<void> load() async {
    final j = json;
    if (j != null) result.value = TaxiWaysResult.fromJson(j);
    state?.call(this);
  }
}

const _cases = [(Size(360, 800), 1.0, '360'), (Size(360, 800), 1.3, '360x13'), (Size(300, 640), 1.0, '300')];

Future<void> _pumpFeed(WidgetTester t, _Ways c, {Size size = const Size(360, 800), double scale = 1}) async {
  Get.put(c, tag: 'ways-test');
  await pumpPhone(t, TaxiWaysFeedScreen(debugController: c), size: size, textScale: scale);
  await settlePhone(t);
}

Future<void> _scrollTo(WidgetTester t, Finder f) async {
  final s = t.state<ScrollableState>(find.byType(Scrollable).first);
  final box = t.renderObject<RenderBox>(f);
  final y = box.localToGlobal(Offset.zero).dy + s.position.pixels - 120;
  s.position.jumpTo(y.clamp(0, s.position.maxScrollExtent));
  await t.pump(const Duration(milliseconds: 300));
  await settlePhone(t);
}

void main() {
  shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\journeys';
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
  });
  setUp(() {
    Get.testMode = true;
    debugDisableShadows = false;
  });
  tearDown(() => Get.reset(clearRouteBindings: true));

  for (final (name, apply) in <(String, void Function(_Ways))>[
    ('feed_load', (c) => c.isLoading.value = true),
    ('feed_off', (c) => c
      ..isOffline.value = true
      ..loadFailed.value = true),
    ('feed_fail', (c) => c.loadFailed.value = true),
    ('feed_taxisoff', (c) => c
      ..tabOff.value = true
      ..loadFailed.value = true
      ..errorText.value = 'Taxis are not available right now'),
  ]) {
    testWidgets(name, (t) async {
      final c = _Ways(null)..state = apply;
      await _pumpFeed(t, c);
      await shot(t, name);
      if (name == 'feed_load') expect(find.byKey(const ValueKey('list-loading')), findsOneWidget);
      if (name == 'feed_taxisoff') expect(find.text('Retry'), findsNothing);
      if (name == 'feed_fail' || name == 'feed_off') {
        expect(find.text('Retry'), findsOneWidget);
      }
      expect(t.takeException(), isNull);
      debugDisableShadows = true;
    });
  }

  for (final (size, scale, tag) in _cases) {
    testWidgets('feed_none $tag', (t) async {
      await _pumpFeed(t, _Ways(_json(to: 'Munsiyari'), to: 'Munsiyari'), size: size, scale: scale);
      await shot(t, 'feed_none_$tag');
      expect(find.text('No taxis in Munsiyari yet', skipOffstage: false), findsOneWidget);
      expect(t.takeException(), isNull);
      debugDisableShadows = true;
    });

    testWidgets('feed_dest $tag', (t) async {
      await _pumpFeed(t, _Ways(_json(drivers: true, dest: true)), size: size, scale: scale);
      await _scrollTo(t, find.text('At Almora'));
      await shot(t, 'feed_dest_$tag');
      expect(find.text('View & call', skipOffstage: false), findsWidgets);
      final s = t.state<ScrollableState>(find.byType(Scrollable).first);
      s.position.jumpTo(s.position.maxScrollExtent);
      await t.pump(const Duration(milliseconds: 300));
      await settlePhone(t);
      await shot(t, 'feed_dest_end_$tag');
      expect(find.text('Ask for a room', skipOffstage: false), findsWidgets);
      expect(t.takeException(), isNull);
      debugDisableShadows = true;
    });

    testWidgets('feed_gap $tag', (t) async {
      final c = _Ways(_json(to: 'Munsiyari', reach: true), trip: true, to: 'Munsiyari');
      await _pumpFeed(t, c, size: size, scale: scale);
      await shot(t, 'feed_gap_$tag');
      expect(find.text('Search again'), findsOneWidget);
      expect(find.text('I will arrange it myself'), findsOneWidget);
      expect(find.text('Skip this'), findsOneWidget);
      expect(t.takeException(), isNull);
      debugDisableShadows = true;
    });

    testWidgets('feed_entry $tag', (t) async {
      final a = PlaceResult(name: 'Haldwani', subtitle: '', latLng: const LatLng(29.2, 79.5));
      final b = PlaceResult(name: 'Almora', subtitle: '', latLng: const LatLng(29.6, 79.7));
      await pumpPhone(
        t,
        Scaffold(
          backgroundColor: const Color(0xFFFFE3DC),
          body: ListView(padding: const EdgeInsets.only(top: 60), children: [
            TaxiWaysEntryCard(from: a, to: b),
            TaxiWaysEntryCard(from: a, to: b, empty: true),
          ]),
        ),
        size: size,
        textScale: scale,
      );
      await settlePhone(t);
      await shot(t, 'feed_entry_$tag');
      expect(find.text('Every way to go'), findsOneWidget);
      expect(t.takeException(), isNull);
      debugDisableShadows = true;
    });
  }

  testWidgets('feed_cal', (t) async {
    await _pumpFeed(t, _Ways(_json(drivers: true)));
    await t.tap(find.textContaining('Tomorrow').first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await settlePhone(t);
    await shot(t, 'feed_cal');
    expect(find.text('Apply'), findsOneWidget);
    debugDisableShadows = true;
  });
}
