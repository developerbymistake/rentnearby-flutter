import 'package:bakhli/design/design.dart';
import 'package:bakhli/navigation/bar_overlap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _tripH = 64.0;

Widget _shell(double w, double scale, bool trip, Widget Function(BuildContext) body) {
  return MediaQuery(
    data: MediaQueryData(
      size: Size(w, 700),
      textScaler: TextScaler.linear(scale),
      padding: const EdgeInsets.only(top: 24, bottom: 20),
      viewPadding: const EdgeInsets.only(top: 24, bottom: 20),
    ),
    child: MaterialApp(
      home: Scaffold(
        extendBody: true,
        resizeToAvoidBottomInset: false,
        body: Navigator(
          onGenerateRoute: (_) => PageRouteBuilder(
            pageBuilder: (_, _, _) => Scaffold(body: Builder(builder: body)),
          ),
        ),
        bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
          if (trip) const BarOverlap(overlap: BarMetrics.centreOverflow, child: SizedBox(height: _tripH, width: double.infinity)),
          const SizedBox(key: Key('nav'), height: BarMetrics.boxHeight + 20),
        ]),
      ),
    ),
  );
}

void main() {
  for (final w in [300.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.3]) {
      for (final trip in [false, true]) {
        testWidgets('last row clears compass and trip bar at $w dp, scale $scale, trip $trip', (tester) async {
          tester.view.physicalSize = Size(w, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(_shell(w, scale, trip, (context) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(bottom: BarMetrics.bodyBottomOf(context)),
              child: Column(children: [
                for (var i = 0; i < 30; i++) SizedBox(height: 60, child: Text('row $i')),
                const SizedBox(key: Key('last'), height: 40, width: double.infinity),
              ]),
            );
          }));
          await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -5000));
          await tester.pumpAndSettle();
          final bottom = tester.getBottomLeft(find.byKey(const Key('last'))).dy;
          final compassTop = 700 - 20 - BarMetrics.boxHeight;
          final tripTop = compassTop - (trip ? _tripH - 38 : 0);
          expect(bottom, lessThanOrEqualTo(tripTop));
        });
      }
    }
  }
}
