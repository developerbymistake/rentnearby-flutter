import 'package:bakhli/config/app_constants.dart';
import 'package:bakhli/features/nearby/nearby_strings.dart';
import 'package:bakhli/features/nearby/widgets/place_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, double w, double scale, Widget child) async {
  t.view.physicalSize = Size(w, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(w, 800), textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    ),
  ));
  await t.pump();
}

void main() {
  test('radius chips are 1, 6, 12, 20 and default is 12', () {
    expect(AppConstants.radiusOptions, [1.0, 6.0, 12.0, 20.0]);
    expect(AppConstants.defaultRadiusKm, 12.0);
    expect(AppConstants.radiusOptions.contains(AppConstants.defaultRadiusKm), isTrue);
  });

  for (final w in [300.0, 360.0]) {
    for (final compact in [true, false]) {
      testWidgets('empty bar shows hint and opens search at $w compact $compact', (t) async {
        var taps = 0;
        await _pump(t, w, 1.3, PlaceSearchBarView(compact: compact, onTap: () => taps++, onClear: () {}));
        expect(find.text(NearbyStrings.searchPlaceHint), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsNothing);
        await t.tap(find.text(NearbyStrings.searchPlaceHint));
        expect(taps, 1);
        expect(t.takeException(), isNull);
      });

      testWidgets('chosen place shows name and x clears at $w compact $compact', (t) async {
        var cleared = 0;
        await _pump(t, w, 2.0, PlaceSearchBarView(compact: compact, label: 'Haldwani, Uttarakhand, India', onTap: () {}, onClear: () => cleared++));
        expect(find.text('Haldwani, Uttarakhand, India'), findsOneWidget);
        await t.tap(find.byIcon(Icons.close_rounded));
        expect(cleared, 1);
        expect(t.getSize(find.byIcon(Icons.close_rounded).first).width, lessThanOrEqualTo(44));
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('busy state disables tap and hides x', (t) async {
    var taps = 0;
    await _pump(t, 360, 1.0, PlaceSearchBarView(busy: true, label: 'Nainital', onTap: () => taps++, onClear: () {}));
    await t.tap(find.text('Nainital'), warnIfMissed: false);
    expect(taps, 0);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });
}
