import 'dart:io';
import 'dart:typed_data';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_stay_owner.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/plan/plan_bindings.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/stay/setup/stay_basic_details_screen.dart';
import 'package:bakhli/features/stay/setup/stay_repository.dart';
import 'package:bakhli/features/stay/setup/stay_setup_controller.dart';
import 'package:bakhli/repositories/plan_repository.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/real_phone.dart';
import 'stay_setup_fixtures.dart';

class _Api implements HttpClientAdapter {
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    return ResponseBody.fromString('{"data": {"photoId": "p1", "photoUrl": "https://x.test/n.jpg"}}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

class _PhotoRepo extends FakeStayRepo {
  _PhotoRepo(super.model);

  final List<String> replaced = [];
  final List<String> replacePaths = [];
  final List<String> deleted = [];
  int uploads = 0;
  int replaceCalls = 0;
  Object? replaceError;

  @override
  Future<void> uploadPhoto(String filePath, {void Function(int, int)? onProgress}) async => uploads++;

  @override
  Future<void> replacePhoto(String photoId, String filePath, {void Function(int, int)? onProgress}) async {
    replaceCalls++;
    if (replaceError != null) throw replaceError!;
    replaced.add(photoId);
    replacePaths.add(filePath);
  }

  @override
  Future<void> deletePhoto(String photoId) async => deleted.add(photoId);
}

class _Picker extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({required ImageSource source, ImagePickerOptions options = const ImagePickerOptions()}) async =>
      XFile('assets/images/design/hotel/hotel_1.png');
}

DioException _network() => DioException(requestOptions: RequestOptions(path: '/stays/me/photos/p1'), type: DioExceptionType.connectionError);

const _off = {
  'paymentEnabled': false,
  'limits': {'photos': 8, 'roomTypes': 6},
};

_PhotoRepo _setUpScreen() {
  final c = setupFor(stayModel(draftJson(step1: true, photos: 3)));
  final repo = _PhotoRepo(c.stay.value);
  Get.delete<StaySetupController>(force: true);
  final ctrl = StaySetupController(repo: repo);
  Get.put<StaySetupController>(ctrl);
  ctrl.stay.value = repo.model;
  ctrl.hasLoaded.value = true;
  PlanGate.debugPlan = null;
  Get.put<PlanRepository>(FakePlanRepository([_off]), permanent: true);
  return repo;
}

Future<void> _pumpScreen(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(t, const StayBasicDetailsScreen(photosOnly: true), size: const Size(360, 1500), toastHost: true);
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 100));
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _changeSecond(WidgetTester t) async {
  await t.tap(find.text('Change').at(1));
  await _settle(t);
  expect(find.text('Change Photo'), findsOneWidget);
  await t.tap(find.text('Choose from Gallery'));
  await _settle(t);
  for (var i = 0; i < 6; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump(const Duration(milliseconds: 50));
  }
  await _settle(t);
}

Future<void> _clear(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 15));
}

Future<void> _pumpTile(WidgetTester t, PhotoTile3D tile, {double scale = 1.0, double width = 320}) async {
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(
    t,
    Scaffold(body: Padding(padding: const EdgeInsets.all(24), child: Align(alignment: Alignment.topLeft, child: SizedBox.square(dimension: 80, child: tile)))),
    size: Size(width, 640),
    textScale: scale,
  );
  await t.pump();
}

