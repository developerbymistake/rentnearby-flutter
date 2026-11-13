import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/nearby/nearby_strings.dart';
import 'package:bakhli/features/nearby/widgets/nearby_centre_bar.dart';
import 'package:bakhli/features/nearby/widgets/nearby_featured_slot.dart';
import 'package:bakhli/features/nearby/widgets/nearby_header_strip.dart';
import 'package:bakhli/features/nearby/widgets/nearby_label_text.dart';
import 'package:bakhli/features/nearby/widgets/nearby_state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, double w, double scale, Widget child) async {
  t.view.physicalSize = Size(w, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(w, 800), textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  ));
  await t.pump();
}

void main() {
  const widths = [300.0, 360.0, 412.0, 560.0];
  const scales = [1.0, 1.3, 2.0];

  for (final w in widths) {
    for (final s in scales) {
      testWidgets('all pieces fit at ${w.toInt()} dp scale $s', (t) async {
        const far = NearbyDistance(km: 420, label: NearbyLabel.far, city: 'Haldwani', state: 'Uttarakhand');
        const header = NearbyHeader(
          farAway: true,
          centreCityName: 'Haldwani',
          centreCityKm: 12,
          citiesUnavailable: true,
        );
        await _pump(
          t,
          w,
          s,
          Column(children: [
            NearbyCentreBarView(text: NearbyStrings.usingPin('A very long place name, Uttarakhand'), hasPin: true, onSearch: () {}, onClear: () {}, onUseMyLocation: () {}),
            const NearbyHeaderStrip(header: header, hasPin: true),
            NearbyFeaturedSlot<String>(items: const ['a', 'b', 'c'], builder: (_, x) => Text('card $x')),
            const NearbyLabelText(distance: far),
            const NearbyLabelText(distance: far, taxi: true),
            const NearbyEmpty(title: NearbyStrings.routeEmptyTitle, body: NearbyStrings.routeEmptyBody),
            const NearbyThin(),
            NearbyError(onRetry: () {}),
          ]),
        );
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('featured slot shows heading, max 2, hidden when empty', (t) async {
    await _pump(t, 360, 1, NearbyFeaturedSlot<String>(items: const ['a', 'b', 'c'], builder: (_, x) => Text('card $x')));
    expect(find.text('Featured near you'), findsOneWidget);
    expect(find.text('card a'), findsOneWidget);
    expect(find.text('card b'), findsOneWidget);
    expect(find.text('card c'), findsNothing);
    await _pump(t, 360, 1, NearbyFeaturedSlot<String>(items: const [], builder: (_, x) => Text(x)));
    expect(find.text('Featured near you'), findsNothing);
  });

  testWidgets('label shows by-road caption only beyond 15 km', (t) async {
    await _pump(t, 360, 1, const NearbyLabelText(distance: NearbyDistance(km: 420, label: NearbyLabel.far, city: 'Haldwani', state: 'Uttarakhand')));
    expect(find.text('Haldwani, Uttarakhand. About 420 km away'), findsOneWidget);
    expect(find.text(NearbyStrings.byRoad), findsOneWidget);
    await _pump(t, 360, 1, const NearbyLabelText(distance: NearbyDistance(km: 10, label: NearbyLabel.inCity, city: 'Haldwani')));
    expect(find.text('In Haldwani'), findsOneWidget);
    expect(find.text(NearbyStrings.byRoad), findsNothing);
  });

  testWidgets('header strip never shows a live-in line', (t) async {
    await _pump(t, 360, 1, const NearbyHeaderStrip(header: NearbyHeader(farAway: true)));
    expect(find.textContaining('We are live in'), findsNothing);
    await _pump(t, 360, 1, const NearbyHeaderStrip(header: NearbyHeader(citiesUnavailable: true)));
    expect(find.textContaining('Cities are loading'), findsOneWidget);
  });

  testWidgets('centre bar buttons', (t) async {
    var cleared = 0, searched = 0;
    await _pump(t, 360, 1, NearbyCentreBarView(text: 'Showing near you', hasPin: false, onSearch: () => searched++, onClear: () => cleared++, onUseMyLocation: () {}));
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    await t.tap(find.text(NearbyStrings.searchAnyPlace));
    expect(searched, 1);
    await _pump(t, 360, 1, NearbyCentreBarView(text: 'Showing near Delhi', hasPin: true, onSearch: () {}, onClear: () => cleared++, onUseMyLocation: () {}));
    await t.tap(find.byIcon(Icons.close_rounded));
    expect(cleared, 1);
    expect(find.text(NearbyStrings.useMyLocation), findsOneWidget);
  });

  testWidgets('error retry', (t) async {
    var n = 0;
    await _pump(t, 360, 1, NearbyError(onRetry: () => n++));
    await t.tap(find.text(NearbyStrings.tryAgain));
    expect(n, 1);
  });

  testWidgets('centre bar far with GPS avoids near you wording', (t) async {
    await _pump(t, 360, 1, NearbyCentreBarView(text: NearbyStrings.usingGps, hasPin: false, far: true, onSearch: () {}, onClear: () {}, onUseMyLocation: () {}));
    expect(find.text('Showing near you'), findsNothing);
    expect(find.text(NearbyStrings.usingMyLocation), findsOneWidget);
  });
}
