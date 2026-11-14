import 'dart:io';
import 'dart:ui' as ui;
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/screens/my_trips_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _FakeMyTrips extends MyTripsController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> load() async {
    pastOpen.value = true;
    active.assignAll([_nainital(), _corbett()]);
    past.assignAll([_mussoorie()]);
    counts.value = const TripListCounts(completed: 1);
  }

  @override
  Future<void> loadPast() async {}

  @override
  Future<void> loadMore() async {}
}

TripEasyRowModel _row(TripEasyRowKind k, TripRowState s, {int? leg, int? total, int? covered, bool needs = false}) =>
    TripEasyRowModel(key: TripEasyRowKey(k, leg), state: s, nightsTotal: total, nightsCovered: covered, needsYou: needs);

TripSummaryModel _nainital() => TripSummaryModel(
      id: 'a1',
      title: '',
      status: 'draft',
      cityName: 'Nainital',
      dayCount: 4,
      spotCount: 8,
      category: 'trip',
      startDate: DateTime(2026, 11, 14),
      endDate: DateTime(2026, 11, 17),
      updatedAt: DateTime(2026, 11, 10),
      legCount: 2,
      legCities: const ['Nainital', 'Mukteshwar'],
      progress: TripProgress(
        total: 4,
        done: 2,
        percent: 50,
        next: const TripNextRow(kind: 'stay', legIndex: 1, key: 'stay:1'),
        rows: [
          _row(TripEasyRowKind.stay, TripRowState.confirmed, leg: 1, total: 1, covered: 1),
          _row(TripEasyRowKind.stay, TripRowState.asked, leg: 2, total: 1, covered: 0, needs: true),
          _row(TripEasyRowKind.taxi, TripRowState.booked),
          _row(TripEasyRowKind.gettingThere, TripRowState.todo),
        ],
      ),
    );

TripSummaryModel _corbett() => TripSummaryModel(
      id: 'a2',
      title: '',
      status: 'draft',
      cityName: 'Jim Corbett',
      dayCount: 3,
      spotCount: 5,
      category: 'trip',
      startDate: DateTime(2026, 11, 20),
      endDate: DateTime(2026, 11, 22),
      updatedAt: DateTime(2026, 11, 9),
      progress: TripProgress(
        total: 4,
        done: 0,
        percent: 0,
        next: const TripNextRow(kind: 'gettingThere', key: 'gettingThere'),
        rows: [
          _row(TripEasyRowKind.gettingThere, TripRowState.todo),
          _row(TripEasyRowKind.stay, TripRowState.todo, leg: 1),
          _row(TripEasyRowKind.taxi, TripRowState.todo),
          _row(TripEasyRowKind.comingBack, TripRowState.todo),
        ],
      ),
    );

TripSummaryModel _mussoorie() => TripSummaryModel(
      id: 'p1',
      title: '',
      status: TripStatuses.completed,
      cityName: 'Mussoorie',
      dayCount: 3,
      spotCount: 6,
      category: 'trip',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 7),
      completedAt: DateTime(2026, 10, 7, 12),
      updatedAt: DateTime(2026, 10, 7),
      progress: TripProgress(
        total: 4,
        done: 4,
        percent: 100,
        rows: [
          _row(TripEasyRowKind.stay, TripRowState.confirmed, leg: 1, total: 2, covered: 2),
          _row(TripEasyRowKind.taxi, TripRowState.booked),
          _row(TripEasyRowKind.gettingThere, TripRowState.booked),
          _row(TripEasyRowKind.comingBack, TripRowState.booked),
        ],
      ),
    );

Future<void> _loadFonts() async {
  final loader = FontLoader('Poppins');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Poppins-$w.ttf'));
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('My Trips renders the hub card design', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(400, 1360);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44);
    tester.view.viewPadding = const FakeViewPadding(top: 44);
    addTearDown(tester.view.reset);
    Get.testMode = true;
    Get.put<MyTripsController>(_FakeMyTrips());
    addTearDown(Get.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: GetMaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Poppins'),
          home: const MyTripsScreen(),
        ),
      ),
    );
    await tester.runAsync(() async {
      for (final e in tester.allElements.toList()) {
        final w = e.widget;
        if (w is Image) await precacheImage(w.image, e);
      }
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 1);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final f = File('test/features/trip/goldens/hub_my_trips.png');
      f.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    expect(find.text('My Trips'), findsOneWidget);
  });
}
