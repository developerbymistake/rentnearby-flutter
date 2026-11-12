import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {required double width, required double height, double scale = 1.3}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, height), textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: Center(child: SizedBox(width: width, height: height, child: child))),
    ),
  );
}

void main() {
  testWidgets('PinnedFilterBar pins in a CustomScrollView at 300 dp, scale 1.3', (tester) async {
    final c = ScrollController();
    await tester.pumpWidget(_host(
      CustomScrollView(controller: c, slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 200)),
        PinnedFilterBar(child: const Row(children: [Expanded(child: Text('Filters'))])),
        SliverList(delegate: SliverChildBuilderDelegate((_, i) => SizedBox(height: 60, child: Text('row $i')), childCount: 40)),
      ]),
      width: 300,
      height: 600,
    ));
    expect(tester.takeException(), isNull);
    final base = tester.getTopLeft(find.text('Filters')).dy;
    c.jumpTo(800);
    await tester.pump();
    expect(tester.takeException(), isNull);
    final pinned = tester.getTopLeft(find.text('Filters')).dy;
    expect(pinned, lessThan(base));
    expect(pinned, lessThan(PinnedFilterBar.defaultExtent));
    expect(tester.getSize(find.byType(Divider)).width, 300);
  });

  testWidgets('TripKitEmpty in a 240 dp box at 300 dp, scale 1.3 does not overflow and keeps retry reachable', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(_host(
      TripKitEmpty(title: 'Nothing here yet', subtitle: 'Try again in a little while.', onRetry: () => tapped++),
      width: 300,
      height: 240,
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Retry'));
    await tester.pump();
    await tester.tap(find.text('Retry'));
    expect(tapped, 1);
  });

  testWidgets('TripKitEmpty in a tall box stays unscrolled and centred content fits', (tester) async {
    await tester.pumpWidget(_host(const TripKitEmpty(title: 'Nothing here yet'), width: 360, height: 700, scale: 1.0));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Nothing here yet'), findsOneWidget);
  });
}
