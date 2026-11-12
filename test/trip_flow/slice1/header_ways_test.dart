import 'dart:io';
import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_controller.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_feed_screen.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_guide_args.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/models/place_result_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../support/real_phone.dart';

class _Repo extends TripShortlistRepository {
  const _Repo();
  @override
  Future<TripShortlist> list(String tripId) async => const TripShortlist(items: [], max: 3);
}

class _Ways extends TaxiWaysController {
  _Ways(PlaceResult from, PlaceResult to)
      : super(from: from, to: to, tripId: 't', tripRole: 'gettingThere', fromTrip: true, date: DateTime(2030, 1, 5), people: 2);

  @override
  Future<void> load() async {
    result.value = TaxiWaysResult(
      version: '1',
      from: const WayPlace(key: 'h', name: 'Haldwani', lat: 29.2, lng: 79.5, resolved: true),
      to: const WayPlace(key: 'b', name: 'Almora', lat: 29.6, lng: 79.6, resolved: true),
      allTheWay: [
        for (var i = 0; i < 8; i++)
          WayDriver(
            taxiId: 'd$i',
            driverName: 'Driver $i',
            vehicleTypeName: 'Sedan',
            seats: 4,
            fromName: 'Haldwani',
            toName: 'Almora',
            listedFare: 2200 + i * 300,
          ),
      ],
    );
  }
}

PlaceResult _place(String n) => PlaceResult(name: n, subtitle: n, latLng: const LatLng(29.2, 79.4));

String _sz(Size s) => '${s.width.toInt()}x${s.height.toInt()}';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
  });
  tearDown(Get.reset);

  for (final s in const [Size(360, 800), Size(300, 640)]) {
    testWidgets('ways header ${_sz(s)}', (t) async {
      Get.testMode = true;
      Get.put(TripShortlistController(repo: const _Repo(), tripId: () async => 't', offline: () => false, warn: (_) {}));
      final c = _Ways(_place('Kamalwaganja'), _place('Almora'));
      Get.put(c, tag: 'ways-test');
      await pumpPhone(t, TaxiWaysFeedScreen(debugController: c, debugGuide: const GuideArgs('gettingThere')), size: s);
      await settlePhone(t);
      expect(find.text('Kamalwaganja'), findsWidgets);
      expect(find.text('Haldwani'), findsNothing, reason: 'one origin name');
      final z = _sz(s);
      final scroll = t.state<ScrollableState>(find.byType(Scrollable).first);
      final max = scroll.position.maxScrollExtent;
      final offs = [0.0, 120.0, 400.0, max];
      for (var i = 0; i < offs.length; i++) {
        scroll.position.jumpTo(offs[i].clamp(0, max).toDouble());
        await t.pump();
        await t.pump(const Duration(milliseconds: 100));
        if (i > 0) {
          final cover = find.byWidgetPredicate((w) => w is Container && w.color != null && w.constraints?.maxHeight == 28);
          expect(cover, findsOneWidget, reason: 'status bar cover missing at ${offs[i]}');
        }
        await shot(t, 'C_ways_${z}_$i');
      }
      expect(t.takeException(), isNull);
    });
  }
}
