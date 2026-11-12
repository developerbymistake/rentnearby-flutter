import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/screens/privacy_policy_screen.dart';

const _sentence =
    'Chats with no new messages for 90 days, notifications older than 90 days and old closed enquiries are removed automatically.';

void main() {
  test('privacy source carries the retention sentence once', () {
    final src = File('lib/screens/privacy_policy_screen.dart').readAsStringSync();
    expect(_sentence.allMatches(src).length, 1);
  });

  testWidgets('privacy screen shows the retention sentence', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));
    await tester.pump();
    final finder = find.textContaining('removed automatically', skipOffstage: false);
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.textContaining('removed automatically'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
    }
    expect(find.textContaining('removed automatically', skipOffstage: false), findsWidgets);
  });
}
