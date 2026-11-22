import 'package:bakhli/config/shell_kind.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/session/owner_push_sync.dart';
import 'package:bakhli/features/owner_core/session/owner_session_hooks.dart';
import 'package:bakhli/features/owner_core/session/shell_teardown.dart';
import 'dart:async';

import 'package:bakhli/config/app_constants.dart';
import 'package:bakhli/services/banner_hub_service.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../support/owner_fakes.dart';

class _HangingBanner extends BannerHubService {
  @override
  Future<void> disconnect() => Completer<void>().future;
}

void _seed(String user) {
  for (final k in [
    OwnerCacheKeys.home,
    OwnerCacheKeys.listing,
    OwnerCacheKeys.calMonth('2026-11'),
    OwnerCacheKeys.calUpcoming,
    OwnerCacheKeys.calPast,
    OwnerCacheKeys.specialPrices,
    OwnerCacheKeys.blocks,
    OwnerCacheKeys.summary('2026-11'),
    OwnerCacheKeys.planCard,
    OwnerCacheKeys.festivals('Uttarakhand'),
    OwnerCacheKeys.seekerFeed,
  ]) {
    OwnerCache.write(user, k, {'k': k});
  }
  OwnerCache.setStatusSeen(user, 'Reply:1:x:1');
  OwnerCache.setShellEmpty(user, true);
}

bool _anyOwnerKey() => [GetStorage(), GetStorage(OwnerCache.container)].any((box) => box.getKeys<Iterable<dynamic>>().whereType<String>().any((k) =>
    k.startsWith(OwnerCache.cachePrefix) || k.startsWith(OwnerCache.statusSeenPrefix) || k.startsWith(OwnerCache.shellEmptyPrefix)));

