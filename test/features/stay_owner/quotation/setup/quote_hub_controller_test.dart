import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/stay_owner/quotation/controllers/quote_hub_controller.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_asset_store.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_models.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_source.dart';
import 'package:bakhli/features/stay_owner/strings/stay_quote_setup_strings.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quote_setup_fakes.dart';

class _Harness {
  _Harness({DateTime? now, bool termsOk = true, bool businessSaved = true}) {
    clock = now ?? DateTime.utc(2026, 11, 27, 9);
    store = QuoteAssetStore(engine: engine, api: api, secure: secure, boxes: boxes, clock: () => clock);
    hub = QuoteHubController(
      api: api,
      store: store,
      userId: () => userId,
      clock: () => clock,
      appVersion: () async => '1.2.0',
      termsPrompt: (_, h) async {
        prompts++;
        return termsOk && await h.acceptTerms();
      },
      openBusiness: () async {
        businessOpened++;
        return businessSaved;
      },
      tell: told.add,
    );
  }

  final api = FakeQuoteApi();
  final engine = FakeEngine();
  final secure = MemKeyValue();
  final boxes = MemBoxes();
  late final QuoteAssetStore store;
  late final QuoteHubController hub;
  late DateTime clock;
  String? userId = 'u1';
  int prompts = 0;
  int businessOpened = 0;
  final told = <String>[];
}

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
    ctx = c;
    return const SizedBox.shrink();
  })));
  return ctx;
}

