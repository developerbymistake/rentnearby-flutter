import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/stay_owner/quotation/controllers/quote_download_controller.dart';
import 'package:bakhli/features/stay_owner/quotation/controllers/quote_form_controller.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_models.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_draft.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_source.dart';
import 'package:bakhli/features/stay_owner/quotation/pdf/quote_engine.dart';
import 'package:bakhli/features/stay_owner/strings/stay_quote_strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'quote_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 11, 27, 10);
  late FakeEngine engine;
  late FakeSource source;
  late QuoteFormController form;
  var offline = false;
  var storageAsked = 0;

  QuoteDownloadController make({QuoteDraft? draft, QuoteUsage? usage}) {
    engine = FakeEngine();
    source = FakeSource(business0: sampleBusiness(), usage0: usage ?? const QuoteUsage(used: 0, limit: 2, canUpgrade: true));
    form = QuoteFormController(initial: draft ?? sampleDraft(), store: memoryStore(timers: TimerLog()), business: sampleBusiness(), ownerId: 'user-1', now: () => now);
    return QuoteDownloadController(
      form: form,
      source: source,
      engine: engine,
      offline: () async => offline,
      askStorage: () async {
        storageAsked++;
        return true;
      },
      now: () => now,
    );
  }

  setUp(() {
    offline = false;
    storageAsked = 0;
  });
  tearDown(Get.reset);

  test('Q12 order of ARCH 8.7: layout, reserve, reservation saved, images, render; real number and approved name on the PDF', () async {
    final dl = make();
    final r = await dl.download();
    expect(r, isA<QuoteDownloadSaved>());
    expect(engine.calls.where((c) => c == 'layout' || c == 'render').toList(), ['layout', 'render']);
    expect(source.log, ['reserve']);
    expect(engine.lastRendered!.toJson()['number'], 'Q-0042');
    expect(engine.lastRendered!.toJson()['businessName'], 'The Banyan Retreat');
    expect(engine.lastRendered!.toJson()['logo'], isTrue);
    expect(engine.lastRendered!.toJson()['signature'], isFalse);
    expect(engine.lastFileName, 'Q-0042_Harshit_Mansi.pdf');
    final res = form.draft.value.reservationFor(QuoteKind.quotation)!;
    expect(res.display, 'Q-0042');
    expect(res.fileUri, isNotNull);
    expect((await form.store.load(form.draft.value.documentId))!.reservation!.fileUri, res.fileUri);
  });

  test('the reservation is on disk before the render runs', () async {
    final dl = make();
    engine.renderFailures.addAll([QuoteEngineFailure.noSpace]);
    final r = await dl.download();
    expect(r, isA<QuoteDownloadMessage>());
    expect((r as QuoteDownloadMessage).message, StayQuoteStrings.noSpace);
    final saved = await form.store.load(form.draft.value.documentId);
    expect(saved!.reservation!.display, 'Q-0042');
    expect(saved.reservation!.fileUri, isNull);
  });

  test('retry after a failed render calls reserve again (Free, same number) and renders', () async {
    final dl = make();
    engine.renderFailures.addAll([QuoteEngineFailure.noSpace]);
    await dl.download();
    source.outcomes.add(QuoteReserved(FakeSource.ok(counted: false)));
    final r = await dl.download();
    expect(r, isA<QuoteDownloadSaved>());
    expect(source.reserves.length, 2);
    expect((r as QuoteDownloadSaved).reservation.display, 'Q-0042');
  });

  test('a killed renderer (RenderFailed) is retried once automatically', () async {
    final dl = make();
    engine.renderFailures.add(QuoteEngineFailure.renderFailed);
    expect(await dl.download(), isA<QuoteDownloadSaved>());
    expect(engine.calls.where((c) => c == 'render').length, 2);
  });

  test('Android 7-9: StorageDenied asks the permission once and renders again', () async {
    final dl = make();
    engine.renderFailures.add(QuoteEngineFailure.storageDenied);
    expect(await dl.download(), isA<QuoteDownloadSaved>());
    expect(storageAsked, 1);
  });

  test('a re-download replaces the earlier file (no "(1)" copies)', () async {
    final dl = make();
    final first = await dl.download() as QuoteDownloadSaved;
    source.outcomes.add(QuoteReserved(FakeSource.ok(counted: false)));
    await dl.download();
    expect(engine.deleted, [first.file.uri]);
  });

  test('Q17 offline: no reserve call, calm line', () async {
    offline = true;
    final dl = make();
    final r = await dl.download();
    expect((r as QuoteDownloadMessage).message, StayQuoteStrings.offlineDownload);
    expect(source.reserves, isEmpty);
    expect(engine.calls, isEmpty);
  });

  test('TooLong from layout stops before any count', () async {
    final dl = make();
    engine.layoutResult = const QuoteLayout(ok: false, pages: 2, fit: 2, reason: 'TooLong');
    final r = await dl.download();
    expect((r as QuoteDownloadMessage).message, StayQuoteStrings.tooLong);
    expect(source.reserves, isEmpty);
  });

  test('invalid form: nothing is called', () async {
    final dl = make(draft: QuoteFormController.blank('doc-00000009', now));
    expect(await dl.download(), isA<QuoteDownloadInvalid>());
    expect(engine.calls, isEmpty);
    expect(source.reserves, isEmpty);
  });

  test('Q14 G1: used = limit opens the sheet locally, without a request', () async {
    final dl = make(usage: const QuoteUsage(used: 2, limit: 2, canUpgrade: true));
    final r = await dl.download();
    expect(r, isA<QuoteDownloadLimit>());
    expect(source.reserves, isEmpty);
  });

  test('Q14 G1: used = limit but the document was reserved 1 h ago -> no sheet, reserve is called', () async {
    final reserved = sampleDraft().withReservation(
      QuoteKind.quotation,
      QuoteReservation(number: 42, display: 'Q-0042', issuedAt: now.subtract(const Duration(hours: 1)), freeUntil: now.add(const Duration(hours: 23)), freeLeft: 4, businessName: 'B'),
    );
    final dl = make(draft: reserved, usage: const QuoteUsage(used: 2, limit: 2, canUpgrade: true));
    source.outcomes.add(QuoteReserved(FakeSource.ok(counted: false, used: 2)));
    expect(await dl.download(), isA<QuoteDownloadSaved>());
    expect(source.reserves.length, 1);
  });

  test('freeUntil in the future never skips the server call', () async {
    final reserved = sampleDraft().withReservation(
      QuoteKind.quotation,
      QuoteReservation(number: 42, display: 'Q-0042', issuedAt: now, freeUntil: now.add(const Duration(hours: 20)), freeLeft: 5, businessName: 'B'),
    );
    final dl = make(draft: reserved);
    await dl.download();
    expect(source.reserves.length, 1);
  });

  test('server limit refusal becomes the limit sheet with the server numbers', () async {
    final dl = make();
    source.outcomes.add(QuoteReserveRefused(const OwnerRefused<dynamic>(
      type: 'QuotationMonthLimit',
      statusCode: 409,
      data: {'key': 'StayQuotationsPerMonth', 'limit': 30, 'used': 30, 'canUpgrade': false},
    )));
    final r = await dl.download() as QuoteDownloadLimit;
    expect(r.limit, 30);
    expect(r.used, 30);
    expect(r.canUpgrade, isFalse);
    expect(engine.calls.contains('render'), isFalse);
  });

  test('a proforma reserves its own kind (G11)', () async {
    final dl = make(draft: sampleDraft(kind: QuoteKind.proforma));
    source.outcomes.add(QuoteReserved(FakeSource.ok(number: 7, kind: QuoteKind.proforma)));
    await dl.download();
    expect(source.reserves.single.$2, QuoteKind.proforma);
    expect(engine.lastFileName, 'PI-0007_Harshit_Mansi.pdf');
  });

  test('a double tap sends one request', () async {
    final dl = make();
    final a = dl.download();
    final b = dl.download();
    await Future.wait([a, b]);
    expect(source.reserves.length, 1);
  });

  test('images are refreshed when the reserve answer carries a newer assets version', () async {
    final dl = make();
    source.outcomes.add(QuoteReserved(FakeSource.ok(assets: 4)));
    await dl.download();
    expect(source.log, ['reserve', 'images:4']);
  });
}
