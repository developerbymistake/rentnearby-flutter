import 'dart:io';
import 'dart:ui' as ui;
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/screens/trips_discovery_screen.dart';
import 'package:bakhli/features/trip/utils/trip_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _FakeCatalog extends TripCityCatalog {
  @override
  void warmFromDisk() {}

  @override
  Future<List<TripCityModel>> load({bool force = false}) async => const [];
}

class _FakeTrips extends MyTripsController {
  _FakeTrips(this.items);
  final List<TripSummaryModel> items;

  @override
  List<TripSummaryModel> get continueTrips => plannerOff.value ? const [] : items;

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> load() async {}

  @override
  Future<void> refreshIfStale() async {}
}

TripEasyRowModel _row(TripEasyRowKind k, TripRowState s, {int? leg, bool needs = false, int? total, int? covered}) =>
    TripEasyRowModel(key: TripEasyRowKey(k, leg), state: s, needsYou: needs, nightsTotal: total, nightsCovered: covered);

List<TripSummaryModel> _fake() {
  final today = TripClock.today();
  DateTime d(int n) => DateTime(today.year, today.month, today.day + n);
  return [
    TripSummaryModel(
      id: 'a',
      title: 'Nainital & Mukteshwar',
      status: 'draft',
      cityName: 'Nainital',
      dayCount: 4,
      spotCount: 8,
      category: 'trip',
      startDate: d(2),
      endDate: d(5),
      updatedAt: today,
      legCount: 2,
      legCities: const ['Nainital', 'Mukteshwar'],
      progress: TripProgress(
        total: 4,
        done: 2,
        percent: 50,
        needsYou: true,
        next: const TripNextRow(kind: 'stay', legIndex: 1, key: 'stay:1'),
        guideStep: 'stay:1',
        rows: [
          _row(TripEasyRowKind.stay, TripRowState.asked, leg: 1, needs: true, total: 2, covered: 1),
          _row(TripEasyRowKind.taxi, TripRowState.confirmed),
          _row(TripEasyRowKind.gettingThere, TripRowState.todo),
          _row(TripEasyRowKind.comingBack, TripRowState.todo),
        ],
      ),
    ),
    TripSummaryModel(
      id: 'b',
      title: 'Jim Corbett',
      status: 'draft',
      cityName: 'Jim Corbett',
      dayCount: 3,
      spotCount: 4,
      category: 'trip',
      startDate: d(8),
      endDate: d(10),
      updatedAt: today,
      progress: const TripProgress(total: 4, done: 0, percent: 0),
    ),
    TripSummaryModel(
      id: 'c',
      title: 'Rishikesh',
      status: 'draft',
      cityName: 'Rishikesh',
      dayCount: 2,
      spotCount: 3,
      category: 'trip',
      startDate: d(14),
      endDate: d(15),
      updatedAt: today,
      progress: const TripProgress(total: 4, done: 0, percent: 0),
    ),
  ];
}

Future<void> _loadPoppins() async {
  final loader = FontLoader('Poppins');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Poppins-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons');
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/Users/deven/develop/flutter';
  final iconBytes = File('$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf').readAsBytesSync();
  icons.addFont(Future.value(ByteData.sublistView(iconBytes)));
  await icons.load();
}

void main() {
  testWidgets('hub with the Continue bar open', (tester) async {
    await _loadPoppins();
    debugDisableShadows = false;
    Get.testMode = true;
    Get.put<TripCityCatalog>(_FakeCatalog(), permanent: true);
    Get.put<MyTripsController>(_FakeTrips(_fake()), permanent: true);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44);
    tester.view.physicalSize = Size(double.parse(Platform.environment['HUB_W'] ?? '400'), 1780);
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData(fontFamily: 'Poppins'),
        home: RepaintBoundary(key: key, child: const TripsDiscoveryScreen()),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Continue your trip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Next step'), findsOneWidget);
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File(Platform.environment['HUB_SHOT'] ?? 'build/hub_open.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(data!.buffer.asUint8List());
    });
    debugDisableShadows = true;
  });
}
