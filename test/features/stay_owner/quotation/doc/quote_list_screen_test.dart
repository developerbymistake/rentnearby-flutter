import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/stay_owner/quotation/controllers/quote_form_controller.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_doc_store.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_models.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_draft.dart';
import 'package:bakhli/features/stay_owner/quotation/screens/quote_list_screen.dart';
import 'package:bakhli/features/stay_owner/quotation/screens/quote_template_screen.dart';
import 'package:bakhli/features/stay_owner/strings/stay_quote_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'quote_fakes.dart';

void main() {
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
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  group('10.7 list screen', () {
    testWidgets('drafts first with no Open button; a downloaded row has Open; count from the hub', (t) async {
      final at = DateTime.utc(2026, 11, 27, 9);
      final downloaded = QuoteDraft.blank(documentId: 'doc-00000002', today: DateTime(2026, 11, 20))
          .copyWith(guestName: 'Asha Rawat')
          .withReservation(
            QuoteKind.quotation,
            QuoteReservation(number: 42, display: 'Q-0042', issuedAt: at, freeUntil: at, freeLeft: 0, businessName: 'B')
                .withFile(uri: 'content://media/external/downloads/9', name: 'Q-0042_Asha_Rawat.pdf', pages: 1, at: at),
          );
      await store.saveNow(sampleDraft(), total: 1000);
      await store.saveNow(downloaded, total: 2000);
      final source = FakeSource(business0: sampleBusiness(), usage0: const QuoteUsage(used: 1, limit: 2));
      await t.binding.setSurfaceSize(const Size(420, 1600));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(GetMaterialApp(home: QuoteListScreen(args: const {}, source: source)));
      await settle(t);
      expect(find.text(StayQuoteStrings.notDownloaded), findsOneWidget);
      expect(find.text(StayQuoteStrings.downloadedHere), findsOneWidget);
      expect(find.text('${StayQuoteStrings.draft} · Harshit & Mansi'), findsOneWidget);
      expect(find.text('Q-0042 · Asha Rawat'), findsOneWidget);
      expect(find.text(StayQuoteStrings.open), findsOneWidget);
      expect(find.textContaining('1 of 2 used'), findsOneWidget);
      expect(find.text(StayQuoteStrings.newQuotation), findsOneWidget);
      expect(find.text(StayQuoteStrings.fromAnEnquiry), findsOneWidget);
    });

    testWidgets('empty list: the empty card', (t) async {
      final source = FakeSource(business0: sampleBusiness(), usage0: const QuoteUsage(used: 0, limit: 2));
      await t.pumpWidget(GetMaterialApp(home: QuoteListScreen(args: const {}, source: source)));
      await settle(t);
      expect(find.text(StayQuoteStrings.emptyTitle), findsOneWidget);
    });
  });

  group('Q5 template screen', () {
    testWidgets('three templates; live thumbnails without watermark; a tap selects; no PDF, no count', (t) async {
      await store.saveNow(sampleDraft());
      final engine = FakeEngine();
      final source = FakeSource(business0: sampleBusiness());
      await t.binding.setSurfaceSize(const Size(420, 1600));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(GetMaterialApp(home: QuoteTemplateScreen(args: const {'documentId': 'doc-00000001'}, source: source, engine: engine)));
      await settle(t);
      expect(find.text(StayQuoteStrings.classic), findsOneWidget);
      expect(find.text(StayQuoteStrings.band), findsOneWidget);
      expect(find.text(StayQuoteStrings.modern), findsOneWidget);
      expect(engine.calls, ['preview:false', 'preview:false', 'preview:false']);
      await t.tap(find.text(StayQuoteStrings.modern));
      await t.pump();
      await t.pump();
      expect(store.index.readTemplate(), 'modern');
      expect(source.reserves, isEmpty);
    });
  });
}
