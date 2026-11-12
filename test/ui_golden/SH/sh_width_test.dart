import 'package:bakhli/controllers/report_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/screens/intro/intro_widgets.dart';
import 'package:bakhli/widgets/home_taxi_rail_card.dart';
import 'package:bakhli/widgets/nearby_item_row.dart';
import 'package:bakhli/widgets/report_listing_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../golden_support.dart';

class _Reports extends ReportController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> loadReportReasons() async {}
}

TaxiBrowseItem _taxi(int? fare) => TaxiBrowseItem(
      id: 't1',
      driverName: 'Ramesh Kumar Negi With A Long Name',
      vehicleTypeName: 'Innova Crysta',
      seats: 7,
      plateDisplay: 'UK07 AB 1234',
      cityName: 'Dehradun',
      minFare: fare,
      routeCount: 2,
      matchReversed: false,
      createdAt: DateTime(2026, 1, 1),
      isFeatured: true,
    );

Widget _host(Widget child, double width, double scale) => MaterialApp(
      theme: ThemeData(fontFamily: 'WorkSans'),
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 760), textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: child),
      ),
    );

void main() {
  setUpAll(loadGoldenFonts);

  const widths = [300.0, 360.0, 412.0, 560.0];
  const scales = [1.0, 1.3];

  for (final w in widths) {
    for (final s in scales) {
      testWidgets('HomeTaxiRailCard fixed height w$w s$s', (t) async {
        setGoldenView(t, Size(w, 760));
        for (final fare in [1800, null]) {
          await t.pumpWidget(_host(
            Align(alignment: Alignment.topLeft, child: SizedBox(height: RailCard.height + 24, child: HomeTaxiRailCard(taxi: _taxi(fare)))),
            w,
            s,
          ));
          await t.pump(const Duration(seconds: 1));
          expect(t.takeException(), isNull);
        }
      });

      testWidgets('NearbyItemRow w$w s$s', (t) async {
        setGoldenView(t, Size(w, 760));
        await t.pumpWidget(_host(
          SingleChildScrollView(
            child: Column(children: [
              for (final elevated in [false, true])
                NearbyItemRow(
                  thumbnailUrl: null,
                  tag: 'FOR STAY',
                  title: 'Deodar Valley Homestay With A Long Name',
                  subtitle: 'Homestay · 2 km',
                  caption: 'FROM',
                  value: '₹1,800',
                  unit: '/night',
                  placeholderIcon: Icons.hotel,
                  isFeatured: true,
                  elevated: elevated,
                  onTap: () {},
                ),
            ]),
          ),
          w,
          s,
        ));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
      });

      testWidgets('IntroCtaButton w$w s$s', (t) async {
        setGoldenView(t, Size(w, 760));
        for (final p in [0.0, 2.5, 5.0]) {
          final progress = ValueNotifier<double>(p);
          await t.pumpWidget(_host(
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(alignment: Alignment.bottomCenter, child: IntroCtaButton(progress: progress, isLast: p == 5.0, onTap: () {})),
            ),
            w,
            s,
          ));
          await t.pump(const Duration(milliseconds: 600));
          expect(t.takeException(), isNull);
          expect(find.byType(IntroCtaButton), findsOneWidget);
        }
        await t.pumpWidget(const SizedBox());
      });
    }
  }

  for (final w in [300.0, 360.0]) {
    testWidgets('stay map ListRow as in StayMapScreen w$w s1.3', (t) async {
      setGoldenView(t, Size(w, 760));
      await t.pumpWidget(_host(
        Stack(children: [
          for (final elevated in [false, true])
            Positioned(
              bottom: elevated ? 86 : 300,
              left: elevated ? 20 : 0,
              right: elevated ? 20 : 0,
              child: ListRow(
                thumbnailUrl: null,
                tag: 'FOR STAY',
                title: 'Deodar Valley Homestay With A Long Name',
                subtitle: 'Homestay · 12.4 km',
                priceCaption: 'FROM',
                priceValue: '₹12,800',
                priceUnit: '/night',
                iconAsset: TravelIcon.stay,
                isFeatured: true,
                margin: elevated ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 6),
                onTap: () {},
              ),
            ),
        ]),
        w,
        1.3,
      ));
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('ReportListingSheet 300dp scale 1.3', (t) async {
    Get.put<ReportController>(_Reports());
    addTearDown(Get.reset);
    setGoldenView(t, const Size(300, 760));
    await t.pumpWidget(_host(const Align(alignment: Alignment.bottomCenter, child: ReportListingSheet(listingId: 'a', listingType: 'Stay')), 300, 1.3));
    await t.pump(const Duration(seconds: 2));
    expect(t.takeException(), isNull);
    expect(find.text('Submit'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
