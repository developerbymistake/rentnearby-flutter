import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
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

const _short = 'A calm lake in the middle of the town, ringed by green hills. Boating starts in the morning and the mall road runs along the north shore.';

TripSpotModel _w(String id, String title, {int photos = 1, bool featured = false, String cat = 'lake'}) => TripSpotModel(
      id: id,
      source: 'x',
      name: title,
      description: _short,
      latitude: 0,
      longitude: 0,
      category: cat,
      area: 'Mallital',
      visitMinutes: 90,
      isFeatured: featured,
      images: [for (var i = 0; i < photos; i++) 'https://res.cloudinary.com/demo/image/upload/v1/$id$i.jpg'],
    );

const _photoTint = {'lake': Color(0xFF5E8C6A), 'ridge': Color(0xFFC9826A), 'forest': Color(0xFF7DB88A), 'mall': Color(0xFF4C8A5A)};

Widget _flatPhoto(String url, BoxFit fit, Widget fallback) {
  final key = _photoTint.keys.firstWhere((k) => url.contains('/$k'), orElse: () => 'lake');
  return ColoredBox(color: _photoTint[key]!);
}

void _golden(String name, Widget Function() build, {Size view = goldenSize}) {
  for (final scale in [1.0, 1.3]) {
    final s = scale == 1.0 ? '1.0' : '1.3';
    testWidgets('TA golden $name @$s', (t) async {
      await loadGoldenFonts();
      setGoldenView(t, view);
      TripSpotMedia.debugImageBuilder = _flatPhoto;
      addTearDown(() => TripSpotMedia.debugImageBuilder = null);
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
        TripSpotRow(spot: _w('lake', 'Naini Lake', featured: true), selected: false, onToggle: () {}),
        TripSpotRow(spot: _w('ridge', 'Snow View Point', photos: 3), selected: true, onToggle: () {}),
        TripSpotRow(spot: _w('temple', 'Naina Devi Temple', photos: 0, featured: true), selected: false, onToggle: () {}),
        TripSpotRow(spot: _w('forest', 'Eco Cave Gardens'), selected: false, locked: true, onToggle: () {}),
        TripSpotRow(spot: _w('lake', 'Naini Lake'), selected: false, draft: true, subtitle: 'Lake · 1 h 30 min', onToggle: () {}),
        TripSpotRow(spot: _w('ridge', 'Snow View Point'), selected: true, draft: true, subtitle: 'Lake · 1 h 30 min', onToggle: () {}),
        TripSpotRow(spot: _w('forest', 'Eco Cave Gardens'), selected: true, draft: true, dimmed: true, subtitle: 'Lake · 1 h 30 min'),
      ]), view: const Size(360, 2700));
  _golden('trip_home_card', () => const TripHomeCard());
  _golden('trip_spots_extras', () => Column(children: [
        TripSpotRow(spot: _w('ridge', 'Snow View Point', photos: 3), selected: true, onToggle: () {}),
        TripSuggestionCard(spot: _w('forest', 'Mall Road Ridge'), away: '20 min away', onAdd: () {}, onDismiss: () {}),
        TripSuggestionCard(spot: _w('temple', 'Naina Devi Temple', photos: 0, cat: 'temple'), away: 'about 1 km away', onAdd: () {}, onDismiss: () {}),
        TripOfflineBanner(onTap: () {}),
      ]), view: const Size(360, 900));
}
