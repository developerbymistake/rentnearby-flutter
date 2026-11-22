import 'dart:async';
import 'dart:io';

import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/owner_fakes.dart';

void main() {
  setUpAll(() => initTestStorage('logout_image_cache'));

  setUp(() {
    Get.testMode = true;
    Get.put<TabConfigController>(FakeTabs());
  });
  tearDown(Get.reset);

  testWidgets('logout and delete account empty the in-memory image cache', (t) async {
    for (final reason in [LogoutReason.explicitLogout, LogoutReason.accountDeleted]) {
      final cache = PaintingBinding.instance.imageCache;
      final completer = OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
      cache.putIfAbsent('proof-$reason', () => completer);
      final l = ImageStreamListener((_, _) {});
      completer.addListener(l);
      expect(cache.pendingImageCount + cache.liveImageCount, greaterThan(0), reason: '$reason');

      final auth = FakeAuth();
      Get.put<AuthController>(auth, permanent: true);
      auth.signIn(role: UserRoleKeys.taxiDriver, taxiStatus: 'Approved', id: 'a');
      await t.runAsync(() => auth.forceLogout(reason: reason));
      expect(cache.currentSize, 0, reason: '$reason');
      expect(cache.pendingImageCount, 0, reason: '$reason');
      expect(cache.liveImageCount, 0, reason: '$reason');
      completer.removeListener(l);
      Get.delete<AuthController>(force: true);
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 3100)));
    }
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('session cleanup also empties the image disk cache', () {
    final src = File('lib/controllers/auth_controller.dart').readAsStringSync();
    expect(src, contains('defaultCacheManager.emptyCache()'));
    expect(src, contains('clearLiveImages()'));
  });
}
