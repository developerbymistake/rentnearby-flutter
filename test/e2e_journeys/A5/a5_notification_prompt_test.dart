import 'package:bakhli/services/notification_service.dart';
import 'package:bakhli/widgets/notification_off_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 12, 12);

  group('promptDue', () {
    test('denied without any stored token still prompts', () {
      expect(NotificationService.promptDue(denied: true, dismissedAt: null, now: now), isTrue);
    });
    test('allowed never prompts', () {
      expect(NotificationService.promptDue(denied: false, dismissedAt: null, now: now), isFalse);
    });
    test('a dismissal under 24 hours old hides it, older shows it again', () {
      expect(NotificationService.promptDue(denied: true, dismissedAt: now.subtract(const Duration(hours: 23)), now: now), isFalse);
      expect(NotificationService.promptDue(denied: true, dismissedAt: now.subtract(const Duration(hours: 24)), now: now), isTrue);
    });
  });

  group('banner', () {
    Future<void> pump(WidgetTester t, {required bool denied, void Function()? onOpen, double w = 300, double scale = 2}) async {
      t.view.physicalSize = Size(w, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
        home: Scaffold(
          body: NotificationOffBanner(isDenied: () async => denied, openSettings: () async => onOpen?.call()),
        ),
      ));
      await t.pump();
    }

    testWidgets('shown when denied, Open settings works, no overflow at 300 dp scale 2', (t) async {
      var opened = 0;
      await pump(t, denied: true, onOpen: () => opened++);
      expect(find.text('Turn on notifications'), findsOneWidget);
      await t.tap(find.text('Open settings'));
      expect(opened, 1);
      expect(t.takeException(), isNull);
    });

    testWidgets('hidden when allowed', (t) async {
      await pump(t, denied: false);
      expect(find.text('Turn on notifications'), findsNothing);
    });
  });
}
