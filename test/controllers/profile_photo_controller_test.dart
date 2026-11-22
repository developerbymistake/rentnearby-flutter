import 'dart:async';
import 'dart:io';

import 'package:bakhli/config/profile_photo_strings.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/profile_photo_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/owner_fakes.dart';
import '../support/real_phone.dart';

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

Map<String, dynamic> _userJson(String id, String? url) => {
      'id': id,
      'phoneNumber': '9876543210',
      'createdAt': '2026-11-22T10:00:00Z',
      'roleConfirmed': true,
      'profilePhotoUrl': url,
    };

class _Fake {
  final sent = <String>[];
  Completer<Map<String, dynamic>>? hold;
  Object? error;
  String nextUrl = 'https://res.cloudinary.com/x/new.jpg';
  bool offline = false;
  int picks = 0;
  File? pickResult;
  List<(int, int)> progress = const [];

  Future<File?> pick(BuildContext _) async {
    picks++;
    return pickResult;
  }

  Future<Map<String, dynamic>> send(String path, void Function(int, int) onProgress) async {
    sent.add(path);
    for (final p in progress) {
      onProgress(p.$1, p.$2);
    }
    final h = hold;
    if (h != null) return h.future;
    final e = error;
    if (e != null) throw e;
    return {'data': _userJson('u1', nextUrl)};
  }

  Future<bool> isOffline() async => offline;

  ProfilePhotoController controller() => ProfilePhotoController(pick: pick, send: send, offline: isOffline);
}

File _tempFile(String name) {
  final dir = Directory.systemTemp.createTempSync('dp_ctrl');
  return File('${dir.path}/$name')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);
}

late _Auth _auth;

Future<BuildContext> _host(WidgetTester t) async {
  late BuildContext ctx;
  await pumpPhone(t, Builder(builder: (c) {
    ctx = c;
    return const SizedBox();
  }), toastHost: true);
  return ctx;
}

