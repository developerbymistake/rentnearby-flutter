import 'dart:io';
import 'dart:ui' as ui;

import 'package:bakhli/design/tokens/design_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'owner_sizes.dart';
import 'real_phone.dart';

const String ownerRenderDir = r'F:\Dhasu\Buddy_resume\owner_render';
const String ownerFramesDir = r'F:\Dhasu\Buddy_resume\owner_frames';
const double ownerFrameWidth = 392;
const double ownerFrameDefaultHeight = 800;
const double ownerFrameDpr = 2;
const Key _frameKey = ValueKey('owner_frame_root');

void useOwnerRenderScale() {
  setUp(DS.applyApproved);
  tearDown(DS.debugReset);
}

final _phStyle = RegExp(r'''<div class="ph"(?:\s+style="([^"]*)")?''');
final _height = RegExp(r'height:\s*(\d+(?:\.\d+)?)px');
final _partLabel = RegExp(r'<em>([A-Z])</em>');

/// The phone height drawn in owner_frames/<id>.html (`.ph` style height, default 800). For a board, [part] (A, B, C...) picks the phone in order.
double ownerFrameHeight(String frameId, {String? part}) {
  final f = File('$ownerFramesDir\\$frameId.html');
  if (!f.existsSync()) return ownerFrameDefaultHeight;
  final html = f.readAsStringSync();
  final phones = _phStyle.allMatches(html).toList();
  if (phones.isEmpty) return ownerFrameDefaultHeight;
  var index = 0;
  if (part != null) {
    final labels = _partLabel.allMatches(html).map((m) => m.group(1)).toList();
    final at = labels.indexOf(part.toUpperCase());
    index = at >= 0 ? at : (part.toUpperCase().codeUnitAt(0) - 'A'.codeUnitAt(0));
    if (index < 0 || index >= phones.length) index = 0;
  }
  final style = phones[index].group(1) ?? '';
  final h = _height.firstMatch(style)?.group(1);
  return h == null ? ownerFrameDefaultHeight : double.tryParse(h) ?? ownerFrameDefaultHeight;
}

String ownerRenderName(String frameId, {String? part}) => part == null ? frameId : '${frameId}_${part.toLowerCase()}';

/// Pumps [screen] on a 392-wide phone at the frame's height and writes owner_render/<frameId>[_part].png (sheets and dialogs included).
Future<File> renderOwnerFrame(
  WidgetTester tester,
  String frameId,
  Widget screen, {
  String? part,
  Future<void> Function(WidgetTester tester)? arrange,
  double textScale = 1.0,
}) async {
  final size = Size(ownerFrameWidth, ownerFrameHeight(frameId, part: part));
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpPhone(tester, RepaintBoundary(key: _frameKey, child: screen), size: size, devicePixelRatio: ownerFrameDpr, textScale: textScale, toastHost: true);
  if (arrange != null) await arrange(tester);
  await settlePhone(tester);
  await settlePhone(tester);
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_frameKey));
  final file = File('$ownerRenderDir\\${ownerRenderName(frameId, part: part)}.png');
  await tester.runAsync(() async {
    final ui.Image image = await _capture(tester, boundary);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
  return file;
}

Future<ui.Image> _capture(WidgetTester tester, RenderRepaintBoundary boundary) async {
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer;
  if (layer is OffsetLayer) {
    return layer.toImage(Offset.zero & (view.size * tester.view.devicePixelRatio), pixelRatio: 1);
  }
  return boundary.toImage(pixelRatio: tester.view.devicePixelRatio);
}

/// FX-34: renders `owner_render/<frameId>.png` for the render compare, then runs the full device matrix
/// (sizes x text scale, plus the keyboard variant when [keyboard]) on the same screen.
void renderOwnerFrameMatrix(
  String frameId,
  Widget Function() builder, {
  String? part,
  bool keyboard = false,
  Future<void> Function(WidgetTester tester)? arrange,
  void Function()? setUpEach,
}) {
  testWidgets('render $frameId${part == null ? '' : ' $part'}', (tester) async {
    setUpEach?.call();
    final f = await renderOwnerFrame(tester, frameId, builder(), part: part, arrange: arrange);
    expect(f.existsSync(), isTrue);
  });
  testOwnerMatrix('$frameId matrix', builder, keyboard: keyboard, arrange: arrange, setUpEach: setUpEach);
}
