import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/buddy/shared/widgets/segment_tabs.dart';
import 'package:bakhli/features/buddy/shared/widgets/view_only_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double w = 320, double scale = 1.3}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(w, 640), textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: child),
      ),
    );

Iterable<Container> _dots(WidgetTester t) => t.widgetList<Container>(find.byType(Container)).where((c) => c.decoration is BoxDecoration && (c.decoration! as BoxDecoration).shape == BoxShape.circle);

void main() {
  const days = ['Day 1', 'Day 2', 'Day 3', 'Day 4', 'Day 5'];

  testWidgets('compact tabs do not overflow at 320 dp and text scale 1.3, dots render', (t) async {
    await t.pumpWidget(_host(SegmentTabs(labels: days, selected: 4, tone: ListingTone.teal, onTap: (_) {}, compact: true, dayDots: const [Colors.red, Colors.green, Colors.blue])));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(_dots(t).length, 3);
    expect(find.text('Day 5'), findsOneWidget);
  });

  testWidgets('compact tapping a tab reports its index', (t) async {
    var got = -1;
    await t.pumpWidget(_host(SegmentTabs(labels: days, selected: 0, tone: ListingTone.teal, onTap: (i) => got = i, compact: true)));
    await t.pumpAndSettle();
    await t.tap(find.text('Day 2'));
    expect(got, 1);
  });

  testWidgets('only the selected day dot gets the white ring', (t) async {
    await t.pumpWidget(_host(SegmentTabs(labels: const ['All', 'Day 1', 'Day 2'], selected: 1, tone: ListingTone.teal, onTap: (_) {}, dayDots: const [Colors.transparent, Colors.red, Colors.green]), w: 400, scale: 1));
    final rings = [for (final d in _dots(t)) (d.decoration! as BoxDecoration).boxShadow != null];
    expect(rings, [false, true, false]);
  });

  testWidgets('default tabs show no dots', (t) async {
    await t.pumpWidget(_host(SegmentTabs(labels: const ['A', 'B'], selected: 0, tone: ListingTone.teal, onTap: (_) {}), w: 400, scale: 1));
    expect(_dots(t), isEmpty);
  });

  testWidgets('view only chip is icon only below 360 and keeps the label for TalkBack', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(_host(const ViewOnlyChip(), w: 320, scale: 1));
    expect(find.text('View only'), findsNothing);
    expect(find.bySemanticsLabel('View only'), findsOneWidget);
    await t.pumpWidget(_host(const ViewOnlyChip(), w: 400, scale: 1));
    expect(find.text('View only'), findsOneWidget);
    h.dispose();
  });
}
