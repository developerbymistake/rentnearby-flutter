import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/widgets/trip_spot_row.dart';
import 'package:bakhli/features/trip/widgets/trip_spots_extras.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_phone.dart';

const _dir = r'F:\Dhasu\Buddy_resume\wgw\shots\w1';
const _short = 'A calm lake in the middle of the town, ringed by green hills. Boating starts in the morning and the mall road runs along the north shore.';

TripSpotModel _w(String id, String title, {int photos = 1, bool featured = false, String cat = 'lake'}) => TripSpotModel(
  id: id,
  source: 'x',
  name: title,
  description: _short,
  latitude: 0,
  longitude: 0,
  category: cat,
  visitMinutes: 90,
  isFeatured: featured,
  images: [for (var i = 0; i < photos; i++) 'https://res.cloudinary.com/demo/image/upload/v1/$id$i.jpg'],
);

const _tint = {'lake': Color(0xFF5E8C6A), 'ridge': Color(0xFFC9826A), 'forest': Color(0xFF7DB88A)};

Widget _photo(String url, BoxFit fit, Widget fallback) => ColoredBox(color: _tint[_tint.keys.firstWhere((k) => url.contains('/$k'), orElse: () => 'lake')]!);

final _frames = <String, Widget Function()>{
  'S1': () => TripSpotRow(spot: _w('lake', 'Naini Lake', featured: true), selected: false, onToggle: () {}),
  'S2': () => TripSpotRow(spot: _w('ridge', 'Snow View Point', photos: 3), selected: true, onToggle: () {}),
  'S3': () => TripSpotRow(spot: _w('temple', 'Naina Devi Temple', photos: 0, featured: true), selected: false, onToggle: () {}),
  'S4': () => TripSpotRow(spot: _w('forest', 'Eco Cave Gardens'), selected: false, locked: true, onToggle: () {}),
  'S5': () => Column(
    children: [
      TripSpotRow(spot: _w('ridge', 'Snow View Point', photos: 3), selected: true, onToggle: () {}),
      TripSuggestionCard(spot: _w('forest', 'Mall Road Ridge'), away: '20 min away', onAdd: () {}, onDismiss: () {}),
    ],
  ),
  'S5b': () => Column(
    children: [
      TripSpotRow(spot: _w('ridge', 'Snow View Point', photos: 3), selected: true, onToggle: () {}),
      TripSuggestionCard(
        spot: _w('temple', 'Naina Devi Temple', photos: 0, cat: 'temple'),
        away: 'about 1 km away',
        onAdd: () {},
        onDismiss: () {},
      ),
    ],
  ),
  'draft': () => Column(
    children: [
      TripSpotRow(spot: _w('lake', 'Naini Lake'), selected: false, draft: true, subtitle: 'Lake · 1 h 30 min', onToggle: () {}),
      TripSpotRow(spot: _w('ridge', 'Snow View Point'), selected: true, draft: true, subtitle: 'Lake · 1 h 30 min', onToggle: () {}),
      TripSpotRow(spot: _w('forest', 'Eco Cave Gardens'), selected: true, draft: true, dimmed: true, subtitle: 'Lake · 1 h 30 min'),
    ],
  ),
};

void main() {
  shotsDir = _dir;
  setUp(() => TripSpotMedia.debugImageBuilder = _photo);
  tearDown(() => TripSpotMedia.debugImageBuilder = null);

  for (final w in [360.0, 320.0]) {
    for (final s in [1.0, 1.3]) {
      for (final e in _frames.entries) {
        if (w != 360 && e.key != 'S1' && e.key != 'S5') continue;
        testWidgets('wishlist shot ${e.key} ${w.toInt()} x $s', (t) async {
          debugDisableShadows = false;
          try {
            await pumpPhone(
              t,
              Scaffold(
                backgroundColor: DesignColors.scaffold,
                body: SingleChildScrollView(child: e.value()),
              ),
              size: Size(w, e.key == 'draft' ? 1100 : 560),
              devicePixelRatio: 1,
              textScale: s,
            );
            await settlePhone(t);
            await t.pump(const Duration(milliseconds: 800));
            expect(t.takeException(), isNull);
            await shot(t, '${e.key}_${w.toInt()}_$s');
          } finally {
            debugDisableShadows = true;
          }
        });
      }
    }
  }
}
