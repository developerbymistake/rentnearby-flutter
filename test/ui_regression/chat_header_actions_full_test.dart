import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/design/extra/chat_kit.dart';

void main() {
  testWidgets('Mark all read is not ellipsized at 360dp, text scale 1.0', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          ChatHeader(
            onBack: () {},
            title: ChatHeader.titleText('Notifications', size: 20),
            trailingAsset: NotificationLook.bell,
            actions: [
              TextButton(
                onPressed: () {},
                child: const Text('Mark all read', key: Key('mar'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 6.5)),
              ),
            ],
          ),
        ]),
      ),
    ));
    await t.pump();
    // Ahem glyphs are 1em wide; 6.5 gives about the width of the real 12.5px label (~85px).
    final text = t.renderObject<RenderParagraph>(find.byKey(const Key('mar')));
    expect(text.didExceedMaxLines, isFalse);
    expect(text.size.width, greaterThanOrEqualTo(text.getMaxIntrinsicWidth(double.infinity) - 0.5));
    expect(t.takeException(), isNull);
  });
}
