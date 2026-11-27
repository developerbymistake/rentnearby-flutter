import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/stay_owner/quotation/controllers/quote_form_controller.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_doc_store.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_models.dart';
import 'package:bakhli/features/stay_owner/quotation/pdf/quote_engine.dart';
import 'package:bakhli/features/stay_owner/quotation/screens/quote_preview_screen.dart';
import 'package:bakhli/features/stay_owner/strings/stay_quote_strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'quote_fakes.dart';

void main() {
  late FakeEngine engine;
  late FakeSource source;
  late QuoteDocStore store;
  final realOpen = QuoteFormController.openStore;

  setUp(() {
    DS.applyApproved();
    store = memoryStore(timers: TimerLog(), now: () => DateTime(2026, 11, 27));
    QuoteFormController.openStore = (_) async => store;
  });

  tearDown(() {
    QuoteFormController.openStore = realOpen;
    DS.debugReset();
    Get.reset();
  });

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(WidgetTester t, {QuoteUsage usage = const QuoteUsage(used: 0, limit: 2), bool watermark = true, List<QuotePreviewPage> pages = const []}) async {
    engine = FakeEngine()..previewPages = pages;
    source = FakeSource(business0: sampleBusiness(usage: usage, previewWatermark: watermark), usage0: usage);
    await store.saveNow(sampleDraft());
    await t.pumpWidget(GetMaterialApp(
      home: QuotePreviewScreen(args: const {'documentId': 'doc-00000001'}, source: source, engine: engine, offline: () async => false),
    ));
    await settle(t);
  }

  testWidgets('Q11 the preview uses only QuoteEngineApi.preview: no layout, no PDF, no reserve; watermark from the hub', (t) async {
    await pump(t);
    expect(engine.calls, ['preview:true']);
    expect(source.reserves, isEmpty);
    expect(source.log.contains('reserve'), isFalse);
    expect(find.text(StayQuoteStrings.previewOnly), findsOneWidget);
  });

  testWidgets('Q11 previewWatermark false from the hub reaches the engine', (t) async {
    await pump(t, watermark: false);
    expect(engine.calls, ['preview:false']);
  });

  testWidgets('B1 limit reached: the calm sheet opens, and after it closes the hub is reloaded', (t) async {
    await pump(t, usage: const QuoteUsage(used: 2, limit: 2), pages: [FakeEngine.tinyPage()]);
    await t.tap(find.text(StayQuoteStrings.downloadPdf));
    await settle(t);
    expect(find.text(StayQuoteStrings.allUsed(2)), findsOneWidget);
    expect(source.reserves, isEmpty);
    await t.tap(find.text(StayQuoteStrings.ok));
    await settle(t);
    expect(source.refreshes, 1);
  });

  testWidgets('Q7 a good download opens the saved sheet; Open file opens the new file', (t) async {
    await pump(t, pages: [FakeEngine.tinyPage()]);
    await t.tap(find.text(StayQuoteStrings.downloadPdf));
    await settle(t);
    expect(source.reserves.length, 1);
    expect(engine.calls.contains('render'), isTrue);
    expect(find.text(StayQuoteStrings.savedTitle), findsOneWidget);
    expect(find.text(StayQuoteStrings.savedSub('Q-0042_Harshit_Mansi.pdf', 1)), findsOneWidget);
    await t.tap(find.text(StayQuoteStrings.openFile));
    await settle(t);
    expect(engine.opened, ['content://media/external/downloads/1']);
  });
}