Future<void> _toast(WidgetTester t) async {
  await t.pump();
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> _drainToasts(WidgetTester t) async {
  await t.pump(const Duration(seconds: 5));
  await t.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() async {
    await initTestStorage('dp_ctrl');
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() {
    Get.testMode = true;
    Get.put<TabConfigController>(FakeTabs());
    _auth = _Auth();
    Get.put<AuthController>(_auth);
    _auth.user.value = UserModel.fromJson(_userJson('u1', 'https://res.cloudinary.com/x/old.jpg'));
  });

  tearDown(Get.reset);

  testWidgets('change: success applies the returned user, clears the local file and toasts Photo updated', (t) async {
    final ctx = await _host(t);
    final f = _Fake()..pickResult = _tempFile('a.jpg');
    final c = Get.put(f.controller());
    await c.change(ctx);
    await _toast(t);
    expect(f.sent, [f.pickResult!.path]);
    expect(_auth.user.value!.profilePhotoUrl, 'https://res.cloudinary.com/x/new.jpg');
    expect(c.localPath.value, isNull);
    expect(c.placeholderPath, f.pickResult!.path);
    expect(c.busy.value, isFalse);
    expect(c.failed.value, isFalse);
    expect(find.text(ProfilePhotoStrings.updated), findsOneWidget);
    await _drainToasts(t);
  });

  testWidgets('failure keeps the old url, sets failed and retry sends the same file', (t) async {
    final ctx = await _host(t);
    final f = _Fake()
      ..pickResult = _tempFile('b.jpg')
      ..error = Exception('500');
    final c = Get.put(f.controller());
    await c.change(ctx);
    await _toast(t);
    expect(_auth.user.value!.profilePhotoUrl, 'https://res.cloudinary.com/x/old.jpg');
    expect(c.failed.value, isTrue);
    expect(c.localPath.value, f.pickResult!.path);
    expect(find.text(ProfilePhotoStrings.updateFailed), findsOneWidget);
    await _drainToasts(t);

    f.error = null;
    await c.retryChange();
    await _toast(t);
    expect(f.sent, [f.pickResult!.path, f.pickResult!.path]);
    expect(f.picks, 1);
    expect(c.failed.value, isFalse);
    expect(_auth.user.value!.profilePhotoUrl, 'https://res.cloudinary.com/x/new.jpg');
    await _drainToasts(t);
  });

  testWidgets('double tap while uploading sends once', (t) async {
    final ctx = await _host(t);
    final f = _Fake()
      ..pickResult = _tempFile('c.jpg')
      ..hold = Completer();
    final c = Get.put(f.controller());
    final first = c.change(ctx);
    await t.pump();
    await c.change(ctx);
    await c.retryChange();
    expect(await c.upload(), isFalse);
    expect(f.sent, hasLength(1));
    expect(f.picks, 1);
    f.hold!.complete({'data': _userJson('u1', f.nextUrl)});
    await first;
    await _drainToasts(t);
  });

  testWidgets('offline: nothing is picked or sent (the toast is pinned by the onboarding offline test)', (t) async {
    final ctx = await _host(t);
    final f = _Fake()
      ..offline = true
      ..pickResult = _tempFile('d.jpg');
    final c = Get.put(f.controller());
    await c.change(ctx);
    await _toast(t);
    expect(await c.choose(ctx), isFalse);
    expect(f.picks, 0);
    expect(f.sent, isEmpty);
    expect(c.localPath.value, isNull);
    await _drainToasts(t);
  });

  testWidgets('cancelled pick changes nothing', (t) async {
    final ctx = await _host(t);
    final f = _Fake();
    final c = Get.put(f.controller());
    await c.change(ctx);
    expect(f.picks, 1);
    expect(f.sent, isEmpty);
    expect(c.localPath.value, isNull);
    expect(_auth.user.value!.profilePhotoUrl, 'https://res.cloudinary.com/x/old.jpg');
  });

  testWidgets('a late answer after close (logout) is dropped', (t) async {
    final ctx = await _host(t);
    final f = _Fake()
      ..pickResult = _tempFile('e.jpg')
      ..hold = Completer();
    final c = Get.put(f.controller());
    expect(await c.choose(ctx), isTrue);
    final pending = c.upload();
    await t.pump();
    expect(c.busy.value, isTrue);
    Get.delete<ProfilePhotoController>();
    expect(c.localPath.value, isNull);
    expect(c.busy.value, isFalse);
    f.hold!.complete({'data': _userJson('u1', f.nextUrl)});
    expect(await pending, isFalse);
    expect(_auth.user.value!.profilePhotoUrl, 'https://res.cloudinary.com/x/old.jpg');
  });

  testWidgets('an answer for another signed-in user is dropped', (t) async {
    final ctx = await _host(t);
    final f = _Fake()
      ..pickResult = _tempFile('f.jpg')
      ..hold = Completer();
    final c = Get.put(f.controller());
    await c.choose(ctx);
    final pending = c.upload();
    await t.pump();
    _auth.user.value = UserModel.fromJson(_userJson('u2', 'https://res.cloudinary.com/x/u2.jpg'));
    f.hold!.complete({'data': _userJson('u1', f.nextUrl)});
    expect(await pending, isFalse);
    expect(_auth.user.value!.id, 'u2');
    expect(_auth.user.value!.profilePhotoUrl, 'https://res.cloudinary.com/x/u2.jpg');
  });

  testWidgets('progress values reach the Rx', (t) async {
    final ctx = await _host(t);
    final f = _Fake()
      ..pickResult = _tempFile('g.jpg')
      ..progress = const [(10, 100), (64, 100)]
      ..hold = Completer();
    final c = Get.put(f.controller());
    await c.choose(ctx);
    final pending = c.upload();
    await t.pump();
    expect(c.progress.value, closeTo(0.64, 0.001));
    f.hold!.complete({'data': _userJson('u1', f.nextUrl)});
    expect(await pending, isTrue);
  });

  testWidgets('a reply without a user counts as a failure', (t) async {
    final ctx = await _host(t);
    final f = _Fake()
      ..pickResult = _tempFile('h.jpg')
      ..hold = Completer();
    final c = Get.put(f.controller());
    await c.choose(ctx);
    final pending = c.upload();
    f.hold!.complete({'data': 'x'});
    expect(await pending, isFalse);
    expect(c.failed.value, isTrue);
  });

  test('ensure registers one plain controller that Get.deleteAll removes', () {
    final a = ProfilePhotoController.ensure();
    expect(identical(a, ProfilePhotoController.ensure()), isTrue);
    Get.deleteAll();
    expect(Get.isRegistered<ProfilePhotoController>(), isFalse);
  });
}
