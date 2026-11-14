import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/template_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  test('stagger gives every item a full 350 ms and never exceeds 1', () {
    for (var n = 1; n <= 12; n++) {
      final total = KitMotion.staggerTotalMs(n);
      for (var i = 0; i < n; i++) {
        final iv = KitMotion.staggerInterval(i, n);
        expect(iv.end <= 1.0, isTrue);
        expect(((iv.end - iv.begin) * total).round(), 350);
      }
    }
  });

  testWidgets('PressScale shrinks on press and returns', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Center(
        child: PressScale(
          child: GestureDetector(onTap: () {}, child: ColoredBox(color: DesignColors.primary, key: ValueKey('p'), child: SizedBox(width: 100, height: 100))),
        ),
      ),
    ));
    final g = await t.startGesture(t.getCenter(find.byKey(const ValueKey('p'))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 120));
    expect(t.getSize(find.byKey(const ValueKey('p'))).width, 100);
    final scaled = t.widget<ScaleTransition>(find.descendant(of: find.byType(PressScale), matching: find.byType(ScaleTransition)));
    expect(scaled.scale.value, closeTo(0.97, 0.001));
    await g.up();
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    final back = t.widget<ScaleTransition>(find.descendant(of: find.byType(PressScale), matching: find.byType(ScaleTransition)));
    expect(back.scale.value, closeTo(1.0, 0.001));
  });

  testWidgets('TabEntrance rests visible and replays when its tab opens', (t) async {
    final src = 0.obs;
    await t.pumpWidget(MaterialApp(
      home: TabEntrance(tab: 2, source: src, child: const SizedBox(key: ValueKey('c'), width: 10, height: 10)),
    ));
    double opacity() => t.widget<Opacity>(find.ancestor(of: find.byKey(const ValueKey('c')), matching: find.byType(Opacity)).first).opacity;
    expect(opacity(), 1);
    src.value = 2;
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    expect(opacity(), lessThan(1));
    await t.pump(const Duration(milliseconds: 400));
    expect(opacity(), 1);
  });

  testWidgets('StaggerHost ends with every item fully visible', (t) async {
    await t.pumpWidget(MaterialApp(
      home: StaggerColumn(children: [for (var i = 0; i < 9; i++) Text('item $i')]),
    ));
    await t.pump(const Duration(milliseconds: 1200));
    for (final o in t.widgetList<Opacity>(find.byType(Opacity))) {
      expect(o.opacity, 1);
    }
  });

  testWidgets('bottom bar: centre button top edge is tappable, bar box is 110 + inset', (t) async {
    int? tapped;
    const inset = 20.0;
    await t.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(360, 760)),
        child: Scaffold(
          extendBody: true,
          body: const SizedBox.expand(),
          bottomNavigationBar: TemplateBottomBar(
            bottomInset: inset,
            selectedIndex: 0,
            onTap: (i) => tapped = i,
            items: const [
              TemplateNavItem(index: 0, label: 'A', image: ListingArt.stay),
              TemplateNavItem(index: 1, label: 'B', image: TravelIcon.taxi),
              TemplateNavItem(index: 2, label: 'C', image: TravelIcon.route, center: true),
              TemplateNavItem(index: 3, label: 'D', image: TravelIcon.map),
              TemplateNavItem(index: 4, label: 'E', image: TravelIcon.chat),
            ],
          ),
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 1200));
    final box = t.getRect(find.byType(TemplateBottomBar));
    expect(box.height, BarMetrics.boxHeightFor(inset));
    await t.tapAt(Offset(box.center.dx, box.top + 14));
    expect(tapped, 2);
  });

  testWidgets('template calendar picks a range and applies', (t) async {
    t.view.physicalSize = const Size(400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    DateTimeRange? out;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async => out = await TemplateCalendarPopup.pickRange(ctx,
              first: DateTime(2030, 5, 1), last: DateTime(2030, 5, 31), initialStart: DateTime(2030, 5, 3)),
          child: const Text('open'),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('May, 2030'), findsOneWidget);
    await t.tap(find.text('3').first);
    await t.pump();
    await t.tap(find.text('3').first);
    await t.pump();
    await t.tap(find.text('10').first);
    await t.pump();
    await t.tap(find.text('Apply'));
    await t.pump(const Duration(milliseconds: 500));
    expect(out?.start, DateTime(2030, 5, 3));
    expect(out?.end, DateTime(2030, 5, 10));
  });
}
