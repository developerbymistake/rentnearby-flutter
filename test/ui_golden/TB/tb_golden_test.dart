import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/stay/models/stay_nearby_model.dart';
import 'package:bakhli/features/trip/widgets/trip_sheet_frame.dart';
import 'package:bakhli/features/trip/widgets/trip_stay_row.dart';
import 'package:bakhli/features/trip/widgets/trip_status.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden_support.dart';

StayNearbyModel _stay({bool active = true, bool featured = false}) => StayNearbyModel(
      id: 's',
      name: 'Hillview Homestay near Mall Road',
      stayTypeName: 'Homestay',
      latitude: 0,
      longitude: 0,
      minPricePerNight: 1800,
      distanceKm: 1.4,
      isActive: active,
      isFeatured: featured,
      cityName: 'Nainital',
      districtName: 'Nainital',
      meals: 'Breakfast',
      checkInTime: '12:00',
      maxGuests: 4,
    );

void _golden(String name, Widget Function() build) {
  for (final scale in [1.0, 1.3]) {
    final s = scale == 1.0 ? '1.0' : '1.3';
    testWidgets('TB golden $name @$s', (t) async {
      await loadGoldenFonts();
      setGoldenView(t, const Size(360, 1000));
      await t.pumpWidget(goldenHost(build(), scale: scale));
      await settleGolden(t);
      expect(t.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('golden_root')), matchesGoldenFile('goldens/${name}_$s.png'));
    });
  }
}

void main() {
  _golden('stay_row', () => Column(children: [
        TripStayRow(stay: _stay(featured: true), onOpen: () {}, onCall: () {}, onAsk: () {}),
        TripStayRow(stay: _stay(active: false), onOpen: () {}),
        TripStayRow(stay: _stay(), status: TripDisplayStatus.asked, onOpen: () {}, onCall: () {}, onAsk: () {}),
        const TripStayRowSkeleton(),
      ]));
  _golden('kit_bits', () => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 72,
          decoration: BoxDecoration(gradient: KitTone.trip.gradient, borderRadius: CardRadius.header),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 12),
          child: TripHeaderAction(label: 'Map', icon: TravelIcon.map, onTap: () {}),
        ),
        const SizedBox(height: 12),
        const TripSurface(child: Text('Surface card')),
        const SizedBox(height: 12),
        TripButton(label: 'Send enquiry', onPressed: () {}),
        const SizedBox(height: 8),
        TripButton(label: 'Skip', outlined: true, neutral: true, onPressed: () {}),
        const SizedBox(height: 8),
        TripButton(label: 'Busy', onPressed: () {}, loading: true),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          TripChoiceChip(label: 'Day 1', selected: true, onTap: () {}),
          TripChoiceChip(label: 'Day 2', selected: false, onTap: () {}),
          TripActionChip(label: 'Call', icon: Icons.call_rounded, onTap: () {}),
        ]),
        const SizedBox(height: 12),
        const TripNote(iconAsset: TravelIcon.pin, child: Text('Tap and hold to drag')),
        const SizedBox(height: 300, child: TripEmpty(title: 'No replies yet', subtitle: 'Hosts reply here', asset: TravelIcon.place, onRetry: _noop, retryLabel: 'Refresh')),
      ]));
  _golden('sheet', () => SizedBox(
        height: 520,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: TripSheetFrame(title: 'Send enquiry', description: 'Hillview Homestay', footer: PrimaryButton(label: 'Send', onPressed: _noop), children: [
            const TripNote(iconAsset: TravelIcon.calendar, child: Text('2 nights, 2 guests')),
            TripButton(label: 'Change dates', outlined: true, onPressed: () {}),
          ]),
        ),
      ));
}

void _noop() {}
