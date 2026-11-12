import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/stay/models/stay_nearby_model.dart';
import 'package:bakhli/features/trip/widgets/trip_filter_chips.dart';
import 'package:bakhli/features/trip/widgets/trip_stay_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

StayNearbyModel _stay() => StayNearbyModel(
      id: 's1',
      name: 'Hill View',
      latitude: 1,
      longitude: 1,
      distanceKm: 2,
      isActive: true,
    );

void main() {
  testWidgets('stay row without photo shows neutral stay icon and call icon', (t) async {
    var called = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TripStayRow(stay: _stay(), onOpen: () {}, onCall: () => called++, onAsk: () {}),
        ),
      ),
    ));
    final stayIcons = t.widgetList<Image>(find.byType(Image)).where((i) {
      final p = i.image;
      return p is AssetImage && p.assetName == TravelIcon.stay;
    });
    expect(stayIcons.length, 1);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    await t.tap(find.byIcon(Icons.call_rounded));
    expect(called, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets('filter chips in a bottom bar Row do not fill the screen', (t) async {
    var taps = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: const SizedBox.expand(key: Key('body')),
        bottomNavigationBar: Row(
          children: [
            TripChipView(chip: TripFilterChip(label: 'Clear', selected: false, icon: Icons.filter_alt_off_rounded, onTap: () => taps++)),
          ],
        ),
      ),
    ));
    expect(t.getSize(find.byKey(const Key('body'))).height, greaterThan(400));
    await t.tap(find.text('Clear'));
    expect(taps, 1);
    expect(t.takeException(), isNull);
  });
}
