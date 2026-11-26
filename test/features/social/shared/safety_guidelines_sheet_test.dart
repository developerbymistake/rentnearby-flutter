import 'package:bakhli/features/social/shared/social_safety_strings.dart';
import 'package:bakhli/features/social/shared/widgets/safety_guidelines_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'social_test_support.dart';

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(Get.reset);
  tearDown(Get.reset);

  bool? result;
  var acceptCalls = 0;

  Future<void> openSheet(WidgetTester t, {String first = 'Kavya', bool group = false, bool readOnly = false, Future<String?> Function()? accept, Size size = const Size(392, 1400), double scale = 1.0}) async {
    result = null;
    acceptCalls = 0;
    await pumpSocial(
      t,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const ValueKey('open'),
              onPressed: () async {
                if (readOnly) {
                  await SafetyGuidelinesSheet.showReadOnly(context);
                } else {
                  result = await SafetyGuidelinesSheet.ask(context, firstName: first, group: group, accept: accept ?? () async {
                    acceptCalls++;
                    return null;
                  });
                }
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
      size: size,
      textScale: scale,
    );
    await t.tap(find.byKey(const ValueKey('open')));
    await settle(t);
  }

  testWidgets('direct chat: title with the first name, intro, the five rows with exact copy, footer, Understood', (t) async {
    await openSheet(t);
    expect(find.text('Keep it safe with Kavya'), findsOneWidget);
    expect(find.text('Every buddy agrees to these.'), findsOneWidget);
    for (final r in SafetyGuidelinesSheet.rows) {
      expect(find.text(r.title), findsOneWidget, reason: r.title);
      expect(find.text(r.line), findsOneWidget, reason: r.line);
    }
    expect(SafetyGuidelinesSheet.rows, hasLength(5));
    expect(find.text('Never send or ask for money'), findsOneWidget);
    expect(find.text('No transfers, deposits or booking fees in chat. Split costs in person.'), findsOneWidget);
    expect(find.text('Passport, bank, home address, OTPs: never in chat. Phone numbers, emails and links are hidden here.'), findsOneWidget);
    expect(find.text('Messages disappear after 24 hours'), findsOneWidget);
    expect(find.text('Report a chat from the menu (⋮).'), findsOneWidget);
    expect(find.byKey(SafetyGuidelinesSheet.understoodKey), findsOneWidget);
    expect(find.text('Understood'), findsOneWidget);
    expect(find.byKey(SafetyGuidelinesSheet.closeKey), findsNothing);
    await drain(t);
  });

  testWidgets('group chat title and a missing name never print the word null', (t) async {
    await openSheet(t, group: true);
    expect(find.text('Keep your trip chat safe'), findsOneWidget);
    expect(find.text('Keep it safe with Kavya'), findsNothing);
    await drain(t);
    expect(SocialSafetyStrings.title(''), 'Keep it safe');
    expect(SocialSafetyStrings.title('  Meera '), 'Keep it safe with Meera');
  });

  testWidgets('Understood saves on the server then closes with true', (t) async {
    await openSheet(t);
    await t.tap(find.byKey(SafetyGuidelinesSheet.understoodKey));
    await settle(t);
    expect(acceptCalls, 1);
    expect(result, isTrue);
    expect(find.byKey(SafetyGuidelinesSheet.understoodKey), findsNothing);
    await drain(t);
  });

  testWidgets('a refused save keeps the sheet open and shows the error; nothing is accepted', (t) async {
    await openSheet(t, accept: () async => 'You are offline.');
    await t.tap(find.byKey(SafetyGuidelinesSheet.understoodKey));
    await settle(t);
    expect(result, isNull);
    expect(find.byKey(SafetyGuidelinesSheet.understoodKey), findsOneWidget);
    expect(find.text('You are offline.'), findsOneWidget);
    await drain(t);
  });

  testWidgets('closing the sheet without Understood returns false', (t) async {
    await openSheet(t);
    await t.tapAt(const Offset(10, 10));
    await settle(t);
    expect(result, isFalse);
    expect(acceptCalls, 0);
    await drain(t);
  });

  testWidgets('read-only copy: same rows, only Close, no Understood, nothing is saved', (t) async {
    await openSheet(t, readOnly: true);
    expect(find.text(SocialSafetyStrings.tipsRow), findsOneWidget);
    for (final r in SafetyGuidelinesSheet.rows) {
      expect(find.text(r.title), findsOneWidget);
    }
    expect(find.byKey(SafetyGuidelinesSheet.understoodKey), findsNothing);
    await t.tap(find.byKey(SafetyGuidelinesSheet.closeKey));
    await settle(t);
    expect(find.byKey(SafetyGuidelinesSheet.closeKey), findsNothing);
    await drain(t);
  });

  for (final size in socialSizes) {
    for (final scale in socialScales) {
      testWidgets('fits without overflow, every full line is shown ($size, $scale)', (t) async {
        await openSheet(t, size: Size(size.width, 800), scale: scale);
        expect(find.text(SocialSafetyStrings.detailsLine), findsOneWidget);
        expect(find.byKey(SafetyGuidelinesSheet.understoodKey), findsOneWidget);
        expect(t.takeException(), isNull);
        await drain(t);
      });
    }
  }
}
