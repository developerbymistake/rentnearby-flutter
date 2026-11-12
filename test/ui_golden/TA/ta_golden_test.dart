import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/utils/trip_spot_picks.dart';
import 'package:bakhli/features/trip/widgets/trip_card.dart';
import 'package:bakhli/features/trip/widgets/trip_home_card.dart';
import 'package:bakhli/features/trip/widgets/trip_spot_row.dart';
import 'package:bakhli/features/trip/widgets/trip_spots_extras.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden_support.dart';

TripSummaryModel _trip({int done = 1, int total = 4}) => TripSummaryModel(
      id: 'a',
      title: 'Nainital and Mussoorie',
      status: 'planned',
      cityName: 'Nainital',
      dayCount: 3,
      spotCount: 8,
      category: 'trip',
      updatedAt: DateTime(2026, 1, 1),
      legCount: 2,
      legCities: const ['Nainital', 'Mussoorie'],
      progress: TripProgress(total: total, done: done, inProgress: 1, percent: (done * 100 / total).round()),
    );

TripSpotModel _spot(String cat, {bool featured = false}) => TripSpotModel(
      id: cat,
      source: 'x',
      name: 'Naini Lake boating',
      description: 'Calm boat ride at sunset',
      latitude: 0,
      longitude: 0,
      category: cat,
      area: 'Mall Road',
      visitMinutes: 60,
      isFeatured: featured,
    );

void _golden(String name, Widget Function() build) {
  for (final scale in [1.0, 1.3]) {
    final s = scale == 1.0 ? '1.0' : '1.3';
    testWidgets('TA golden $name @$s', (t) async {
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
  _golden('trip_card', () => Column(children: [
        TripCard(trip: _trip(), onOpen: () {}, onAction: () {}, onDelete: () {}, onShare: () {}),
        const SizedBox(height: 12),
        TripCard(trip: _trip(done: 4), past: true, onOpen: () {}, onAction: () {}, onDelete: () {}),
      ]));
  _golden('trip_spot_row', () => Column(children: [
        TripSpotRow(spot: _spot('lake', featured: true), selected: false, onToggle: () {}),
        const SizedBox(height: 12),
        TripSpotRow(spot: _spot('temple'), selected: true, onToggle: () {}),
        const SizedBox(height: 12),
        TripSpotRow(spot: _spot('market'), selected: false, locked: true, onToggle: () {}),
      ]));
  _golden('trip_home_card', () => const TripHomeCard());
  _golden('trip_spots_extras', () => Column(children: [
        TripQuickStartRail(
          bundles: const [
            TripQuickStart('l', 'Lakes', ['a', 'b']),
            TripQuickStart('t', 'Temples', ['a', 'b', 'c']),
          ],
          onTap: (_) {},
        ),
        TripSuggestionCard(text: 'Mall Road is close by', onAdd: () {}, onDismiss: () {}),
        TripOfflineBanner(onTap: () {}),
      ]));
}