void main() {
  test('load stores the hub in the user cache box and sends the ETag next time', () async {
    final t = _Harness();
    expect(await t.hub.load(), isTrue);
    expect(t.hub.hub.value!.stay.name, 'The Banyan Retreat');
    expect(t.boxes.boxes['quote_cache_u1'], isNotNull);
    expect(await t.hub.load(), isTrue);
    expect(t.api.lastEtag, '"e1"');
  });

  test('304 keeps the cached hub', () async {
    final t = _Harness();
    await t.hub.load();
    t.api.hubResult = const OwnerOk(QuoteHubResponse(notModified: true, etag: '"e1"'));
    expect(await t.hub.load(), isTrue);
    expect(t.hub.hub.value!.usage.used, 1);
    expect(t.hub.fromCache.value, isFalse);
  });

  test('offline: a cached hub is used, a cached count from an older month shows no number (Q17)', () async {
    final first = _Harness(now: DateTime.utc(2026, 10, 20));
    first.api.hubResult = OwnerOk(QuoteHubResponse(notModified: false, hub: QuoteHub.fromJson(hubJson(resetsAt: '2026-10-31T18:30:00Z'))));
    await first.hub.load();
    final cached = first.boxes.boxes['quote_cache_u1']!;

    final t = _Harness(now: DateTime.utc(2026, 11, 2));
    t.boxes.boxes['quote_cache_u1'] = cached;
    t.api.hubResult = const OwnerOffline();
    expect(await t.hub.load(), isTrue);
    expect(t.hub.offline.value, isTrue);
    expect(t.hub.fromCache.value, isTrue);
    expect(t.hub.usage, isNull);
    expect(t.hub.next, isNull);
  });

  test('same-month cache keeps the count', () async {
    final first = _Harness(now: DateTime.utc(2026, 11, 20));
    await first.hub.load();
    final t = _Harness(now: DateTime.utc(2026, 11, 21));
    t.boxes.boxes['quote_cache_u1'] = first.boxes.boxes['quote_cache_u1']!;
    t.api.hubResult = const OwnerOffline();
    await t.hub.load();
    expect(t.hub.usage?.used, 1);
  });

  testWidgets('first open: terms sheet, then Business details, then in (G5)', (tester) async {
    final t = _Harness();
    t.api.hubResult = OwnerOk(QuoteHubResponse(notModified: false, hub: QuoteHub.fromJson(hubJson(profile: false, acceptedVersion: null))));
    final ctx = await _context(tester);
    expect(await tester.runAsync(() => t.hub.ensureReady(ctx)), isTrue);
    expect(t.prompts, 1);
    expect(t.api.calls, contains('acceptTerms:1'));
    expect(t.businessOpened, 1);
    expect(t.hub.termsAccepted, isTrue);
  });

  testWidgets('accepted terms: no sheet, no Business details', (tester) async {
    final t = _Harness();
    final ctx = await _context(tester);
    expect(await tester.runAsync(() => t.hub.ensureReady(ctx)), isTrue);
    expect(t.prompts, 0);
    expect(t.businessOpened, 0);
  });

  testWidgets('terms refused or Business details left: leave the feature', (tester) async {
    final no = _Harness(termsOk: false);
    no.api.hubResult = OwnerOk(QuoteHubResponse(notModified: false, hub: QuoteHub.fromJson(hubJson(profile: false, acceptedVersion: null))));
    final ctx = await _context(tester);
    expect(await tester.runAsync(() => no.hub.ensureReady(ctx)), isFalse);
    expect(no.businessOpened, 0);

    final back = _Harness(businessSaved: false);
    back.api.hubResult = no.api.hubResult;
    expect(await tester.runAsync(() => back.hub.ensureReady(ctx)), isFalse);
  });

  testWidgets('offline first open asks for a connection once', (tester) async {
    final t = _Harness();
    t.api.hubResult = const OwnerOffline();
    final ctx = await _context(tester);
    expect(await tester.runAsync(() => t.hub.ensureReady(ctx)), isFalse);
    expect(t.told, [QuoteSetupStrings.connectOnce]);
  });

  testWidgets('stay not approved and an old app are refused calmly', (tester) async {
    final t = _Harness();
    t.api.hubResult = OwnerOk(QuoteHubResponse(notModified: false, hub: QuoteHub.fromJson(hubJson(approved: false))));
    final ctx = await _context(tester);
    expect(await tester.runAsync(() => t.hub.ensureReady(ctx)), isFalse);
    expect(t.told.last, QuoteSetupStrings.notApproved);

    final old = _Harness();
    expect(await tester.runAsync(() => old.hub.ensureReady(ctx, appTemplateVersion: 0)), isFalse);
    expect(old.told.last, QuoteSetupStrings.updateApp);
  });

  test('terms version refused by the server asks for an update', () async {
    final t = _Harness();
    await t.hub.load();
    t.api.termsResult = const OwnerRefused(type: 'QuoteTermsVersionUnknown', statusCode: 400);
    expect(await t.hub.acceptTerms(), isFalse);
    expect(t.told.last, QuoteSetupStrings.updateApp);
  });

  test('reserve result refreshes the count and the next number', () async {
    final t = _Harness();
    await t.hub.load();
    t.hub.applyReserve(const QuoteReserveResult(
      number: 42,
      display: 'Q-0042',
      kind: QuoteKind.quotation,
      counted: true,
      usage: QuoteUsage(used: 2, limit: 2, canUpgrade: true),
      businessName: 'The Banyan Retreat',
      assetsVersion: 3,
    ));
    expect(t.hub.usage!.used, 2);
    expect(t.hub.next!.quotation, 43);
    expect(t.hub.next!.proforma, 7);
  });

  test('another user never sees the first user cache', () async {
    final t = _Harness();
    await t.hub.load();
    final other = _Harness()..userId = 'u2';
    other.boxes.boxes.addAll(t.boxes.boxes);
    other.api.hubResult = const OwnerOffline();
    expect(await other.hub.load(), isFalse);
    expect(other.hub.hub.value, isNull);
  });

  testWidgets('B1 ensureReady sends If-None-Match on every entry and applies a new usage', (tester) async {
    final t = _Harness();
    final ctx = await _context(tester);
    expect(await tester.runAsync(() => t.hub.ensureReady(ctx)), isTrue);
    final first = t.api.calls.where((c) => c == 'hub').length;
    t.api.hubResult = OwnerOk(QuoteHubResponse(notModified: false, etag: '"e2"', hub: QuoteHub.fromJson(hubJson(used: 3, limit: 30))));
    expect(await tester.runAsync(() => t.hub.ensureReady(ctx)), isTrue);
    expect(t.api.calls.where((c) => c == 'hub').length, first + 1);
    expect(t.api.lastEtag, '"e1"');
    expect(t.hub.usage!.limit, 30);
    expect(t.hub.usage!.used, 3);
  });

  test('B1 a plan change on /plans/me forces a hub reload without the ETag', () async {
    final t = _Harness();
    await t.hub.load();
    t.hub.onPlanChanged(const MyPlanModel(limits: PlanLimitsModel(quotationsPerMonth: 2)));
    final before = t.api.calls.where((c) => c == 'hub').length;
    t.hub.onPlanChanged(const MyPlanModel(limits: PlanLimitsModel(quotationsPerMonth: 2, quotationsUsed: 1)));
    expect(t.api.calls.where((c) => c == 'hub').length, before);
    t.api.hubResult = OwnerOk(QuoteHubResponse(notModified: false, etag: '"e3"', hub: QuoteHub.fromJson(hubJson(used: 2, limit: 30))));
    t.hub.onPlanChanged(const MyPlanModel(planId: 'plus', isPaid: true, limits: PlanLimitsModel(quotationsPerMonth: 30)));
    await Future<void>.delayed(Duration.zero);
    await t.hub.load();
    expect(t.api.calls.where((c) => c == 'hub').length, greaterThan(before));
    expect(t.hub.usage!.limit, 30);
  });

  test('I4 a month-limit refusal copies the server numbers into the hub', () async {
    final t = _Harness();
    await t.hub.load();
    t.api.reserveResult = const OwnerRefused<QuoteReserveResult>(
      type: 'QuotationMonthLimit',
      statusCode: 409,
      data: {'key': 'StayQuotationsPerMonth', 'limit': 2, 'used': 7, 'canUpgrade': true, 'resetsAt': '2026-11-30T18:30:00Z'},
    );
    final out = await AppQuoteSource(hub: t.hub).reserve('doc-1', QuoteKind.quotation);
    expect(out, isA<QuoteReserveRefused>());
    expect(t.hub.usage!.used, 7);
    expect(t.hub.usage!.limit, 2);
    expect(t.hub.savedAt, t.clock);
  });

  testWidgets('I3 feature entry fetches a missing logo back (logout, reinstall, second phone)', (tester) async {
    final t = _Harness();
    t.api.hubResult = OwnerOk(QuoteHubResponse(notModified: false, etag: '"e1"', hub: QuoteHub.fromJson(hubJson(hasLogo: true))));
    final ctx = await _context(tester);
    expect(await tester.runAsync(() => t.hub.ensureReady(ctx)), isTrue);
    await tester.runAsync(() => t.hub.fetchMissingImages());
    expect(t.api.calls, contains('image:logo'));
    expect(t.engine.calls, contains('putImage:u1:logo:3'));
  });
}
