import 'package:bakhli/features/social/b/widgets/social_widgets_b.dart';
import 'package:bakhli/features/social/c/chat/who_can_send_sheet.dart';
import 'package:bakhli/features/social/c/social_strings_c.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'social_c_test_kit.dart';

void main() {
  useBuddyRenderScale();
  tearDown(Get.reset);

  const hostKey = ValueKey('who_can_send_host');

  Future<void> pumps(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<bool?> show(WidgetTester t, {required bool onlyOwner}) => WhoCanSendSheet.show(t.element(find.byKey(hostKey)), onlyOwner: onlyOwner);

  for (final w in socialWidths) {
    for (final s in socialScales) {
      testWidgets('shows both choices with the current one selected (${w.toInt()} x$s)', (t) async {
        await pumpSocial(t, const SizedBox(key: hostKey), width: w, scale: s);
        show(t, onlyOwner: true);
        await pumps(t);
        expect(find.text(SocialStringsC.whoCanSend), findsOneWidget);
        expect(find.text(SocialStringsC.whoCanSendLine), findsOneWidget);
        expect(find.text(SocialStringsC.everyone), findsOneWidget);
        expect(find.text(SocialStringsC.everyoneLine), findsOneWidget);
        expect(find.text(SocialStringsC.onlyMe), findsOneWidget);
        expect(find.text(SocialStringsC.onlyMeLine), findsOneWidget);
        RadioMark mark(Key k) => t.widget<RadioMark>(find.descendant(of: find.byKey(k), matching: find.byType(RadioMark)));
        expect(mark(WhoCanSendSheet.onlyMeKey).selected, isTrue);
        expect(mark(WhoCanSendSheet.everyoneKey).selected, isFalse);
        expect(t.takeException(), isNull);
        await disposeSocial(t);
      });
    }
  }

  testWidgets('tapping a row returns the pick', (t) async {
    await pumpSocial(t, const SizedBox(key: hostKey));
    final first = show(t, onlyOwner: false);
    await pumps(t);
    await t.tap(find.byKey(WhoCanSendSheet.onlyMeKey));
    await pumps(t);
    expect(await first, isTrue);

    final second = show(t, onlyOwner: true);
    await pumps(t);
    await t.tap(find.byKey(WhoCanSendSheet.everyoneKey));
    await pumps(t);
    expect(await second, isFalse);
    await disposeSocial(t);
  });
}
