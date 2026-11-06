import 'package:bakhli/screens/intro/intro_scaffold.dart';
import 'package:bakhli/screens/intro/intro_slide_a.dart';
import 'package:bakhli/screens/intro/intro_slide_b.dart';
import 'package:bakhli/screens/intro/intro_strings.dart';
import 'package:bakhli/screens/intro/intro_widgets.dart';
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
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: reduce,
      ),
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
  await tester.pumpWidget(_app(
    IntroScaffold(onFinish: onFinish ?? () {}, autoplay: autoplay),
    scale: scale,
    reduce: reduce,
  ));
  await _pumpFor(tester, const Duration(seconds: 1));
}

int _page(WidgetTester tester) {
  final controller = tester.widget<PageView>(find.byType(PageView)).controller!;
  return controller.page!.round();
}

Future<void> _goTo(WidgetTester tester, int k) async {
  await tester.tap(find.byKey(Key('intro_stop_$k')));
  await _pumpFor(tester, const Duration(seconds: 3));
}

Finder _ctaText(String label) => find.descendant(
      of: find.byKey(const Key('intro_cta')),
      matching: find.text(label),
    );

void main() {
  group('layout and motion matrix', () {
    for (final sizeEntry in _sizes.entries) {
      for (final scale in const [1.0, 1.3]) {
        for (final reduce in const [false, true]) {
          testWidgets(
              'all pages ${sizeEntry.key} scale $scale reduceMotion $reduce',
              (tester) async {
            await _pumpIntro(tester,
                size: sizeEntry.value, scale: scale, reduce: reduce);
            expect(tester.takeException(), isNull);
            for (var k = 0; k < IntroScaffold.pageCount; k++) {
              if (k > 0) await _goTo(tester, k);
              await _pumpFor(tester, const Duration(seconds: 3));
              expect(tester.takeException(), isNull,
                  reason: 'page $k threw or overflowed');
              expect(_page(tester), k);
              expect(find.byKey(ValueKey('intro_page_$k')), findsOneWidget);
            }
          });
        }
      }
    }
  });

  group('structure', () {
    testWidgets('six stops and six pages', (tester) async {
      expect(IntroScaffold.pageCount, 6);
      await _pumpIntro(tester, size: _sizes['360x640']!);
      for (var k = 0; k < IntroScaffold.pageCount; k++) {
        expect(find.byKey(Key('intro_stop_$k')), findsOneWidget);
      }
      expect(find.byKey(Key('intro_stop_${IntroScaffold.pageCount}')),
          findsNothing);
      expect(tester.widget<PageView>(find.byType(PageView)).childrenDelegate
          .estimatedChildCount, IntroScaffold.pageCount);
    });

    testWidgets('skip tappable on pages 0-4, not on 5',
        (tester) async {
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
      await _pumpIntro(tester,
          size: _sizes['360x640']!, onFinish: () => finished++);
      await tester.tap(find.byKey(const Key('intro_skip')));
      await _pumpFor(tester, const Duration(milliseconds: 500));
      expect(finished, 1);
    });

    testWidgets('cta label is Next on 0-4 and Start planning on 5',
        (tester) async {
      await _pumpIntro(tester, size: _sizes['360x640']!);
      for (var k = 0; k < IntroScaffold.pageCount; k++) {
        if (k > 0) await _goTo(tester, k);
        if (k < IntroScaffold.pageCount - 1) {
          expect(_ctaText('Next'), findsOneWidget, reason: 'page $k');
          expect(_ctaText('Start planning'), findsNothing);
        } else {
          expect(_ctaText('Start planning'), findsOneWidget);
          expect(_ctaText('Next'), findsNothing);
        }
      }
    });

    testWidgets('next moves forward one page', (tester) async {
      await _pumpIntro(tester, size: _sizes['360x640']!);
      await tester.tap(find.byKey(const Key('intro_cta')));
      await _pumpFor(tester, const Duration(seconds: 2));
      expect(_page(tester), 1);
    });

    testWidgets('get started finishes exactly once even when tapped twice',
        (tester) async {
      var finished = 0;
      await _pumpIntro(tester,
          size: _sizes['360x640']!, onFinish: () => finished++);
      await _goTo(tester, IntroScaffold.pageCount - 1);
      await tester.tap(find.byKey(const Key('intro_cta')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('intro_cta')), warnIfMissed: false);
      await _pumpFor(tester, const Duration(milliseconds: 500));
      expect(finished, 1);
    });
  });

  group('swipe', () {
    testWidgets('fling left goes to page 1, fling right on page 0 stays',
        (tester) async {
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
      testWidgets('settles within 1 s on page $k', (tester) async {
        await _pumpIntro(tester, size: _sizes['360x640']!, reduce: true);
        if (k > 0) {
          await tester.tap(find.byKey(Key('intro_stop_$k')));
        }
        await tester.pumpAndSettle(const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate, const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(_page(tester), k);
      });
    }
  });

  group('autoplay', () {
    testWidgets('advances from page 0 to page 1', (tester) async {
      await _pumpIntro(tester, size: _sizes['360x640']!, autoplay: true);
      await _pumpFor(
          tester, IntroScaffold.autoplayInterval + const Duration(seconds: 2));
      expect(_page(tester), 1);
    });

    testWidgets('stays on the last page', (tester) async {
      await _pumpIntro(tester, size: _sizes['360x640']!, autoplay: true);
      await _goTo(tester, IntroScaffold.pageCount - 1);
      await _pumpFor(tester, IntroScaffold.autoplayInterval * 2);
      expect(_page(tester), IntroScaffold.pageCount - 1);
    });

    testWidgets('an interaction pauses it for that page', (tester) async {
      await _pumpIntro(tester, size: _sizes['360x640']!, autoplay: true);
      const IntroInteractionNotification()
          .dispatch(tester.element(find.byType(IntroSlidePick)));
      await _pumpFor(
          tester, IntroScaffold.autoplayInterval + const Duration(seconds: 2));
      expect(_page(tester), 0);
    });

    testWidgets('off with reduce motion', (tester) async {
      await _pumpIntro(tester,
          size: _sizes['360x640']!, autoplay: true, reduce: true);
      await _pumpFor(
          tester, IntroScaffold.autoplayInterval + const Duration(seconds: 2));
      expect(_page(tester), 0);
    });
  });

  group('slides alone', () {
    final builders = <String, Widget Function(bool, ValueNotifier<double>)>{
      'pick': (a, p) => IntroSlidePick(isActive: a, progress: p),
      'plan': (a, p) => IntroSlidePlan(isActive: a, progress: p),
      'ask': (a, p) => IntroSlideAsk(isActive: a, progress: p),
      'taxi': (a, p) => IntroSlideTaxi(isActive: a, progress: p),
      'live': (a, p) => IntroSlideLive(isActive: a, progress: p),
      'start': (a, p) => IntroSlideStart(isActive: a, progress: p),
    };

    Widget host(Widget slide, {bool reduce = false}) => _app(
          Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                  size: IntroSlideCanvas.size, child: slide),
            ),
          ),
          reduce: reduce,
        );

    var index = 0;
    for (final entry in builders.entries) {
      final k = index++;
      testWidgets('${entry.key}: animates, then stops when inactive',
          (tester) async {
        _setView(tester, const Size(800, 600));
        final progress = ValueNotifier<double>(k.toDouble());
        addTearDown(progress.dispose);
        await tester.pumpWidget(host(entry.value(true, progress)));
        await _pumpFor(tester, const Duration(milliseconds: 3000));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(host(entry.value(false, progress)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        expect(tester.binding.transientCallbackCount, 0);
      });

      testWidgets('${entry.key}: reduce motion shows the final frame idle',
          (tester) async {
        _setView(tester, const Size(800, 600));
        final progress = ValueNotifier<double>(k.toDouble());
        addTearDown(progress.dispose);
        await tester.pumpWidget(host(entry.value(true, progress), reduce: true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        expect(tester.binding.transientCallbackCount, 0);
      });
    }
  });

  group('copy rules', () {
    const forbidden = [
      'Nainital',
      'Bhimtal',
      'Kainchi',
      'Naini',
      'Mall Road',
      'hills',
      'commission',
      'middleman',
      'Talk to hosts',
    ];

    testWidgets('tagline only on page 5, finale ring text', (tester) async {
      await _pumpIntro(tester, size: _sizes['360x640']!);
      for (var k = 0; k < IntroScaffold.pageCount; k++) {
        if (k > 0) await _goTo(tester, k);
        final page = find.byKey(ValueKey('intro_page_$k'));
        expect(
          find.descendant(
              of: page, matching: find.text(IntroStrings.tagline)),
          k == 5 ? findsOneWidget : findsNothing,
          reason: 'tagline on page $k',
        );
        for (final word in forbidden) {
          expect(find.textContaining(word), findsNothing,
              reason: '$word on page $k');
        }
      }
      expect(find.text(IntroStrings.tagline), findsOneWidget);
      expect(find.text('Your next trip'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    });
  });
}
