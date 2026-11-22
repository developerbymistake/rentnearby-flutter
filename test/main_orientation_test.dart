import 'package:bakhli/config/app_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FX-22 phones (shortest side below 600) are portrait only; tablets rotate freely', () {
    expect(AppFrame.orientationsFor(320), [DeviceOrientation.portraitUp]);
    expect(AppFrame.orientationsFor(411), [DeviceOrientation.portraitUp]);
    expect(AppFrame.orientationsFor(599.9), [DeviceOrientation.portraitUp]);
    expect(AppFrame.orientationsFor(600), isEmpty);
    expect(AppFrame.orientationsFor(820), isEmpty);
  });

  test('FX-22 a view size not known yet (0x0 at start) is not read as a phone', () {
    expect(AppFrame.shortestSideOf(Size.zero, 3), isNull);
    expect(AppFrame.shortestSideOf(const Size(1080, 2400), 0), isNull);
    expect(AppFrame.shortestSideOf(const Size(1080, 2400), 3), 360);
    expect(AppFrame.shortestSideOf(const Size(2560, 1600), 2), 800);
  });

  Future<Size> contentSize(WidgetTester t, Size screen) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = screen;
    addTearDown(t.view.reset);
    late Size seen;
    late Size box;
    await t.pumpWidget(MaterialApp(
      builder: (context, child) => Builder(builder: (context) => AppFrame.capWidth(context, child!)),
      home: Builder(builder: (context) {
        seen = MediaQuery.sizeOf(context);
        return LayoutBuilder(builder: (_, c) {
          box = Size(c.maxWidth, c.maxHeight);
          return const SizedBox.expand();
        });
      }),
    ));
    expect(seen.width, box.width, reason: 'MediaQuery width matches the capped box');
    return box;
  }

  testWidgets('FX-33 tablets (820 wide) get a centred 640 wide column; phones are untouched', (t) async {
    expect((await contentSize(t, const Size(820, 1180))).width, 640);
    expect((await contentSize(t, const Size(600, 960))).width, 600);
    expect((await contentSize(t, const Size(411, 891))).width, 411);
  });
}
