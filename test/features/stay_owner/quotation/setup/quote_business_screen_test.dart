import 'package:bakhli/features/stay_owner/quotation/controllers/quote_hub_controller.dart';
import 'package:bakhli/features/stay_owner/quotation/controllers/quote_image_controller.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_asset_store.dart';
import 'package:bakhli/features/stay_owner/quotation/screens/quote_business_screen.dart';
import 'package:bakhli/features/stay_owner/strings/stay_quote_setup_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'quote_setup_fakes.dart';

void main() {
  late FakeQuoteApi api;
  late QuoteHubController hub;
  Object? popped;

  Future<void> pump(WidgetTester tester) async {
    api = FakeQuoteApi();
    hub = QuoteHubController(api: api, store: QuoteAssetStore(engine: FakeEngine(), api: api, secure: MemKeyValue(), boxes: MemBoxes()), userId: () => 'u1');
    await tester.runAsync(hub.load);
    popped = null;
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(GetMaterialApp(
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async => popped = await Navigator.of(c).push<Object?>(
                MaterialPageRoute(builder: (_) => QuoteBusinessScreen(args: const {}, hub: hub, images: QuoteImageController(hub: hub, isOffline: () async => false))),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
  }

  testWidgets('the approved stay name is shown locked, with the admin line (Q5)', (tester) async {
    await pump(tester);
    expect(find.text('The Banyan Retreat'), findsOneWidget);
    expect(find.text(QuoteSetupStrings.nameLocked), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
    expect(find.widgetWithText(EditableText, 'The Banyan Retreat'), findsNothing);
  });

  testWidgets('Request change opens the admin request sheet', (tester) async {
    await pump(tester);
    await tester.ensureVisible(find.text(QuoteSetupStrings.requestChange));
    await tester.tap(find.text(QuoteSetupStrings.requestChange));
    await tester.pumpAndSettle();
    expect(find.text(QuoteSetupStrings.nameSheetTitle), findsOneWidget);
    expect(find.text(QuoteSetupStrings.nameSheetSub), findsOneWidget);
    expect(find.text(QuoteSetupStrings.sendRequest), findsOneWidget);
  });

  testWidgets('fields come from the saved profile and Save sends PUT /profile', (tester) async {
    await pump(tester);
    expect(find.text('Riverside stays'), findsOneWidget);
    expect(find.text('05ABCDE1234F1Z6'), findsOneWidget);
    await tester.enterText(find.text('Riverside stays'), 'On the river');
    await tester.tap(find.text(QuoteSetupStrings.save));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(api.calls, contains('saveProfile'));
    expect(api.bodies.last['slogan'], 'On the river');
    expect(api.bodies.last.containsKey('name'), isFalse);
    expect(popped, isTrue);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
