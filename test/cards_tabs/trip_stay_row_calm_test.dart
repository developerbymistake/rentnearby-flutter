import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/stay_photo_card.dart';
import 'package:bakhli/features/stay/models/stay_nearby_model.dart';
import 'package:bakhli/features/trip/trip_strings_v2_find.dart';
import 'package:bakhli/features/trip/utils/trip_stay_rank.dart';
import 'package:bakhli/features/trip/widgets/trip_status.dart';
import 'package:bakhli/features/trip/widgets/trip_stay_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/real_phone.dart';

StayNearbyModel _stay(String id, {int base = 1800, int? dated, bool full = false, bool active = true, bool featured = false, String? url}) =>
    StayNearbyModel.fromJson({
      'id': id,
      'name': 'Stay $id',
      'stayTypeName': 'Homestay',
      'latitude': 29.39,
      'longitude': 79.45,
      'minPricePerNight': base,
      'distanceKm': 0.4,
      'isActive': active,
      'isFeatured': featured,
      'cityName': 'Mallital',
      'bestRoomName': 'Double room',
      'thumbnailUrl': ?url,
      'datesPerNight': ?dated,
      if (dated != null) 'datesTotal': dated * 3,
      if (dated != null) 'basePerNight': base,
      if (dated != null && dated < base) 'priceChip': {'kind': 'Off', 'text': '15% off'},
      'fullOnDates': full,
    });

Future<void> _pump(WidgetTester t, Widget row, {double width = 360, double scale = 1.0}) async {
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(t, Scaffold(body: SingleChildScrollView(child: row)), size: Size(width, 1000), textScale: scale);
}

CalmPillButton _pill(WidgetTester t, String label) =>
    t.widget<CalmPillButton>(find.ancestor(of: find.text(label), matching: find.byType(CalmPillButton)));

