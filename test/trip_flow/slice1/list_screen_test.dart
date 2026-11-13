import 'dart:io';
import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_controller.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_feed_screen.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_guide_args.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/trip_strings_shortlist.dart';
import 'package:bakhli/features/trip/widgets/trip_shortlist_bar.dart';
import 'package:bakhli/models/place_result_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../support/real_phone.dart';

enum _Mode { loading, ready, empty, error, offline }

class _Repo extends TripShortlistRepository {
  _Repo(this.pre);
  final List<ShortlistItem> pre;
  @override
  Future<TripShortlist> list(String tripId) async => TripShortlist(items: pre, max: 3);
  @override
  Future<List<ShortlistItem>> add(String tripId, String stepKey, String listingId, ShortlistItem item) async => (pre..removeWhere((i) => i.listingId == listingId)..add(item)).toList();
  @override
  Future<void> remove(String tripId, String stepKey, String listingId) async {
    pre.removeWhere((i) => i.listingId == listingId);
  }
}

class _Ways extends TaxiWaysController {
  _Ways(this.mode, PlaceResult from, PlaceResult to)
      : super(from: from, to: to, tripId: 't', tripRole: 'gettingThere', fromTrip: true, date: DateTime(2030, 1, 5), people: 2);
  final _Mode mode;
  int loads = 0;
  int drivers = 4;

  @override
  Future<void> load() async {
    loads++;
    switch (mode) {
      case _Mode.loading:
        isLoading.value = true;
      case _Mode.ready:
        result.value = _result(drivers);
      case _Mode.empty:
        result.value = _result(0);
      case _Mode.error:
        loadFailed.value = true;
      case _Mode.offline:
        loadFailed.value = true;
        isOffline.value = true;
    }
  }
}

const _from = WayPlace(key: 'a', name: 'Delhi', lat: 28.6, lng: 77.2, resolved: true);
const _to = WayPlace(key: 'b', name: 'Nainital', lat: 29.4, lng: 79.4, resolved: true);

TaxiWaysResult _result(int n) => TaxiWaysResult(
      version: '1',
      from: _from,
      to: _to,
      allTheWay: [
        for (var i = 0; i < n; i++)
          WayDriver(
            taxiId: 'd$i',
            driverName: ['Ramesh Negi', 'Suresh Bisht', 'Mahesh Joshi', 'Dinesh Rawat'][i % 4],
            vehicleTypeName: 'Sedan',
            seats: 4,
            fromName: 'Delhi',
            toName: 'Nainital',
            listedFare: 5200 + i * 300,
            basedHere: i == 0,
          ),
      ],
    );

PlaceResult _place(String n) => PlaceResult(name: n, subtitle: n, latLng: const LatLng(28.6, 77.2));

final warnings = <String>[];

