import 'dart:io';

import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/stay_owner/quotation/controllers/quote_hub_controller.dart';
import 'package:bakhli/features/stay_owner/quotation/controllers/quote_image_controller.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_asset_store.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_models.dart';
import 'package:bakhli/features/stay_owner/strings/stay_quote_setup_strings.dart';
import 'package:bakhli/utils/photo_upload/profile_photo_crop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quote_setup_fakes.dart';

void main() {
  late FakeQuoteApi api;
  late FakeEngine engine;
  late QuoteHubController hub;
  late List<String> said;
  late List<PhotoCropShape> shapes;
  late Directory tmp;

  QuoteImageController make({bool offline = false, File? picked}) => QuoteImageController(
        hub: hub,
        pick: (_, shape) async {
          shapes.add(shape);
          return picked;
        },
        isOffline: () async => offline,
        tell: said.add,
      );

  setUp(() async {
    api = FakeQuoteApi();
    engine = FakeEngine();
    said = [];
    shapes = [];
    tmp = Directory.systemTemp.createTempSync('quote_img');
    engine
      ..root = '${tmp.path}/store'
      ..writeFiles = true;
    hub = QuoteHubController(api: api, store: QuoteAssetStore(engine: engine, api: api, secure: MemKeyValue(), boxes: MemBoxes()), userId: () => 'u1');
    await hub.load();
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('logo crops square, stamp or signature crops free', () {
    expect(QuoteImageController.shapeOf(QuoteImageKind.logo), PhotoCropShape.square);
    expect(QuoteImageController.shapeOf(QuoteImageKind.signature), PhotoCropShape.free);
  });

  testWidgets('upload: multipart put, new version, stripped bytes fetched back, local crop deleted', (tester) async {
    final crop = File('${tmp.path}/crop.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 1]);
    final c = make(picked: crop);
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (b) {
      ctx = b;
      return const SizedBox.shrink();
    })));
    await tester.runAsync(() => c.change(ctx, QuoteImageKind.logo));
    expect(shapes, [PhotoCropShape.square]);
    expect(api.calls, containsAllInOrder(['putImage:logo', 'image:logo']));
    expect(engine.calls, ['putImage:u1:logo:4']);
    expect(hub.hub.value!.profile!.hasLogo, isTrue);
    expect(hub.hub.value!.profile!.assetsVersion, 4);
    expect(crop.existsSync(), isFalse);
    expect(c.busy.value, isNull);
    expect(c.paths[QuoteImageKind.logo], endsWith('logo_4.jpg'));
  });

  test('refusals show calm lines and change nothing', () async {
    final c = make();
    final f = File('${tmp.path}/a.jpg')..writeAsBytesSync([1]);
    api.imagePutResult = const OwnerRefused(type: 'PhotoTooLarge', statusCode: 400);
    expect(await c.upload(QuoteImageKind.logo, f), isFalse);
    api.imagePutResult = const OwnerRefused(type: 'PhotoInvalid', statusCode: 400);
    expect(await c.upload(QuoteImageKind.logo, f), isFalse);
    api.imagePutResult = const OwnerFailed(message: 'busy');
    expect(await c.upload(QuoteImageKind.logo, f), isFalse);
    expect(said, [QuoteSetupStrings.imageTooLarge, QuoteSetupStrings.imageInvalid, QuoteSetupStrings.imageBusy]);
    expect(hub.hub.value!.profile!.hasLogo, isFalse);
    expect(engine.calls, isEmpty);
  });

  test('offline upload is refused before any call', () async {
    final c = make(offline: true);
    expect(await c.upload(QuoteImageKind.signature, File('${tmp.path}/x.jpg')), isFalse);
    expect(api.calls.where((x) => x.startsWith('putImage')), isEmpty);
    expect(said, [QuoteSetupStrings.offline]);
  });

  test('remove clears the image and bumps the version', () async {
    final c = make();
    expect(await c.remove(QuoteImageKind.logo), isTrue);
    expect(api.calls, contains('deleteImage:logo'));
    expect(hub.hub.value!.profile!.hasLogo, isFalse);
    expect(hub.hub.value!.profile!.assetsVersion, 5);
  });
}
