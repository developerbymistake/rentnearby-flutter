import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:bakhli/features/social/shared/widgets/follow_limit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'social_test_support.dart';

Widget _host() => Scaffold(
      body: Builder(
        builder: (c) => Center(
          child: TextButton(onPressed: () => FollowLimitSheet.show(c), child: const Text('open')),
        ),
      ),
    );

void main() {
  useBuddyRenderScale();
  tearDown(Get.reset);

  test('copy is the D3 text', () {
    expect(SocialStrings.tryLaterTitle, 'Try again later');
    expect(SocialStrings.tryLaterLine, 'We limit some actions to keep Bakhli safe.');
    expect(SocialStrings.ok, 'OK');
  });

  for (final size in socialSizes) {
    for (final scale in socialScales) {
      testWidgets('sheet shows title, line and OK only, no number or date, OK closes ($size, $scale)', (t) async {
        await pumpSocial(t, _host(), size: size, textScale: scale);
        await t.tap(find.text('open'));
        await settle(t);
        final sheet = find.byKey(FollowLimitSheet.sheetKey);
        expect(sheet, findsOneWidget);
        expect(t.widget<Sheet3D>(sheet).art, ListingArt.alarmClock);
        expect(find.text(SocialStrings.tryLaterTitle), findsOneWidget);
        expect(find.text(SocialStrings.tryLaterLine), findsOneWidget);
        expect(find.descendant(of: sheet, matching: find.byType(GradientPillButton)), findsOneWidget);
        final texts = t.widgetList<Text>(find.descendant(of: sheet, matching: find.byType(Text))).map((w) => w.data ?? w.textSpan?.toPlainText() ?? '');
        expect(texts.where((x) => RegExp(r'\d').hasMatch(x)), isEmpty);
        expect(t.takeException(), isNull);
        await t.tap(find.byKey(FollowLimitSheet.okKey));
        await settle(t);
        expect(sheet, findsNothing);
        await drain(t);
      });
    }
  }
}
