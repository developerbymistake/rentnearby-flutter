import 'package:bakhli/features/taxi/guest/taxi_card.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/taxi/ways/widgets/taxi_ways_entry_card.dart';
import 'package:bakhli/features/taxi/ways/widgets/way_driver_row.dart';
import 'package:bakhli/models/place_result_model.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden_support.dart';

TaxiBrowseItem _taxi() => TaxiBrowseItem(
      id: 't1',
      driverName: 'Ramesh Kumar Negi',
      vehicleTypeName: 'Innova Crysta',
      seats: 7,
      plateDisplay: 'UK07 AB 1234',
      cityName: 'Dehradun',
      minFare: 1800,
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

void _golden(String name, Widget Function() build) {
  for (final scale in [1.0, 1.3]) {
    final s = scale == 1.0 ? '1.0' : '1.3';
    testWidgets('TX golden $name @$s', (t) async {
      await loadGoldenFonts();
      setGoldenView(t);
      await t.pumpWidget(goldenHost(build(), scale: scale));
      await settleGolden(t);
      expect(t.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('golden_root')),
        matchesGoldenFile('goldens/${name}_$s.png'),
      );
    });
  }
}

void main() {
  _golden('taxi_card', () => Column(children: [
        TaxiCard(item: _taxi(), onOpen: () {}),
        TaxiCard(item: _taxi(), onOpen: () {}, onSelect: () {}, selected: true, onBook: () {}, onEnquire: () {}),
        const TaxiCardSkeleton(),
      ]));
  _golden('way_driver_row', () => Column(children: [
        WayDriverRow(driver: _driver, onTap: () {}, onCall: () {}, onUse: () {}),
        const SizedBox(height: 12),
        WayDriverRow(driver: _driver, onTap: () {}, bestReason: 'Lowest fare', onCall: () {}),
      ]));
  _golden('ways_entry_card', () {
    final a = PlaceResult(name: 'Dehradun', subtitle: 'Uttarakhand', latLng: LatLng(30.3, 78.0));
    final b = PlaceResult(name: 'Mussoorie', subtitle: 'Uttarakhand', latLng: LatLng(30.4, 78.07));
    return TaxiWaysEntryCard(from: a, to: b);
  });
}
