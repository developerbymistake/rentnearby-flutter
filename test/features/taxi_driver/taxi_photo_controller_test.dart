import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/session/owner_session_hooks.dart';
import 'package:bakhli/features/taxi/models/taxi_owner_model.dart';
import 'package:bakhli/features/taxi/setup/taxi_repository.dart';
import 'package:bakhli/features/taxi/setup/taxi_setup_controller.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;

import '../../support/owner_fakes.dart';
import 'core/taxi_fixtures.dart';

class _Api implements HttpClientAdapter {
  _Api(this.reply);
  final String reply;
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    return ResponseBody.fromString(reply, 201, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

DioException _network() => DioException(requestOptions: RequestOptions(path: '/taxis/me/display-photo'), type: DioExceptionType.connectionError);

DioException _server(int code, String type, String message) => DioException(
      requestOptions: RequestOptions(path: '/taxis/me/plate-photo'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/taxis/me/plate-photo'),
        statusCode: code,
        data: {
          'success': false,
          'error': {'type': type, 'message': message},
        },
      ),
    );

class _Repo extends TaxiRepository {
  _Repo();

  int displayCalls = 0;
  int plateCalls = 0;
  int loads = 0;
  final List<String> paths = [];
  Object? displayError;
  Object? plateError;
  Completer<void>? hold;
  TaxiOwnerModel? mine;

  @override
  Future<TaxiOwnerModel?> getMine() async {
    loads++;
    return mine;
  }

  @override
  Future<TaxiPhotoResult> uploadDisplayPhoto(String filePath, {void Function(int, int)? onProgress}) async {
    displayCalls++;
    paths.add(filePath);
    final h = hold;
    if (h != null) await h.future;
    if (displayError != null) throw displayError!;
    return const TaxiPhotoResult(photoUrl: 'https://res.cloudinary.com/x/new.jpg');
  }

  @override
  Future<TaxiPhotoResult> uploadPlatePhoto(String filePath, {void Function(int, int)? onProgress}) async {
    plateCalls++;
    if (plateError != null) throw plateError!;
    return const TaxiPhotoResult(photoUrl: 'https://res.cloudinary.com/x/plate.jpg', status: 'PendingReview');
  }
}

TaxiSetupController _ctrl(_Repo repo) {
  Get.reset();
  Get.testMode = true;
  return TaxiSetupController(repo: repo);
}

void main() {
  setUpAll(() => initTestStorage('taxi_photo_controller'));
  tearDown(resetOwnerTestState);

  group('TaxiRepository.uploadDisplayPhoto', () {
    late File file;
    setUp(() {
      file = File('${Directory.systemTemp.createTempSync('taxi_display').path}/taxi.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);
      ApiService.init();
    });

    Future<(TaxiPhotoResult, _Api)> run(String reply) async {
      final api = _Api(reply);
      ApiService.dio.httpClientAdapter = api;
      return (await const TaxiRepository().uploadDisplayPhoto(file.path), api);
    }

    test('posts multipart to /taxis/me/display-photo and reads displayPhotoUrl', () async {
      final (res, api) = await run('{"data": {"displayPhotoUrl": "https://res.cloudinary.com/x/d.jpg"}}');
      expect(api.seen.single.method, 'POST');
      expect(api.seen.single.path, '/taxis/me/display-photo');
      final form = api.seen.single.data as FormData;
      expect(form.files.single.key, 'photo');
      expect(res.photoUrl, 'https://res.cloudinary.com/x/d.jpg');
      expect(res.status, isNull);
    });

    test('falls back to photoUrl', () async {
      final (res, _) = await run('{"data": {"photoUrl": "https://res.cloudinary.com/x/p.jpg"}}');
      expect(res.photoUrl, 'https://res.cloudinary.com/x/p.jpg');
    });

    test('a non-map data gives an empty result', () async {
      for (final reply in ['{"data": "x"}', '{"data": null}', '{"data": [1]}', '{}']) {
        final (res, _) = await run(reply);
        expect(res.photoUrl, isNull, reason: reply);
      }
    });
  });

  group('TaxiSetupController.uploadDisplayPhoto', () {
    test('success with reload calls the repo once and loads', () async {
      final repo = _Repo();
      final c = _ctrl(repo);
      final res = await c.uploadDisplayPhoto('/tmp/a.jpg');
      expect(res?.photoUrl, 'https://res.cloudinary.com/x/new.jpg');
      expect(repo.displayCalls, 1);
      expect(repo.paths.single, '/tmp/a.jpg');
      expect(repo.loads, 1);
      expect(c.displayUploading.value, isFalse);
    });

    test('success without reload does not load', () async {
      final repo = _Repo();
      final c = _ctrl(repo);
      final res = await c.uploadDisplayPhoto('/tmp/a.jpg', reload: false);
      expect(res, isNotNull);
      expect(repo.loads, 0);
      expect(c.displayUploading.value, isFalse);
    });

    test('network error: 3 attempts then null', () async {
      final repo = _Repo()..displayError = _network();
      final c = _ctrl(repo);
      final res = await c.uploadDisplayPhoto('/tmp/a.jpg');
      expect(res, isNull);
      expect(repo.displayCalls, 3);
      expect(c.displayUploading.value, isFalse);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('non-network error: 1 attempt then null', () async {
      final repo = _Repo()..displayError = _server(400, 'Validation', 'Photo size must not exceed 10MB');
      final c = _ctrl(repo);
      expect(await c.uploadDisplayPhoto('/tmp/a.jpg'), isNull);
      expect(repo.displayCalls, 1);
      expect(c.lastErrorMessage, 'Photo size must not exceed 10MB');
      expect(c.displayUploading.value, isFalse);
    });

    test('a second call while the first runs returns null without calling the repo', () async {
      final repo = _Repo()..hold = Completer<void>();
      final c = _ctrl(repo);
      final first = c.uploadDisplayPhoto('/tmp/a.jpg');
      await Future<void>.delayed(Duration.zero);
      expect(c.displayUploading.value, isTrue);
      expect(await c.uploadDisplayPhoto('/tmp/b.jpg'), isNull);
      expect(repo.displayCalls, 1);
      repo.hold!.complete();
      expect(await first, isNotNull);
      expect(c.displayUploading.value, isFalse);
    });
  });

  test('uploadPlatePhoto 409 TaxiProofLocked returns null with the type set, one attempt', () async {
    final repo = _Repo()..plateError = _server(409, TaxiSetupController.proofLockedType, 'Your number plate photo is verified and cannot be changed.');
    final c = _ctrl(repo);
    expect(await c.uploadPlatePhoto('/tmp/p.jpg'), isNull);
    expect(c.lastErrorType, TaxiSetupController.proofLockedType);
    expect(repo.plateCalls, 1);
  });

  test('clear resets taxi, hasLoaded and displayUploading', () {
    final c = _ctrl(_Repo());
    c.taxi.value = TaxiOwnerModel.fromJson(taxiJson()..['displayPhotoUrl'] = 'https://x.test/d.jpg');
    c.hasLoaded.value = true;
    c.displayUploading.value = true;
    c.clear();
    expect(c.taxi.value, isNull);
    expect(c.hasLoaded.value, isFalse);
    expect(c.displayUploading.value, isFalse);
  });

  test('logout wipe removes the cached taxi with both photo urls', () async {
    OwnerCache.write('user-a', OwnerCacheKeys.listing, taxiJson()
      ..['platePhotoUrl'] = 'https://x.test/plate.jpg'
      ..['displayPhotoUrl'] = 'https://x.test/display.jpg');
    expect(OwnerCache.read('user-a', OwnerCacheKeys.listing)?['displayPhotoUrl'], 'https://x.test/display.jpg');
    await OwnerSessionHooks.onLogout(LogoutReason.explicitLogout, 'user-a');
    expect(OwnerCache.read('user-a', OwnerCacheKeys.listing), isNull);
  });
}