Future<_Ways> _open(WidgetTester t, _Mode mode, {Size size = phoneSize, int pre = 0, double scale = 1, int drivers = 4}) async {
  Get.testMode = true;
  warnings.clear();
  Get.put(TripShortlistController(
    repo: _Repo([for (var i = 0; i < pre; i++) ShortlistItem(stepKey: 'gettingThere', kind: 'Car', listingId: 'd$i', name: 'D$i')]),
    tripId: () async => 't',
    offline: () => false,
    warn: warnings.add,
  ));
  final c = _Ways(mode, _place('Delhi'), _place('Nainital'))..drivers = drivers;
  Get.put(c, tag: 'ways-test');
  await pumpPhone(
    t,
    TaxiWaysFeedScreen(debugController: c, debugGuide: const GuideArgs('gettingThere')),
    size: size,
    textScale: scale,
  );
  await settlePhone(t);
  return c;
}

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

  const sizes = [Size(360, 800), Size(300, 640)];
  Future<void> shortlistTap(WidgetTester t, int i) async {
    await t.ensureVisible(find.text('Shortlist').at(i));
    await t.pump();
    await t.tap(find.text('Shortlist').at(i));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }

  for (final s in sizes) {
    final z = _sz(s);
    testWidgets('loading $z', (t) async {
      await _open(t, _Mode.loading, size: s);
      expect(find.byKey(const ValueKey('list-loading')), findsOneWidget);
      expect(find.text(TripStringsShortlist.loadingTaxis), findsOneWidget);
      await shot(t, 'B_loading_$z');
    });
    testWidgets('empty $z', (t) async {
      await _open(t, _Mode.empty, size: s);
      expect(find.text(TripStringsShortlist.emptyTitle), findsOneWidget);
      expect(find.text(TripStringsShortlist.emptyBody), findsOneWidget);
      expect(find.text('I will arrange it myself'), findsWidgets);
      expect(find.text('Skip this'), findsWidgets);
      expect(TripStringsShortlist.emptyFull, 'No taxis found for this route yet. You can arrange it yourself or skip.');
      await shot(t, 'B_empty_$z');
    });
    testWidgets('error with retry $z', (t) async {
      final c = await _open(t, _Mode.error, size: s);
      expect(find.text("Couldn't load ways to go"), findsOneWidget);
      expect(find.text('I will arrange it myself'), findsOneWidget);
      await t.tap(find.text('Retry'));
      await t.pump();
      expect(c.loads, 2);
      await shot(t, 'B_error_$z');
    });
    testWidgets('one shortlisted $z', (t) async {
      await _open(t, _Mode.ready, size: s, pre: 1);
      expect(find.text('1 of 3 shortlisted'), findsOneWidget);
      await shot(t, 'B_one_$z');
    });
    testWidgets('three shortlisted and full $z', (t) async {
      await _open(t, _Mode.ready, size: s, pre: 3);
      expect(find.text('3 of 3 shortlisted'), findsOneWidget);
      expect(find.text(TripStringsShortlist.full), findsOneWidget);
      await shot(t, 'B_three_$z');
    });
    testWidgets('fourth blocked, remove frees a slot $z', (t) async {
      await _open(t, _Mode.ready, size: s);
      for (var i = 0; i < 3; i++) {
        await shortlistTap(t, 0);
        expect(find.text('${i + 1} of 3 shortlisted'), findsOneWidget);
      }
      final sc = TripShortlistController.to;
      expect(sc.countOf('gettingThere'), 3);
      await t.ensureVisible(find.text('Shortlist').first);
      await t.pump();
      await t.tap(find.text('Shortlist').first);
      await t.pump();
      expect(warnings, contains(TripStringsShortlist.full));
      expect(find.text('3 of 3 shortlisted'), findsOneWidget);
      await t.ensureVisible(find.text('Shortlisted').first);
      await t.pump();
      await t.tap(find.text('Shortlisted').first);
      await t.pump();
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('2 of 3 shortlisted'), findsOneWidget);
      await shot(t, 'B_full_$z');
    });
    testWidgets('done with none says what to do, stays on the list $z', (t) async {
      await _open(t, _Mode.ready, size: s);
      expect(find.byKey(const ValueKey('shortlist-bar-note')), findsNothing);
      await t.tap(find.text('Done'));
      await t.pump();
      expect(find.text(TripStringsShortlist.pickFirst), findsOneWidget);
      expect(find.text('Send to all'), findsNothing);
      expect(find.byType(TaxiWaysFeedScreen), findsOneWidget);
      await shot(t, 'B_done_none_$z');
    });
    testWidgets('bar is docked and the list scrolls clear of it $z', (t) async {
      await _open(t, _Mode.ready, size: s, pre: 1, scale: 2);
      final bar = t.getRect(find.byType(TripShortlistBar));
      expect(bar.bottom, s.height);
      expect(t.noException, isTrue);
      final pos = t.state<ScrollableState>(find.byType(Scrollable).first).position;
      pos.jumpTo(pos.maxScrollExtent);
      await t.pump(const Duration(milliseconds: 100));
      final last = t.getRect(find.byKey(const ValueKey('d-d3')));
      expect(last.bottom, lessThanOrEqualTo(bar.top));
      await shot(t, 'B_scrolled_scale2_$z');
    });
  }
}

extension on WidgetTester {
  bool get noException => takeException() == null;
}
