import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/trip_strings_map_disc.dart';
import 'package:bakhli/features/trip/widgets/trip_map_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/real_phone.dart';

const _keys = ['disc-eye', 'disc-zoom-in', 'disc-zoom-out', 'disc-locate'];

Future<void> _pump(WidgetTester tester, Widget child, double width, double scale) => pumpPhone(
      tester,
      Scaffold(backgroundColor: const Color(0xFFEDE8DF), body: Center(child: child)),
      size: Size(width, 760),
      textScale: scale,
    );

void main() {
  for (final w in [320.0, 360.0, 411.0]) {
    for (final ts in [1.0, 1.3]) {
      final tag = '${w.toInt()} @ $ts';

      testWidgets('column: eye, zoom in, zoom out, locate top to bottom, 44 dp circles ($tag)', (tester) async {
        var located = 0;
        await _pump(tester, TripMapControls.column(onLocate: () => located++, onEye: (_) {}), w, ts);
        expect(tester.takeException(), isNull);
        final rects = [for (final k in _keys) tester.getRect(find.byKey(ValueKey(k)))];
        for (var i = 1; i < rects.length; i++) {
          expect(rects[i].top, greaterThan(rects[i - 1].bottom));
          expect(rects[i].left, closeTo(rects[0].left, 0.5));
        }
        expect(rects.first.width, closeTo(DS.s(TripMapControls.columnSize), 0.5));
        await tester.tap(find.byKey(const ValueKey('disc-locate')));
        expect(located, 1);
      });

      testWidgets('row inside 16 dp side padding: 4 circles with equal gaps; 3 when no eye ($tag)', (tester) async {
        Future<void> check(bool eye) async {
          await _pump(tester, Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: TripMapControls.row(showEye: eye, onEye: (_) {}, onLocate: () {})), w, ts);
          expect(tester.takeException(), isNull);
          final keys = eye ? _keys : _keys.sublist(1);
          final rects = [for (final k in keys) tester.getRect(find.byKey(ValueKey(k)))];
          final gaps = [rects.first.left - 16, for (var i = 1; i < rects.length; i++) rects[i].left - rects[i - 1].right, w - 16 - rects.last.right];
          for (final g in gaps) {
            expect(g, closeTo(gaps.first, 0.6));
            expect(g, greaterThan(0));
          }
          final size = DS.s(TripMapControls.rowSize);
          expect(gaps.first, closeTo((w - 32 - keys.length * size) / (keys.length + 1), 0.6));
          for (final r in rects) {
            expect(r.top, closeTo(rects.first.top, 0.5));
          }
        }

        await check(true);
        await check(false);
        expect(find.byKey(const ValueKey('disc-eye')), findsNothing);
      });
    }
  }

  testWidgets('eye: struck-through glyph when off, toggles to the opposite value, ring while loading', (tester) async {
    final calls = <bool>[];
    await _pump(tester, TripMapControls.column(eyeOn: false, onEye: calls.add), 360, 1);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(find.byKey(const ValueKey('disc-eye-ring')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('disc-eye')));
    expect(calls, [true]);
    await _pump(tester, TripMapControls.column(loading: true, onEye: calls.add), 360, 1);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byKey(const ValueKey('disc-eye-ring')), findsOneWidget);
  });

  testWidgets('screen-reader labels on every control', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, TripMapControls.column(onEye: (_) {}, onLocate: () {}), 360, 1);
    for (final l in [TripMapDiscStrings.semHidePlaces, TripMapDiscStrings.semZoomIn, TripMapDiscStrings.semZoomOut, TripMapDiscStrings.semLocate]) {
      expect(find.bySemanticsLabel(l), findsOneWidget, reason: l);
    }
    handle.dispose();
  });

  testWidgets('loading chip shows a spinner; the plain chip does not', (tester) async {
    await _pump(tester, const TripMapLoadingChip(text: TripMapDiscStrings.loadingPlaces, loading: true), 320, 1.3);
    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await _pump(tester, const TripMapLoadingChip(text: 'Offline. Your plan is saved on this phone.'), 320, 1.3);
    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
