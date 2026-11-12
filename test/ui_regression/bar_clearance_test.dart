import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(double w, double scale, Widget Function(BuildContext) body) {
  return MediaQuery(
    data: MediaQueryData(size: Size(w, 700), textScaler: TextScaler.linear(scale)),
    child: MaterialApp(
      home: Scaffold(
        extendBody: true,
        bottomNavigationBar: const SizedBox(height: BarMetrics.barHeight),
        body: Builder(builder: body),
      ),
    ),
  );
}

void main() {
  for (final w in [300.0, 360.0, 560.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('last item clears the bar at $w dp, scale $scale', (tester) async {
        tester.view.physicalSize = Size(w, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_host(w, scale, (context) {
          return ListView(
            padding: EdgeInsets.only(bottom: BarMetrics.bodyBottomOf(context)),
            children: [
              for (var i = 0; i < 30; i++) SizedBox(height: 60, child: Text('row $i')),
              const SizedBox(key: Key('last'), height: 40),
            ],
          );
        }));
        await tester.drag(find.byType(ListView), const Offset(0, -5000));
        await tester.pumpAndSettle();
        final bottom = tester.getBottomLeft(find.byKey(const Key('last'))).dy;
        expect(bottom, lessThanOrEqualTo(700 - BarMetrics.barHeight));
      });

      testWidgets('pinned filter bar keeps its extent at $w dp, scale $scale', (tester) async {
        tester.view.physicalSize = Size(w, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_host(w, scale, (context) {
          return CustomScrollView(slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
            const PinnedFilterBar(
              extent: 90,
              padding: EdgeInsets.only(top: 30, bottom: 4),
              child: SizedBox(key: Key('chips'), height: 40),
            ),
            SliverList.builder(itemCount: 40, itemBuilder: (_, i) => SizedBox(height: 60, child: Text('r$i'))),
          ]);
        }));
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byKey(const Key('chips'))).dy, greaterThanOrEqualTo(30));
        expect(tester.getBottomLeft(find.byKey(const Key('chips'))).dy, lessThanOrEqualTo(90));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
