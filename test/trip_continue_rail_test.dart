import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/widgets/trip_continue_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TripSummaryModel _trip(int n) => TripSummaryModel.fromJson({
      'id': 'trip-$n',
      'title': 'Trip number $n',
      'status': 'Planned',
      'cityName': 'Nainital',
      'dayCount': 2,
      'spotCount': 4,
      'category': 'attraction',
      'startDate': '2030-01-${10 + n}',
      'endDate': '2030-01-${12 + n}',
      'updatedAt': '2026-11-01T10:00:00Z',
      'progress': {'total': 4, 'done': 1, 'percent': 25},
    });

Future<void> _pump(WidgetTester t, double w) async {
  t.view.physicalSize = Size(w, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: TripContinueRail(trips: [_trip(1), _trip(2), _trip(3)], tone: ListingTone.cB, onOpen: (_) {}),
      ),
    ),
  ));
  await t.pump();
}

Rect _card(WidgetTester t, int n) {
  final r = t.getRect(find.byKey(ValueKey('continue-trip-$n')));
  return Rect.fromLTRB(r.left + 14, r.top, r.right - 14, r.bottom);
}

void main() {
  for (final w in [392.0, 360.0]) {
    testWidgets('rail inset 18 and gap 12 @${w.toInt()}', (t) async {
      await _pump(t, w);
      final a = _card(t, 1);
      final b = _card(t, 2);
      expect(a.left, 18);
      expect(a.width, TripContinueRail.cardWidth);
      expect(b.left - a.right, 12);
    });
  }

  test('attraction uses the teal gradient, others unchanged', () {
    final g = TripSpotLook.gradientOf('attraction');
    expect(g.colors, [ListingPalette.teal.g1, ListingPalette.teal.g2]);
    expect(TripSpotLook.gradientOf('temple').colors, isNot(g.colors));
    expect(TripSpotLook.gradientOf('lake').colors, isNot(g.colors));
    expect(TripSpotLook.gradientOf('other').colors, isNot(g.colors));
  });
}
