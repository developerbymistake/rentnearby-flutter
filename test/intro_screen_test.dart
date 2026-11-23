import 'package:bakhli/screens/intro/intro_scaffold.dart';
import 'package:bakhli/screens/intro/intro_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _sizes = <String, Size>{
  '320x568': Size(320, 568),
  '360x640': Size(360, 640),
  '412x915': Size(412, 915),
};

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(Widget home, {double scale = 1.0, bool reduce = false}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: reduce),
      child: child!,
    ),
    home: home,
  );
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

Future<void> _pumpIntro(
  WidgetTester tester, {
  required Size size,
  double scale = 1.0,
  bool reduce = false,
  bool autoplay = false,
  VoidCallback? onFinish,
}) async {
  _setView(tester, size);
  await tester.pumpWidget(_app(IntroScaffold(onFinish: onFinish ?? () {}, autoplay: autoplay), scale: scale, reduce: reduce));
  await _pumpFor(tester, const Duration(seconds: 1));
}

PageController _controller(WidgetTester tester) => tester.widget<PageView>(find.byType(PageView)).controller!;

int _page(WidgetTester tester) => _controller(tester).page!.round();

Future<void> _goTo(WidgetTester tester, int k) async {
  _controller(tester).jumpToPage(k);
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

Finder _ctaText(String label) => find.descendant(of: find.byKey(const Key('intro_cta')), matching: find.text(label));

void main() {
  group('layout and motion matrix', () {
    for (final sizeEntry in _sizes.entries) {
      for (final scale in const [1.0, 1.3]) {
        for (final reduce in const [false, true]) {
          testWidgets('all pages ${sizeEntry.key} scale $scale reduceMotion $reduce', (tester) async {
            await _pumpIntro(tester, size: sizeEntry.value, scale: scale, reduce: reduce);
            expect(tester.takeException(), isNull);
            for (var k = 0; k < IntroScaffold.pageCount; k++) {
              if (k > 0) await _goTo(tester, k);
              await _pumpFor(tester, const Duration(milliseconds: 600));
              expect(tester.takeException(), isNull, reason: 'page $k threw or overflowed');
              expect(_page(tester), k);
              expect(find.byKey(ValueKey('intro_page_$k')), findsOneWidget);
              expect(find.byKey(ValueKey('intro_text_$k')), findsOneWidget);
            }
          });
        }
      }
    }
  });

  group('structure', () {
    testWidgets('six pages, six dots, no journey thread stops', (tester) async {
      expect(IntroScaffold.pageCount, 6);
      await _pumpIntro(tester, size: _sizes['360x640']!);
      expect(tester.widget<PageView>(find.byType(PageView)).childrenDelegate.estimatedChildCount, IntroScaffold.pageCount);
      final dots = find.byKey(const Key('intro_dots'));
      expect(dots, findsOneWidget);
      expect(tester.widget<Row>(dots).children.whereType<Container>().length, IntroScaffold.pageCount);
      expect(find.byKey(const Key('intro_stop_0')), findsNothing);
    });

    testWidgets('skip tappable on pages 0-4, not on 5', (tester) async {
      await _pumpIntro(tester, size: _sizes['360x640']!);
      for (var k = 0; k < IntroScaffold.pageCount; k++) {
        if (k > 0) await _goTo(tester, k);
        final skip = find.byKey(const Key('intro_skip'));
        if (k < IntroScaffold.pageCount - 1) {
          expect(skip.hitTestable(), findsOneWidget, reason: 'page $k');
        } else {
          expect(skip.hitTestable(), findsNothing);
        }
      }
    });

    testWidgets('skip finishes once', (tester) async {
      var finished = 0;
      await _pumpIntro(tester, size: _sizes['360x640']!, onFinish: () => finished++);
      await tester.tap(find.byKey(const Key('intro_skip')));
      await tester.tap(find.byKey(const Key('intro_skip')), warnIfMissed: false);
      await _pumpFor(tester, const Duration(milliseconds: 500));
      expect(finished, 1);
    });

    testWidgets('cta label is Next on 0-4 and Start planning on 5', (tester) async {
      await _pumpIntro(tester, size: _sizes['360x640']!);
      for (var k = 0; k < IntroScaffold.pageCount; k++) {
        if (k > 0) await _goTo(tester, k);
        if (k < IntroScaffold.pageCount - 1) {
          expect(_ctaText(IntroStrings.next), findsOneWidget, reason: 'page $k');
          expect(_ctaText(IntroStrings.getStarted), findsNothing);
        } else {
          expect(_ctaText(IntroStrings.getStarted), findsOneWidget);
          expect(_ctaText(IntroStrings.next), findsNothing);
        }
      }
    });

    testWidgets('next moves forward one page', (tester) async {
      await _pumpIntro(tester, size: _sizes['360x640']!);
      await tester.tap(find.byKey(const Key('intro_cta')));
      await _pumpFor(tester, const Duration(seconds: 2));
      expect(_page(tester), 1);
    });

    testWidgets('start planning finishes exactly once even when tapped twice', (tester) async {
      var finished = 0;
      await _pumpIntro(tester, size: _sizes['360x640']!, onFinish: () => finished++);
      await _goTo(tester, IntroScaffold.pageCount - 1);
      await tester.tap(find.byKey(const Key('intro_cta')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('intro_cta')), warnIfMissed: false);
      await _pumpFor(tester, const Duration(milliseconds: 500));
      expect(finished, 1);
    });
  });

  group('swipe', () {
    testWidgets('fling left goes to page 1, fling right on page 0 stays', (tester) async {
      await _pumpIntro(tester, size: _sizes['360x640']!);
      await tester.fling(find.byType(PageView), const Offset(300, 0), 1200);
      await _pumpFor(tester, const Duration(seconds: 2));
      expect(_page(tester), 0);
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1200);
      await _pumpFor(tester, const Duration(seconds: 2));
      expect(_page(tester), 1);
    });

    testWidgets('no wrap past the last page', (tester) async {
      await _pumpIntro(tester, size: _sizes['360x640']!);
      await _goTo(tester, IntroScaffold.pageCount - 1);
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1200);
      await _pumpFor(tester, const Duration(seconds: 2));
      expect(_page(tester), IntroScaffold.pageCount - 1);
    });
  });

  group('reduce motion', () {
    for (var k = 0; k < IntroScaffold.pageCount; k++) {
      testWidgets('settles within 1 s on page $k with no running ticker', (tester) async {
        await _pumpIntro(tester, size: _sizes['360x640']!, reduce: true);
        if (k > 0) _controller(tester).jumpToPage(k);
        await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(_page(tester), k);
        expect(tester.binding.transientCallbackCount, 0);
      });
    }

    testWidgets('next jumps without animation', (tester) async {
      await _pumpIntro(tester, size: _sizes['360x640']!, reduce: true);
      await tester.tap(find.byKey(const Key('intro_cta')));
      await tester.pump();
      expect(_page(tester), 1);
    });
  });

  group('autoplay', () {
    testWidgets('advances from page 0 to page 1', (tester) async {
      await _pumpIntro(tester, size: _sizes['360x640']!, autoplay: true);
      await _pumpFor(tester, IntroScaffold.autoplayInterval + const Duration(seconds: 2));
      expect(_page(tester), 1);
    });

    testWidgets('stays on the last page', (tester) async {
      await _pumpIntro(tester, size: _sizes['360x640']!, autoplay: true);
      await _goTo(tester, IntroScaffold.pageCount - 1);
      await _pumpFor(tester, IntroScaffold.autoplayInterval * 2);
      expect(_page(tester), IntroScaffold.pageCount - 1);
    });

    testWidgets('off with reduce motion', (tester) async {
      await _pumpIntro(tester, size: _sizes['360x640']!, autoplay: true, reduce: true);
      await _pumpFor(tester, IntroScaffold.autoplayInterval + const Duration(seconds: 2));
      expect(_page(tester), 0);
    });
  });

  group('scene life cycle', () {
    testWidgets('story ticker runs, and nothing is left after dispose', (tester) async {
      await _pumpIntro(tester, size: _sizes['360x640']!);
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('ticker stops after finish', (tester) async {
      await _pumpIntro(tester, size: _sizes['360x640']!);
      await tester.tap(find.byKey(const Key('intro_skip')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('copy rules', () {
    const forbidden = ['Nainital', 'Bhimtal', 'Kainchi', 'Naini', 'Mall Road', 'hills', 'commission', 'middleman', 'Talk to hosts'];

    test('no forbidden words, tagline only in chapter 6', () {
      for (var k = 0; k < IntroStrings.slides.length; k++) {
        final c = IntroStrings.slides[k];
        final all = '${c.eyebrow} ${c.headline} ${c.sub}';
        for (final word in forbidden) {
          expect(all.contains(word), isFalse, reason: '$word in chapter $k');
        }
        expect(all.contains(IntroStrings.tagline), k == 5, reason: 'tagline in chapter $k');
      }
    });

    testWidgets('at rest on the last page only its text block is built', (tester) async {
      await _pumpIntro(tester, size: _sizes['360x640']!);
      await _goTo(tester, 5);
      for (var k = 0; k < 6; k++) {
        expect(find.byKey(ValueKey('intro_text_$k')), k == 5 ? findsOneWidget : findsNothing);
      }
      expect(find.bySemanticsLabel(IntroStrings.tagline), findsOneWidget);
    });
  });
}
