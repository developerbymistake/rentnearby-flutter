import 'dart:io';
import 'dart:ui' as ui;
import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ui_golden/golden_support.dart';

const _out = 'F:/Dhasu/UI_Template_resume/Repair/shots';

Future<void> _shot(WidgetTester t, String name) async {
  final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
  await t.runAsync(() async {
    final img = await ro.toImage(pixelRatio: 1);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    await File('$_out/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Widget _host(double w, double scale, Widget body) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'WorkSans'),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(w, 700),
          textScaler: TextScaler.linear(scale),
          padding: const EdgeInsets.only(top: 24),
        ),
        child: RepaintBoundary(key: const ValueKey('shot'), child: Scaffold(body: body)),
      ),
    );

void main() {
  testWidgets('header stays fixed and clear of trailing while scrolling', (t) async {
    await loadGoldenFonts();
    for (final w in [300.0, 360.0]) {
      t.view.physicalSize = Size(w, 700);
      t.view.devicePixelRatio = 1;
      final c = ScrollController();
      var taps = 0;
      await t.pumpWidget(_host(
        w,
        1.3,
        Builder(
          builder: (context) => Column(children: [
            ModuleHeader(
              title: 'Nainital and Bhimtal trip',
              subtitle: 'Day plan for 3 days',
              onBack: () {},
              trailing: [
                PillAction(label: 'Map', onTap: () => taps++),
                IconButton(onPressed: () => taps++, icon: const Icon(Icons.more_vert, color: Colors.white)),
              ],
            ),
            Expanded(
              child: ListView(controller: c, children: [
                for (var i = 0; i < 40; i++) SizedBox(height: 60, child: Text('row $i')),
              ]),
            ),
          ]),
        ),
      ));
      await t.pump(const Duration(seconds: 1));
      final h0 = t.getSize(find.byType(ModuleHeader)).height;
      final top0 = t.getTopLeft(find.byType(ModuleHeader));
      final title = t.getRect(find.text('Nainital and Bhimtal trip'));
      final map = t.getRect(find.text('Map'));
      expect(title.right, lessThanOrEqualTo(map.left), reason: 'title overlaps Map at $w');
      for (final o in [0.0, 80.0, 400.0, 1500.0]) {
        c.jumpTo(o);
        await t.pump();
        expect(t.getSize(find.byType(ModuleHeader)).height, h0);
        expect(t.getTopLeft(find.byType(ModuleHeader)), top0);
        if (o == 400) await _shot(t, 'shell_header_${w.toInt()}_scroll400');
      }
      await t.tap(find.text('Map'));
      await t.tap(find.byIcon(Icons.more_vert));
      expect(taps, 2);
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('buttons never ellipsize long labels', (t) async {
    await loadGoldenFonts();
    for (final w in [300.0, 360.0]) {
      t.view.physicalSize = Size(w, 700);
      t.view.devicePixelRatio = 1;
      await t.pumpWidget(_host(
        w,
        1.3,
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            ButtonPair(
              first: SecondaryButton(label: "I'll arrange it myself", onPressed: () {}),
              second: PrimaryButton(label: 'Help me find', onPressed: () {}),
              stackAbove: 5,
            ),
            const SizedBox(height: 12),
            PillAction(label: 'Show all nearby taxis', onTap: () {}, maxWidth: 120),
          ]),
        ),
      ));
      await t.pump(const Duration(seconds: 1));
      for (final txt in ["I'll arrange it myself", 'Show all nearby taxis']) {
        final ro = t.renderObject<RenderParagraph>(find.text(txt));
        expect(ro.didExceedMaxLines, isFalse, reason: txt);
        expect(ro.size.width, greaterThan(0));
      }
      expect(t.takeException(), isNull);
      await _shot(t, 'shell_buttons_${w.toInt()}');
    }
  });
}
