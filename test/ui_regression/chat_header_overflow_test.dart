import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/design/extra/chat_kit.dart';

void main() {
  testWidgets('ChatHeader has no overflow at 360dp and text scale 1.4', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
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
                child: const Text('Mark all read', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ]),
      ),
    ));
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