void main() {
  setUpAll(() => initTestStorage('owner_logout'));

  setUp(() {
    Get.testMode = true;
    Get.put<TabConfigController>(FakeTabs());
  });
  tearDown(Get.reset);

  test('read and write are scoped to the signed-in user', () {
    OwnerCache.write('a', OwnerCacheKeys.home, {'x': 1});
    expect(OwnerCache.read('a', OwnerCacheKeys.home), {'x': 1});
    expect(OwnerCache.read('b', OwnerCacheKeys.home), isNull);
    expect(OwnerCache.read(null, OwnerCacheKeys.home), isNull);
    OwnerCache.clearAll();
  });

  test('a broken saved value reads as null', () {
    GetStorage(OwnerCache.container).write('${OwnerCache.cachePrefix}a:home', '{not json');
    expect(OwnerCache.read('a', OwnerCacheKeys.home), isNull);
    OwnerCache.clearAll();
  });

  test('listing-scoped clear keeps the seeker feed and other users', () {
    _seed('a');
    _seed('b');
    OwnerCache.removeListingScoped('a');
    expect(OwnerCache.read('a', OwnerCacheKeys.home), isNull);
    expect(OwnerCache.read('a', OwnerCacheKeys.calMonth('2026-11')), isNull);
    expect(OwnerCache.read('a', OwnerCacheKeys.summary('2026-11')), isNull);
    expect(OwnerCache.read('a', OwnerCacheKeys.seekerFeed), isNotNull);
    expect(OwnerCache.read('b', OwnerCacheKeys.home), isNotNull);
    OwnerCache.clearAll();
  });

  for (final reason in LogoutReason.values) {
    test('logout ($reason) removes every owner key of every user and runs the role resets', () async {
      _seed('a');
      _seed('b');
      var resets = 0;
      OwnerSessionHooks.register('test', (r, u) {
        expect(r, reason);
        expect(u, 'a');
        resets++;
      });
      OwnerSessionHooks.refreshHome = () async {};
      await OwnerSessionHooks.onLogout(reason, 'a');
      expect(_anyOwnerKey(), isFalse);
      expect(resets, 1);
      expect(OwnerCache.read('a', OwnerCacheKeys.home), isNull);
      expect(OwnerCache.statusSeen('a'), isNull);
      expect(OwnerCache.shellEmpty('a'), isFalse);
      OwnerSessionHooks.unregister('test');
    });
  }

  test('next user sees nothing of the last one, shell back to seeker', () async {
    final auth = FakeAuth();
    Get.put<AuthController>(auth);
    auth.signIn(role: UserRoleKeys.stayOwner, stayStatus: null, id: 'a');
    auth.setOwnerShellEmpty(true);
    expect(auth.shellKind.value, ShellKind.stayOwner);
    _seed('a');
    await OwnerSessionHooks.onLogout(LogoutReason.explicitLogout, 'a');
    auth.signIn(role: UserRoleKeys.stayOwner, stayStatus: null, id: 'b');
    expect(auth.shellKind.value, ShellKind.seeker);
    expect(OwnerCache.read('b', OwnerCacheKeys.home), isNull);
  });

  test('forced logout from an owner shell blocks the seeker shell switch until cleanup ends', () async {
    for (final reason in [LogoutReason.sessionExpired, LogoutReason.roleChanged, LogoutReason.accountDeleted]) {
      final auth = FakeAuth();
      Get.put<AuthController>(auth, permanent: true);
      Get.put<TabConfigController>(FakeTabs());
      auth.signIn(role: UserRoleKeys.taxiDriver, taxiStatus: 'Approved', id: 'a');
      expect(auth.shellKind.value, ShellKind.taxiDriver, reason: '$reason');
      final blockedAtFlip = <bool>[];
      final w = ever<ShellKind>(auth.shellKind, (_) => blockedAtFlip.add(auth.blocksShellSwitch));
      await auth.forceLogout(reason: reason);
      w.dispose();
      expect(blockedAtFlip, [true], reason: '$reason');
      expect(auth.blocksShellSwitch, isFalse, reason: '$reason');
      expect(auth.shellKind.value, ShellKind.seeker, reason: '$reason');
      Get.delete<AuthController>(force: true);
      // ApiService joins logouts that start within 3 seconds of the last one.
      await Future<void>.delayed(const Duration(milliseconds: 3100));
    }
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('logout clears shell teardown steps and push handlers', () async {
    var n = 0;
    ShellTeardown.register(ShellKind.taxiDriver, () => n++);
    var pushed = 0;
    OwnerPushSync.register('t', (_, _) => pushed++);
    await OwnerSessionHooks.onLogout(LogoutReason.explicitLogout, 'a');
    ShellTeardown.run(ShellKind.taxiDriver);
    OwnerPushSync.onPush('festival_reminder', null, null);
    expect(n, 0);
    expect(pushed, 0);
  });

  test('a throwing hook never stops the others', () async {
    var ran = false;
    OwnerSessionHooks.register('boom', (_, _) => throw StateError('x'));
    OwnerSessionHooks.register('ok', (_, _) => ran = true);
    await OwnerSessionHooks.onLogout(LogoutReason.sessionExpired, 'a');
    expect(ran, isTrue);
    OwnerSessionHooks.unregister('boom');
    OwnerSessionHooks.unregister('ok');
  });

  test('push sync reaches handlers only for owner work types', () {
    final seen = <String>[];
    OwnerPushSync.register('t', (type, args) => seen.add(type));
    OwnerPushSync.onPush('festival_reminder', '/stay-special-prices', {'festivalId': 'f'});
    OwnerPushSync.onPush('trip_reply', '/trip-replies', null);
    OwnerPushSync.onPush(null, null, null);
    expect(seen, ['festival_reminder']);
    OwnerPushSync.reset();
  });

  test('shell teardown runs the old kind once', () {
    var n = 0;
    ShellTeardown.register(ShellKind.stayOwner, () => n++);
    ShellTeardown.run(ShellKind.taxiDriver);
    expect(n, 0);
    ShellTeardown.run(ShellKind.stayOwner);
    ShellTeardown.run(ShellKind.stayOwner);
    expect(n, 1);
  });

  test('FX-18 owner keys live in their own box; two equal writes are one box write; legacy keys are dropped', () async {
    final box = GetStorage(OwnerCache.container);
    var writes = 0;
    final listener = box.listen(() => writes++);
    OwnerCache.write('a', OwnerCacheKeys.home, {'x': 1});
    OwnerCache.write('a', OwnerCacheKeys.home, {'x': 1});
    listener();
    expect(writes, 1);
    expect(GetStorage().hasData('${OwnerCache.cachePrefix}a:home'), isFalse);
    GetStorage().write('${OwnerCache.cachePrefix}old:home', '{}');
    GetStorage().write('${OwnerCache.statusSeenPrefix}old', 'k');
    await OwnerCache.init();
    expect(GetStorage().hasData('${OwnerCache.cachePrefix}old:home'), isFalse);
    expect(GetStorage().hasData('${OwnerCache.statusSeenPrefix}old'), isFalse);
    OwnerCache.clearAll();
    expect(box.getKeys<Iterable<dynamic>>(), isEmpty);
  });

  test('FX-26 a hub disconnect that never completes still ends with no token and no owner key, and never touches the next session', () async {
    FlutterSecureStorage.setMockInitialValues({AppConstants.tokenKey: 'old'});
    await StorageService.init();
    expect(StorageService.getToken(), 'old');
    Get.put<BannerHubService>(_HangingBanner(), permanent: true);
    final auth = FakeAuth();
    Get.put<AuthController>(auth, permanent: true);
    Get.put<TabConfigController>(FakeTabs());
    auth.signIn(role: UserRoleKeys.stayOwner, stayStatus: 'Approved', id: 'a');
    _seed('a');
    final sw = Stopwatch()..start();
    await auth.forceLogout(reason: LogoutReason.sessionExpired);
    expect(sw.elapsed, lessThan(const Duration(seconds: 4)));
    expect(StorageService.getToken(), isNull);
    expect(_anyOwnerKey(), isFalse);
    await StorageService.saveToken('next');
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(StorageService.getToken(), 'next', reason: 'no late cleanup step runs after the redirect');
    await StorageService.clearToken();
    Get.delete<AuthController>(force: true);
    Get.delete<BannerHubService>(force: true);
  }, timeout: const Timeout(Duration(seconds: 20)));
}
