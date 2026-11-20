import 'dart:io';
import 'dart:ui' as ui;

import 'package:bakhli/design/tokens/design_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'real_phone.dart';

const String buddyRenderDir = r'F:\Dhasu\Buddy_resume\render';
const Size buddyFrameSize = Size(392, 800);
const double buddyFrameDpr = 2;
const Key _frameKey = ValueKey('buddy_frame_root');

String frameFile(String frameId) => 's${frameId.replaceAll('.', '_')}';

void useBuddyRenderScale() {
  setUp(DS.applyApproved);
  tearDown(DS.debugReset);
}

Future<File> renderFrame(
  WidgetTester tester,
  String frameId,
  Widget screen, {
  Future<void> Function(WidgetTester tester)? arrange,
  Size size = buddyFrameSize,
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpPhone(tester, RepaintBoundary(key: _frameKey, child: screen), size: size, devicePixelRatio: buddyFrameDpr, textScale: textScale, toastHost: true);
  if (arrange != null) await arrange(tester);
  await settlePhone(tester);
  await settlePhone(tester);
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_frameKey));
  final file = File('$buddyRenderDir\\${frameFile(frameId)}.png');
  await tester.runAsync(() async {
    final ui.Image image = await _capture(tester, boundary);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
  return file;
}

// Captures the whole view (dialogs, sheets and overlays included) when the root layer is reachable.
Future<ui.Image> _capture(WidgetTester tester, RenderRepaintBoundary boundary) async {
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer;
  if (layer is OffsetLayer) {
    return layer.toImage(Offset.zero & (view.size * tester.view.devicePixelRatio), pixelRatio: 1);
  }
  return boundary.toImage(pixelRatio: tester.view.devicePixelRatio);
}
