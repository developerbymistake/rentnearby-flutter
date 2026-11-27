import 'dart:convert';
import 'dart:typed_data';

import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_asset_store.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quote_setup_fakes.dart';

void main() {
  late FakeQuoteApi api;
  late FakeEngine engine;
  late MemKeyValue secure;
  late MemBoxes boxes;
  late QuoteAssetStore store;

  setUp(() {
    api = FakeQuoteApi();
    engine = FakeEngine();
    secure = MemKeyValue();
    boxes = MemBoxes();
    store = QuoteAssetStore(engine: engine, api: api, secure: secure, boxes: boxes, clock: () => DateTime.utc(2026, 11, 27));
  });

  test('hub cache lives in the per-user box and holds no bank value', () async {
    await store.writeHub('u1', hubOf(), etag: '"e1"');
    final raw = jsonEncode(boxes.boxes['quote_cache_u1']);
    for (final secret in ['4521', 'SBIN0001234', 'ba***@sbi', 'banyan@sbi', '123456784521']) {
      expect(raw, isNot(contains(secret)), reason: secret);
    }
    final back = await store.readHub('u1');
    expect(back!.etag, '"e1"');
    expect(back.savedAt, DateTime.utc(2026, 11, 27));
    expect(await store.readHub('u2'), isNull);
  });

  test('full bank only in secure storage, keyed by user, tied to the profile time', () async {
    final stamp = DateTime.utc(2026, 11, 27, 8);
    await store.writeBank('u1', sampleBank, stamp: stamp);
    expect(secure.values.keys.toList(), ['quote_bank_u1']);
    expect(boxes.boxes, isEmpty);
    expect(await store.readBank('u1', stamp: stamp), sampleBank);
    expect(await store.readBank('u1', stamp: DateTime.utc(2026, 11, 28)), isNull);
    expect(await store.readBank('u2'), isNull);
    await store.writeBank('u1', null);
    expect(secure.values, isEmpty);
  });

  test('bank(): a stale copy fetches once and refreshes the copy', () async {
    final stamp = DateTime.utc(2026, 11, 27, 8);
    final r = await store.bank('u1', stamp: stamp);
    expect((r as OwnerOk<QuoteBank?>).value, sampleBank);
    expect(api.calls, ['bank']);
    await store.bank('u1', stamp: stamp);
    expect(api.calls, ['bank']);
  });

  test('only server JPEG bytes up to 200 KB reach the phone store', () async {
    expect(await store.fetchImage('u1', QuoteImageKind.logo, 4), isTrue);
    expect(engine.calls, ['putImage:u1:logo:4']);

    api.imageResult = OwnerOk(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]));
    expect(await store.fetchImage('u1', QuoteImageKind.logo, 5), isFalse);

    final big = Uint8List(QuoteAssetStore.maxImageBytes + 1)..setAll(0, [0xFF, 0xD8, 0xFF]);
    api.imageResult = OwnerOk(big);
    expect(await store.fetchImage('u1', QuoteImageKind.logo, 6), isFalse);

    api.imageResult = const OwnerRefused(type: null, statusCode: 404);
    expect(await store.fetchImage('u1', QuoteImageKind.signature, 7), isFalse);
    expect(engine.calls, ['putImage:u1:logo:4']);
  });

  test('ensureImages fetches only the images the profile has', () async {
    await store.ensureImages('u1', hubOf(hasLogo: true).profile, assetsVersion: 9);
    expect(api.calls, ['image:logo']);
    expect(engine.calls, ['putImage:u1:logo:9']);
    await store.ensureImages('u1', null);
    expect(api.calls, ['image:logo']);
  });
}
