import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
import 'package:bakhli/design/extra/stay_setup_kit.dart';
import 'package:bakhli/design/extra/taxi_setup_kit.dart';
import 'package:bakhli/design/extra/trip_pill_button.dart';

Future<void> _pumpBar(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(400, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      bottomNavigationBar: Row(children: [child]),
      body: const SizedBox.expand(key: Key('body')),
    ),
  ));
}

void _expectBodyKept(WidgetTester tester, Finder bar) {
  expect(tester.takeException(), isNull);
  expect(tester.getSize(find.byKey(const Key('body'))).height, greaterThan(500));
  expect(tester.getSize(bar).height, lessThan(100));
}

void main() {
  group('Center in loose-bounded min-height boxes', () {
    testWidgets('TripPillButton in a bottom bar row', (tester) async {
      var taps = 0;
      await _pumpBar(tester, TripPillButton(label: 'Call', onTap: () => taps++, accent: DesignColors.primary));
      _expectBodyKept(tester, find.byType(TripPillButton));
      await tester.tap(find.text('Call'));
      expect(taps, 1);
    });

    testWidgets('TaxiPill in a bottom bar row', (tester) async {
      var taps = 0;
      await _pumpBar(tester, TaxiPill(label: 'Confirm', onTap: () => taps++));
      _expectBodyKept(tester, find.byType(TaxiPill));
      await tester.tap(find.text('Confirm'));
      expect(taps, 1);
    });

    testWidgets('SetupPill in a bottom bar row', (tester) async {
      var taps = 0;
      await _pumpBar(tester, SetupPill(label: 'Confirm', onTap: () => taps++));
      _expectBodyKept(tester, find.byType(SetupPill));
      await tester.tap(find.text('Confirm'));
      expect(taps, 1);
    });

    testWidgets('RepliesDialogButton keeps its own size in a loose box', (tester) async {
      var taps = 0;
      await _pumpBar(tester, RepliesDialogButton(label: 'Delete', onPressed: () => taps++));
      _expectBodyKept(tester, find.byType(RepliesDialogButton));
      expect(tester.getSize(find.byType(RepliesDialogButton)).width, lessThan(200));
      await tester.tap(find.text('Delete'));
      expect(taps, 1);
    });

    testWidgets('RepliesDialogButton in a Stack child does not fill the stack', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(children: [
            RepliesDialogButton(label: 'Delete', onPressed: () {}),
          ]),
        ),
      ));
      expect(tester.takeException(), isNull);
      final s = tester.getSize(find.byType(RepliesDialogButton));
      expect(s.height, lessThan(100));
      expect(s.width, lessThan(200));
    });
  });

  group('Entrance animations', () {
    testWidgets('RepliesEntrance content ends fully visible', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: RepliesEntrance(child: Text('hello'))),
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      final fade = tester.widgetList<FadeTransition>(find.ancestor(of: find.text('hello'), matching: find.byType(FadeTransition)));
      for (final f in fade) {
        expect(f.opacity.value, 1.0);
      }
    });
  });

  group('Bottom bars and input decorations', () {
    testWidgets('min-size Column bottom bar keeps the body', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: const [
            SizedBox(height: 56, child: Center(child: Text('bar'))),
          ]),
          body: const SizedBox.expand(key: Key('body')),
        ),
      ));
      expect(tester.getSize(find.byKey(const Key('body'))).height, 644);
    });

    testWidgets('text field with a boxed prefix stays one line tall', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            TextFormField(
              decoration: InputDecoration(
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: const Text('+91'),
                ),
                hintText: 'Enter mobile number',
              ),
            ),
          ]),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TextFormField)).height, lessThan(100));
    });
  });
}
