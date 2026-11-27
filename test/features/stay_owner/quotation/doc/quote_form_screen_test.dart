import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/stay_owner/quotation/controllers/quote_form_controller.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_doc_store.dart';
import 'package:bakhli/features/stay_owner/quotation/screens/quote_form_screen.dart';
import 'package:bakhli/features/stay_owner/strings/stay_quote_strings.dart';
import 'package:flutter/material.dart';
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

  Future<void> pump(WidgetTester t, {String gstin = ''}) async {
    engine = FakeEngine();
    source = FakeSource(business0: sampleBusiness(gstin: gstin));
    await t.binding.setSurfaceSize(const Size(420, 3200));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(GetMaterialApp(
      home: QuoteFormScreen(args: const {'new': true}, source: source, engine: engine),
      getPages: [
        GetPage<dynamic>(
          name: AppRoutes.stayQuotationBusiness,
          page: () => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  source.business0 = sampleBusiness();
                  Get.back<dynamic>(result: true);
                },
                child: const Text('save business'),
              ),
            ),
          ),
        ),
      ],
    ));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('Q7 the document type comes first; Valid till defaults to the date + 7 days', (t) async {
    await pump(t);
    expect(find.text(StayQuoteStrings.documentType), findsOneWidget);
    expect(t.getTopLeft(find.text(StayQuoteStrings.documentType)).dy, lessThan(t.getTopLeft(find.text(StayQuoteStrings.guest)).dy));
    final now = DateTime.now();
    final valid = DateTime(now.year, now.month, now.day).add(const Duration(days: 7));
    expect(find.text(StayQuoteStrings.dayMonth(valid)), findsOneWidget);
    expect(engine.calls, contains('warmUp'));
  });

  testWidgets('Q9 / I5 no GSTIN: hint line; after Business details saves a GSTIN the GST field shows at once', (t) async {
    await pump(t);
    expect(find.text(StayQuoteStrings.gst), findsNothing);
    await t.ensureVisible(find.text(StayQuoteStrings.gstHint));
    await t.tap(find.text(StayQuoteStrings.gstHint));
    await t.pumpAndSettle();
    await t.tap(find.text('save business'));
    await t.pumpAndSettle();
    expect(find.text(StayQuoteStrings.gstHint), findsNothing);
    expect(find.text(StayQuoteStrings.gst), findsOneWidget);
  });

  testWidgets('I5 a hub change while the form is open (logo, terms, GSTIN) reaches the form', (t) async {
    await pump(t);
    expect(find.text(StayQuoteStrings.gst), findsNothing);
    source.changeBusiness(sampleBusiness());
    await t.pump();
    await t.pump();
    expect(find.text(StayQuoteStrings.gst), findsOneWidget);
  });

  testWidgets('m4 quick-add and mock copy: chips read "+ Room", meal pills carry their sub lines', (t) async {
    await pump(t);
    expect(find.text(StayQuoteStrings.quickRoomChip), findsOneWidget);
    expect(find.text(StayQuoteStrings.quickExtraChip), findsOneWidget);
    expect(find.text(StayQuoteStrings.mealEpSub), findsOneWidget);
    expect(find.text(StayQuoteStrings.mealApSub), findsOneWidget);
  });
}