void main() {
  setUpAll(() => initTestStorage('stay_photo_replace'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanBindings.dispose();
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  test('StayRepository.replacePhoto puts multipart photo to /stays/me/photos/{id}', () async {
    final file = File('${Directory.systemTemp.createTempSync('stay_replace').path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    ApiService.init();
    final api = _Api();
    ApiService.dio.httpClientAdapter = api;
    await const StayRepository().replacePhoto('p1', file.path);
    expect(api.seen.single.method, 'PUT');
    expect(api.seen.single.path, '/stays/me/photos/p1');
    expect((api.seen.single.data as FormData).files.single.key, 'photo');
  });

  group('StaySetupController.replacePhoto', () {
    test('calls the repo with the id and path', () async {
      final repo = _PhotoRepo(null);
      final c = StaySetupController(repo: repo);
      expect(await c.replacePhoto('p2', '/tmp/b.jpg'), isTrue);
      expect(repo.replaced, ['p2']);
      expect(repo.replacePaths, ['/tmp/b.jpg']);
    });

    test('network error is retried 3 times, then false with the error read and no toast', () async {
      final repo = _PhotoRepo(null)..replaceError = _network();
      final c = StaySetupController(repo: repo);
      expect(await c.replacePhoto('p2', '/tmp/b.jpg'), isFalse);
      expect(repo.replaceCalls, 3);
      expect(c.lastNetwork, isTrue);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('a server error is read into lastErrorType after one attempt', () async {
      final repo = _PhotoRepo(null)
        ..replaceError = DioException(
          requestOptions: RequestOptions(path: '/stays/me/photos/p2'),
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: RequestOptions(path: '/stays/me/photos/p2'), statusCode: 404, data: {
            'error': {'type': 'NotFound', 'message': 'Photo not found'},
          }),
        );
      final c = StaySetupController(repo: repo);
      expect(await c.replacePhoto('p2', '/tmp/b.jpg'), isFalse);
      expect(repo.replaceCalls, 1);
      expect(c.lastErrorType, 'NotFound');
    });
  });

  for (final approved in [false, true]) {
    group(approved ? 'approved scale' : 'identity scale', () {
      setUp(() => approved ? DS.applyApproved() : DS.debugReset());
      tearDown(DS.debugReset);

      testWidgets('PhotoTile3D shows Change only with onChange, both taps fire', (t) async {
        var changes = 0, removes = 0;
        await _pumpTile(t, PhotoTile3D(image: const ColoredBox(color: Colors.grey), onRemove: () => removes++));
        expect(find.text('Change'), findsNothing);
        await _pumpTile(t, PhotoTile3D(image: const ColoredBox(color: Colors.grey), onRemove: () => removes++, onChange: () => changes++));
        expect(find.text('Change'), findsOneWidget);
        await t.tap(find.text('Change'));
        await t.tap(find.byTooltip('Remove photo'));
        expect(changes, 1);
        expect(removes, 1);
      });

      for (final width in [320.0, 360.0, 411.0]) {
        for (final scale in [1.0, 1.3]) {
          testWidgets('PhotoTile3D 80 px at $width @$scale: no overflow, Change and remove do not overlap', (t) async {
            await _pumpTile(t, PhotoTile3D(image: const ColoredBox(color: Colors.grey), coverLabel: 'Cover', onRemove: () {}, onChange: () {}), scale: scale, width: width);
            expect(t.takeException(), isNull);
            final change = t.getRect(find.ancestor(of: find.text('Change'), matching: find.byType(Tap3D)).first);
            final remove = t.getRect(find.byTooltip('Remove photo'));
            expect(change.overlaps(remove), isFalse, reason: '$change vs $remove');
          });
        }
      }

      testWidgets('change the second of three photos and Save: one replace, no upload, no delete, order kept', (t) async {
        ImagePickerPlatform.instance = _Picker();
        final repo = _setUpScreen();
        await _pumpScreen(t);
        expect(find.byType(PhotoTile3D), findsNWidgets(3));
        expect(find.text('Change'), findsNWidgets(3));
        await _changeSecond(t);
        final tiles = t.widgetList<PhotoTile3D>(find.byType(PhotoTile3D)).toList();
        expect(tiles.length, 3);
        expect(tiles[0].coverLabel, isNotNull);
        expect(tiles[0].image, isNot(isA<Image>()));
        expect(tiles[1].image, isA<Image>());
        expect((tiles[1].image as Image).image, isA<ResizeImage>());
        expect(tiles[2].image, isNot(isA<Image>()));
        await t.tap(find.text('Save'));
        await _settle(t);
        expect(repo.replaced, ['p1']);
        expect(repo.uploads, 0);
        expect(repo.deleted, isEmpty);
        await _clear(t);
      });

      testWidgets('change then remove the same tile: one delete, no replace', (t) async {
        ImagePickerPlatform.instance = _Picker();
        final repo = _setUpScreen();
        await _pumpScreen(t);
        await _changeSecond(t);
        await t.tap(find.byTooltip('Remove photo').at(1));
        await t.pump();
        expect(find.byType(PhotoTile3D), findsNWidgets(2));
        await t.tap(find.text('Save'));
        await _settle(t);
        expect(repo.deleted, ['p1']);
        expect(repo.replaceCalls, 0);
        expect(repo.uploads, 0);
        await _clear(t);
      });
    });
  }
}
