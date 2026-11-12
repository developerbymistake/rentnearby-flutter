import 'dart:io';
import 'dart:ui' as ui;
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/taxi/guest/taxi_card.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/features/taxi/models/taxi_owner_model.dart';
import 'package:bakhli/features/taxi/setup/taxi_owner_card.dart';
import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/taxi/ways/widgets/local_taxi_rail_card.dart';
import 'package:bakhli/features/taxi/ways/widgets/way_driver_row.dart';
import 'package:bakhli/features/taxi/ways/widgets/ways_arrange_bar.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/widgets/trip_shortlist_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../golden_support.dart';

const _out = 'F:/Dhasu/UI_Template_resume/Repair/shots';

TaxiBrowseItem _taxi({int? rate}) => TaxiBrowseItem(
      id: 't1',
      driverName: 'Ramesh Kumar Negi',
      vehicleTypeName: 'Innova Crysta',
      seats: 7,
      plateDisplay: 'UK07 AB 1234',
      cityName: 'Dehradun',
      minFare: 1800,
      localDayRate: rate,
      localDayKm: rate == null ? null : 80,
      routeCount: 2,
      matchReversed: false,
      createdAt: DateTime(2026, 1, 1),
      isFeatured: true,
    );

const _driver = WayDriver(
  taxiId: 't1',
  driverName: 'Ramesh Kumar Negi',
  vehicleTypeName: 'Innova Crysta',
  seats: 7,
  fromName: 'Dehradun',
  toName: 'Mussoorie',
  listedFare: 1800,
  basedHere: true,
);

TaxiOwnerModel _owner() => TaxiOwnerModel.fromJson({
      'id': 'o1',
      'status': 'Approved',
      'plateDisplay': 'UK07 AB 1234',
      'vehicleTypeName': 'Innova Crysta',
      'seats': 7,
      'cityName': 'Dehradun',
      'minFare': 1800,
      'localDayRate': 2500,
      'localDayKm': 80,
      'routes': [
        {'id': 'r1', 'routeIndex': 1, 'fromName': 'Dehradun', 'toName': 'Mussoorie', 'fare': 1800, 'tripType': 'OneWay'}
      ],
      'createdAt': '2026-01-01T00:00:00Z',
    });

Future<void> _shot(WidgetTester t, String name) async {
  final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot_root')));
  await t.runAsync(() async {
    final img = await ro.toImage(pixelRatio: 1);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    await Directory(_out).create(recursive: true);
    await File('$_out/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Widget _host(Widget child, double w, double scale, {Widget? bottom}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'WorkSans'),
      home: MediaQuery(
        data: MediaQueryData(size: Size(w, 760), textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(
          key: const ValueKey('shot_root'),
          child: Scaffold(
            backgroundColor: DesignColors.scaffold,
            body: child,
            bottomNavigationBar: bottom,
          ),
        ),
      ),
    );

void main() {
  setUp(Get.reset);

  testWidgets('taxi list pieces', (t) async {
    await loadGoldenFonts();
    for (final w in [300.0, 360.0]) {
      for (final s in [1.0, 1.3]) {
        setGoldenView(t, Size(w, 760));
        await t.pumpWidget(_host(
          ListView(padding: const EdgeInsets.only(top: 24), children: [
            TaxiCard(item: _taxi(), onOpen: () {}),
            TaxiCard(item: _taxi(rate: 2500), onOpen: () {}, onSelect: () {}, selected: true, onBook: () {}, onEnquire: () {}),
            WayDriverRow(driver: _driver, onTap: () {}, bestReason: 'Lowest fare', onCall: () {}, onUse: () {}),
            Padding(padding: const EdgeInsets.all(12), child: TaxiOwnerCard(taxi: _owner(), onPreview: () {}, onShare: () {}, onDelete: () {}, onEditFare: (_) {}, onLocalRate: () {}, onTripLeads: () {})),
          ]),
          w,
          s,
        ));
        await settleGolden(t);
        expect(t.takeException(), isNull);
        await _shot(t, 'taxi_list_${w.toInt()}_$s');
      }
    }
  });

  testWidgets('taxi rail card', (t) async {
    await loadGoldenFonts();
    setGoldenView(t, const Size(360, 400));
    await t.pumpWidget(_host(
      Padding(padding: const EdgeInsets.only(top: 40), child: SizedBox(height: LocalTaxiRailCard.baseHeight + 8, child: ListView(scrollDirection: Axis.horizontal, children: [
        LocalTaxiRailCard(item: _taxi(rate: 2500)),
        LocalTaxiRailCard(item: _taxi()),
      ]))),
      360,
      1.3,
    ));
    await settleGolden(t);
    expect(t.takeException(), isNull);
    await _shot(t, 'taxi_rail_360_1.3');
  });

  for (final w in [300.0, 360.0, 412.0]) {
    for (final s in [1.3, 2.0]) {
      testWidgets('shortlist bar docked $w $s', (t) async {
        await loadGoldenFonts();
        Get.put(TripShortlistController(tripId: () async => 't', offline: () => false, warn: (_) {}), permanent: true);
        setGoldenView(t, Size(w, 760));
        await t.pumpWidget(_host(
          ListView(padding: const EdgeInsets.only(top: 24), children: [
            WayDriverRow(driver: _driver, onTap: () {}, onCall: () {}, onShortlist: () {}),
            WayDriverRow(driver: _driver, onTap: () {}, onCall: () {}, onShortlist: () {}),
          ]),
          w,
          s,
          bottom: TripShortlistBar(step: 'taxi', onDone: () {}, tone: KitTone.taxi),
        ));
        await settleGolden(t);
        expect(t.takeException(), isNull);
        final bar = t.getRect(find.byType(TripShortlistBar));
        expect(bar.bottom, 760);
        expect(bar.height, lessThan(200));
        expect(find.text('Done'), findsOneWidget);
        await _shot(t, 'taxi_shortlist_${w.toInt()}_$s');
      });

      testWidgets('arrange bar docked $w $s', (t) async {
        await loadGoldenFonts();
        setGoldenView(t, Size(w, 760));
        var arranged = 0;
        var skipped = 0;
        await t.pumpWidget(_host(
          ListView(padding: const EdgeInsets.only(top: 24), children: [
            WayDriverRow(driver: _driver, onTap: () {}, onCall: () {}),
          ]),
          w,
          s,
          bottom: WaysArrangeBar(arrangeLabel: 'I will arrange it myself', skipLabel: 'Skip this', onArrange: () => arranged++, onSkip: () => skipped++),
        ));
        await settleGolden(t);
        final bar = t.getRect(find.byType(WaysArrangeBar));
        expect(bar.bottom, 760);
        expect(bar.height, lessThan(200));
        await t.tap(find.text('Skip this'));
        await t.tap(find.textContaining('arrange'));
        expect([arranged, skipped], [1, 1]);
        await t.pump();
        await _shot(t, 'taxi_arrange_${w.toInt()}_$s');
      });
    }
  }
}
