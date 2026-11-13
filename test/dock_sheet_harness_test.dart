import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/design/design.dart';

const _bar = Key('bar');
const _btn = Key('btn');
const _btn2 = Key('btn2');

Widget _footer() => Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(key: _btn2, height: 52, width: double.infinity, child: GestureDetector(onTap: () {}, child: const ColoredBox(color: Colors.blue))),
      const SizedBox(height: 8),
      SizedBox(key: _btn, height: 52, width: double.infinity, child: GestureDetector(onTap: () {}, child: const ColoredBox(color: Colors.red))),
    ]);

Widget _sheet(String kind, SheetSize size) {
  final long = Column(children: List.generate(30, (i) => Text('row $i')));
  if (kind == 'frame') return SheetFrame(title: 'T', size: size, footer: _footer(), child: long);
  return Sheet3D(tone: ListingTone.indigo, title: 'T', size: size, footer: _footer(), child: long);
}

Future<void> _pump(WidgetTester t, {double kb = 0, double scale = 1, bool dock = true, double sys = 0, String kind = 'sheet', SheetSize size = SheetSize.hug}) async {
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1;
  t.view.viewInsets = FakeViewPadding(bottom: kb);
  t.view.padding = FakeViewPadding(bottom: dock ? sys : 24);
  t.view.viewPadding = FakeViewPadding(bottom: dock ? sys : 24);
  addTearDown(t.view.reset);
  final opener = Builder(builder: (ctx) => Center(child: ElevatedButton(onPressed: () => kind == 'frame' ? SheetFrame.show(ctx, builder: (_) => _sheet(kind, size)) : Sheet3D.show(ctx, builder: (_) => _sheet(kind, size)), child: const Text('open'))));
  final nested = Navigator(onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => opener));
  await t.pumpWidget(MaterialApp(
    builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: w!),
    home: dock
        ? Scaffold(
            resizeToAvoidBottomInset: false,
            extendBody: true,
            body: DockInsetScope(child: nested),
            bottomNavigationBar: const SizedBox(key: _bar, height: 80, child: ColoredBox(color: Colors.green)),
          )
        : Scaffold(resizeToAvoidBottomInset: false, body: opener),
  ));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

void main() {
  for (final kind in ['sheet', 'frame']) {
    for (final size in [SheetSize.hug, SheetSize.list]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets('dock $kind $size x$scale', (t) async {
          await _pump(t, kind: kind, size: size, scale: scale);
          final barTop = t.getTopLeft(find.byKey(_bar)).dy;
          expect(t.getBottomLeft(find.byKey(_btn)).dy, lessThanOrEqualTo(barTop));
          expect(t.getBottomLeft(find.byType(Material).last).dy, lessThanOrEqualTo(barTop + 0.5));
          expect(t.getTopLeft(find.byKey(_btn2)).dy, greaterThan(0));
          expect(find.byKey(_btn).hitTestable(), findsOneWidget);
          expect(find.byKey(_btn2).hitTestable(), findsOneWidget);
        });
      }
    }
  }

  testWidgets('dock with system inset: no double gap, no short gap', (t) async {
    await _pump(t, sys: 24, size: SheetSize.list);
    final barTop = t.getTopLeft(find.byKey(_bar)).dy;
    expect(t.getBottomLeft(find.byKey(_btn)).dy, lessThanOrEqualTo(barTop));
    expect(t.getBottomLeft(find.byKey(_btn)).dy, greaterThan(barTop - 40));
  });

  testWidgets('keyboard 300', (t) async {
    await _pump(t, kb: 300, size: SheetSize.list);
    expect(t.getBottomLeft(find.byKey(_btn)).dy, lessThanOrEqualTo(500));
    expect(t.getBottomLeft(find.byKey(_btn)).dy, greaterThan(500 - 80));
    expect(find.byKey(_btn).hitTestable(), findsOneWidget);
  });

  testWidgets('keyboard smaller than dock does not drop below bar', (t) async {
    await _pump(t, kb: 40, size: SheetSize.list);
    expect(t.getBottomLeft(find.byKey(_btn)).dy, lessThanOrEqualTo(t.getTopLeft(find.byKey(_bar)).dy));
  });

  testWidgets('root route without dock adds no extra gap', (t) async {
    await _pump(t, dock: false, size: SheetSize.list);
    final b = t.getBottomLeft(find.byKey(_btn)).dy;
    expect(b, lessThanOrEqualTo(800 - 24));
    expect(b, greaterThan(800 - 24 - 40));
  });

  testWidgets('root route with keyboard', (t) async {
    await _pump(t, dock: false, kb: 300, size: SheetSize.list);
    expect(t.getBottomLeft(find.byKey(_btn)).dy, lessThanOrEqualTo(500));
  });
}
