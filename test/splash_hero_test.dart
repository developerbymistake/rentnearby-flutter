import 'package:bakhli/config/app_colors.dart';
import 'package:bakhli/screens/splash/splash_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _sizes = <String, Size>{
  '320x568': Size(320, 568),
  '360x640': Size(360, 640),
  '412x915': Size(412, 915),
};

Widget _host({required double scale, required bool reduce}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Builder(
      builder: (c) => MediaQuery(
        data: MediaQuery.of(c).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduce,
        ),
        child: const Scaffold(
          backgroundColor: AppColors.textDark,
          body: SplashHero(),
        ),
      ),
    ),
  );
}

void main() {
  for (final entry in _sizes.entries) {
    for (final scale in const [1.0, 1.3]) {
      for (final reduce in const [false, true]) {
        final name = '${entry.key} scale $scale reduce $reduce';
        testWidgets('SplashHero $name', (tester) async {
          final size = entry.value;
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          var hits = 0;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'HapticFeedback.vibrate') hits++;
              return null;
            },
          );
          addTearDown(() => tester.binding.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null));

          await tester.pumpWidget(_host(scale: scale, reduce: reduce));
          expect(tester.takeException(), isNull);

          final darkBase = find.descendant(
            of: find.byType(SplashHero),
            matching: find.byWidgetPredicate(
              (w) => w is ColoredBox && w.color == AppColors.textDark,
            ),
          );
          expect(darkBase, findsOneWidget);
          expect(AppColors.textDark.computeLuminance(), lessThan(0.1));
          expect(
            find.descendant(
              of: find.byType(SplashHero),
              matching: find.byType(Image),
            ),
            findsNothing,
          );
          expect(find.textContaining('Discover'), findsNothing);

          for (var i = 0; i < 16; i++) {
            await tester.pump(const Duration(milliseconds: 100));
            expect(tester.takeException(), isNull);
          }
          expect(find.text('Bakhli'), findsOneWidget);
          expect(hits, reduce ? 0 : 1);

          final rect = tester.getRect(find.text('Bakhli'));
          expect(
            (Offset.zero & size).inflate(0.5).contains(rect.topLeft) &&
                (Offset.zero & size).inflate(0.5).contains(rect.bottomRight),
            isTrue,
          );

          await tester.pump(const Duration(milliseconds: 3000));
          expect(tester.takeException(), isNull);
          expect(hits, reduce ? 0 : 1);
          expect(tester.hasRunningAnimations, !reduce);

          await tester.pumpWidget(const SizedBox());
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