void main() {
  testWidgets('shortlisted = selected gradient pill; not shortlisted = Shortlist', (t) async {
    await _pump(t, TripStayRow(stay: _stay('a'), onOpen: () {}, onCall: () {}, onShortlist: () {}, shortlisted: true));
    expect(find.text('Shortlisted'), findsOneWidget);
    expect(_pill(t, 'Shortlisted').action.selected, isTrue);
    expect(_pill(t, 'Shortlisted').action.kind, CalmActionKind.primary);
    final sem = t.widget<Semantics>(find.descendant(of: find.byType(CalmPillButton).last, matching: find.byType(Semantics)).first);
    expect(sem.properties.selected, isTrue);
    await _pump(t, TripStayRow(stay: _stay('a'), onOpen: () {}, onCall: () {}, onShortlist: () {}));
    expect(find.text('Shortlist'), findsOneWidget);
    expect(_pill(t, 'Shortlist').action.selected, isFalse);
  });

  testWidgets('lower dated price: new, struck old, tag under the block, caption From', (t) async {
    await _pump(t, TripStayRow(stay: _stay('a', dated: 1530), onOpen: () {}, onCall: () {}, onShortlist: () {}));
    expect(find.text('₹1,530'), findsOneWidget);
    expect(t.widget<Text>(find.text('₹1,800')).style?.decoration, TextDecoration.lineThrough);
    expect(find.descendant(of: find.byType(CalmPriceBlock), matching: find.text('15% off')), findsOneWidget);
    expect(find.descendant(of: find.byType(Wrap), matching: find.text('15% off')), findsNothing);
    expect(find.text('From'), findsOneWidget);
  });

  testWidgets('higher dated price: price only, no strike, no tag', (t) async {
    await _pump(t, TripStayRow(stay: _stay('a', base: 3000, dated: 3600), onOpen: () {}, onCall: () {}, onShortlist: () {}));
    expect(find.text('₹3,600'), findsOneWidget);
    expect(find.text('₹3,000'), findsNothing);
    expect(find.textContaining('% off'), findsNothing);
  });

  testWidgets('full on dates: grey chip first, disabled Full pill does nothing', (t) async {
    var taps = 0;
    await _pump(t, TripStayRow(stay: _stay('a', base: 650, full: true), onOpen: () {}, onCall: () {}, onShortlist: () => taps++));
    expect(find.text('Full on your dates'), findsOneWidget);
    final chip = t.widget<CalmChip>(find.ancestor(of: find.text('Full on your dates'), matching: find.byType(CalmChip)));
    expect(chip.kind, CalmChipKind.muted);
    expect(t.getTopLeft(find.text('Full on your dates')).dx, lessThan(t.getTopLeft(find.text('Homestay')).dx));
    expect(_pill(t, 'Full').action.kind, CalmActionKind.disabled);
    await t.tap(find.text('Full'));
    await t.pump(const Duration(milliseconds: 300));
    expect(taps, 0);
  });

  testWidgets('YOUR GROUP never shows (fits true, false, unknown)', (t) async {
    for (final fits in <bool?>[true, false, null]) {
      await _pump(
        t,
        TripStayRow(
          stay: _stay('a', dated: 1530),
          onOpen: () {},
          onCall: () {},
          onShortlist: () {},
          fit: TripStayFit(id: 'a', fits: fits, nearestKm: 0.4, detourKm: 0),
        ),
      );
      expect(find.text('YOUR GROUP'), findsNothing, reason: '$fits');
      expect(find.text('From'), findsOneWidget, reason: '$fits');
    }
  });

  testWidgets('asked = disabled Asked; with chat = Open chat', (t) async {
    await _pump(t, TripStayRow(stay: _stay('a'), onOpen: () {}, onCall: () {}, status: TripDisplayStatus.asked));
    final second = t.widget<CalmPillButton>(find.byType(CalmPillButton).last).action;
    expect((second.kind, second.label), (CalmActionKind.disabled, TripStringsV2Find.asked));
    await _pump(t, TripStayRow(stay: _stay('a'), onOpen: () {}, onCall: () {}, status: TripDisplayStatus.asked, onOpenChat: () {}));
    expect(find.text('Open chat'), findsOneWidget);
  });

  testWidgets('paused: dimmed, no buttons', (t) async {
    await _pump(t, TripStayRow(stay: _stay('a', active: false), onOpen: () {}, onCall: () {}, onShortlist: () {}));
    expect(t.widget<StayPhotoCard>(find.byType(StayPhotoCard)).dimmed, isTrue);
    expect(find.byType(CalmPillButton), findsNothing);
    expect(find.byType(Opacity), findsWidgets);
  });

  testWidgets('distance text, Call, no WhatsApp; featured pill on the photo', (t) async {
    await _pump(t, TripStayRow(stay: _stay('a', featured: true), onOpen: () {}, onCall: () {}, onShortlist: () {}));
    expect(find.text('0.4 km away'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.byKey(StayPhotoCard.featuredKey), findsOneWidget);
    expect(find.text('FOR STAY'), findsOneWidget);
  });

  for (final w in [320.0, 360.0, 411.0]) {
    for (final s in [1.0, 1.3]) {
      testWidgets('rows 1, 2 and many fit at ${w.toInt()} @$s', (t) async {
        final stays = [
          _stay('a', dated: 1530, url: 'https://example.com/a.jpg'),
          _stay('b', base: 3000, dated: 3600),
          _stay('c', base: 650, full: true),
          _stay('d', active: false),
        ];
        for (final n in [1, 2, stays.length * 3]) {
          await _pump(
            t,
            Column(children: [
              for (var i = 0; i < n; i++)
                TripStayRow(
                  key: ValueKey(i),
                  stay: stays[i % stays.length],
                  index: i,
                  onOpen: () {},
                  onCall: () {},
                  onShortlist: () {},
                  shortlisted: i.isEven,
                ),
            ]),
            width: w,
            scale: s,
          );
          expect(t.takeException(), isNull, reason: '$n rows');
        }
      });
    }
  }
}
