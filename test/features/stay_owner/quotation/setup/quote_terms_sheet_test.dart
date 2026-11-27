import 'package:bakhli/features/stay_owner/quotation/controllers/quote_hub_controller.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_asset_store.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_models.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/stay_owner/quotation/widgets/quote_terms_sheet.dart';
import 'package:bakhli/features/stay_owner/strings/stay_quote_terms_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quote_setup_fakes.dart';

void main() {
  late FakeQuoteApi api;
  late QuoteHubController hub;
  bool? result;

  Future<void> open(WidgetTester tester) async {
    api = FakeQuoteApi()..hubResult = OwnerOk(QuoteHubResponse(notModified: false, hub: QuoteHub.fromJson(hubJson(acceptedVersion: null))));
    hub = QuoteHubController(api: api, store: QuoteAssetStore(engine: FakeEngine(), api: api, secure: MemKeyValue(), boxes: MemBoxes()), userId: () => 'u1', appVersion: () async => '1.2.0');
    await tester.runAsync(hub.load);
    result = null;
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (c) => Center(child: ElevatedButton(onPressed: () async => result = await QuoteTermsSheet.ask(c, hub), child: const Text('open')))),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the five lines; Continue does nothing until the tick (Q4)', (tester) async {
    await open(tester);
    expect(find.text(QuoteTermsStrings.title), findsOneWidget);
    for (final line in QuoteTermsStrings.lines) {
      expect(find.text(line), findsOneWidget);
    }
    await tester.ensureVisible(find.text(QuoteTermsStrings.continueLabel));
    await tester.tap(find.text(QuoteTermsStrings.continueLabel));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('acceptTerms:1')));
    expect(find.text(QuoteTermsStrings.title), findsOneWidget);
  });

  testWidgets('tick then Continue stores the acceptance and closes with true', (tester) async {
    await open(tester);
    await tester.ensureVisible(find.text(QuoteTermsStrings.agree));
    await tester.tap(find.text(QuoteTermsStrings.agree));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(QuoteTermsStrings.continueLabel));
    await tester.tap(find.text(QuoteTermsStrings.continueLabel));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(api.calls, contains('acceptTerms:1'));
    expect(hub.termsAccepted, isTrue);
    expect(result, isTrue);
    expect(find.text(QuoteTermsStrings.title), findsNothing);
  });

  testWidgets('a tap outside does not close it', (tester) async {
    await open(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text(QuoteTermsStrings.title), findsOneWidget);
  });

  testWidgets('re-read copy shows the agreed date and no tick', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (c) => ElevatedButton(onPressed: () => QuoteTermsSheet.reRead(c, DateTime.utc(2026, 11, 12, 7)), child: const Text('read'))),
      ),
    ));
    await tester.tap(find.text('read'));
    await tester.pumpAndSettle();
    expect(find.text('You agreed on 12 Nov 2026'), findsOneWidget);
    expect(find.text(QuoteTermsStrings.agree), findsNothing);
  });
}
