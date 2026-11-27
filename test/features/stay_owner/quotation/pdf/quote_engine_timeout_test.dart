import 'dart:async';
import 'dart:io';

import 'package:bakhli/features/stay_owner/quotation/controllers/quote_download_controller.dart';
import 'package:bakhli/features/stay_owner/quotation/controllers/quote_form_controller.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_models.dart';
import 'package:bakhli/features/stay_owner/quotation/pdf/quote_engine.dart';
import 'package:bakhli/features/stay_owner/strings/stay_quote_strings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../doc/quote_fakes.dart';

const _channel = MethodChannel('test/quote_pdf_timeout');
const _kotlin = 'android/app/src/main/kotlin/com/rentnearby/rentnearby/QuotePdfChannel.kt';

void main() {
  final now = DateTime.utc(2026, 11, 27, 10);
  late List<MethodCall> calls;

  QuoteFormController form() =>
      QuoteFormController(initial: sampleDraft(), store: memoryStore(timers: TimerLog()), business: sampleBusiness(), ownerId: 'user-1', now: () => now);

  // Layout answers, every other job never answers: a lost native callback.
  void silentChannel(WidgetTester tester, {bool answerLayout = true}) {
    calls = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) {
      calls.add(call);
      if (call.method == 'cancel') return Future.value();
      if (answerLayout && call.method == 'layout') return Future.value({'ok': true, 'pages': 1, 'fit': 0});
      return Completer<Object?>().future;
    });
  }

  List<int> jobIds(String method) => [for (final c in calls.where((c) => c.method == method)) (c.arguments as Map)['job'] as int];

  tearDown(Get.reset);

  for (final method in ['render', 'preview', 'layout']) {
    testWidgets('B1 a $method that never answers fails as renderFailed after the time limit and is cancelled natively', (tester) async {
      silentChannel(tester, answerLayout: false);
      final engine = QuoteEngine(channel: _channel);
      final doc = form().doc();
      QuoteEngineException? error;
      final Future<Object?> job = switch (method) {
        'render' => engine.render('classic', doc, fileName: 'Q-0042_Guest.pdf'),
        'preview' => engine.preview('classic', doc, widthPx: 720, watermark: true),
        _ => engine.layout('classic', doc),
      };
      unawaited(job.then((_) {}, onError: (Object e) {
        error = e as QuoteEngineException;
      }));

      await tester.pump(QuoteEngine.jobTimeout - const Duration(seconds: 1));
      expect(error, isNull);
      expect(jobIds('cancel'), isEmpty);

      await tester.pump(const Duration(seconds: 2));
      expect(error?.failure, QuoteEngineFailure.renderFailed);
      expect(jobIds('cancel'), jobIds(method));
    });
  }

  testWidgets('B1 / I1 every job carries its own token', (tester) async {
    silentChannel(tester);
    final engine = QuoteEngine(channel: _channel);
    final doc = form().doc();
    await engine.layout('classic', doc);
    await engine.layout('classic', doc);
    final ids = jobIds('layout');
    expect(ids.length, 2);
    expect(ids.toSet().length, 2);
  });

  testWidgets('B1 download with a never-answering render ends with a message and busy false; both renders are cancelled', (tester) async {
    silentChannel(tester);
    final dl = QuoteDownloadController(
      form: form(),
      source: FakeSource(business0: sampleBusiness(), usage0: const QuoteUsage(used: 0, limit: 2, canUpgrade: true)),
      engine: QuoteEngine(channel: _channel),
      offline: () async => false,
      askStorage: () async => true,
      now: () => now,
    );
    QuoteDownloadResult? result;
    unawaited(dl.download().then((r) => result = r));

    await tester.pump();
    expect(dl.busy.value, isTrue);
    expect(jobIds('render').length, 1);

    await tester.pump(QuoteEngine.jobTimeout + const Duration(seconds: 1));
    expect(jobIds('render').length, 2, reason: 'one automatic retry after renderFailed');
    expect(result, isNull);

    await tester.pump(QuoteEngine.jobTimeout + const Duration(seconds: 1));
    expect(result, isA<QuoteDownloadMessage>());
    expect((result! as QuoteDownloadMessage).message, StayQuoteStrings.renderFailed);
    expect(dl.busy.value, isFalse);
    expect(jobIds('cancel'), jobIds('render'));
  });

  test('B1 / I1 / I2 / I6 native guards stay in the channel', () {
    final kt = File(_kotlin).readAsStringSync();
    for (final rule in [
      'offscreenPreRaster = true',
      'RENDER_TIMEOUT_MS = 30_000L',
      'STEP_TIMEOUT_MS = 12_000L',
      'main.postDelayed(watchdog, timeoutMs)',
      '"cancel" ->',
      'val alive: Boolean get() = !answered && current === this',
      'catch (t: Throwable)',
      'releaseWhenIdle = true',
      'ConcurrentHashMap<String, ByteArray>()',
      '@Volatile private var imgUser',
      'offsetByCodePoints',
      'LOW_RAM_WIDTH',
    ]) {
      expect(kt, contains(rule), reason: rule);
    }
    expect(kt.contains('onGone'), isFalse);
    expect(kt.contains('if (!running) destroyWebView()'), isFalse, reason: 'dispose during a job is deferred, never dropped');
  });

  test('minor 5: the template script sets the PDF title from the document number', () {
    final js = File('assets/quote_templates/quote.js').readAsStringSync();
    expect(js, contains("document.title = data && typeof data.number === 'string'"));
  });
}
