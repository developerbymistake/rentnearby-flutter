import 'dart:async';
import 'dart:io';

import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/shared/data/social_me_api.dart';
import 'package:bakhli/features/social/shared/social_area_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'social_test_support.dart';

class _Api extends SocialMeApi {
  _Api();

  final List<String> sent = [];
  BuddyResult<void> next = const BuddyOk(null);

  Completer<void>? gate;

  @override
  Future<BuddyResult<void>> updateArea(String districtId) async {
    sent.add(districtId);
    final g = gate;
    if (g != null) await g.future;
    return next;
  }
}

void main() {
  late _Api api;
  var now = DateTime(2026, 11, 27, 9);

  setUp(() {
    SocialAreaSync.reset();
    api = _Api();
    now = DateTime(2026, 11, 27, 9);
    SocialAreaSync.api = api;
    SocialAreaSync.clock = () => now;
  });
  tearDown(SocialAreaSync.reset);

  test('sends the district id on start; the same district again within 6 h is throttled', () async {
    await SocialAreaSync.sync('d-1');
    await SocialAreaSync.sync('d-1');
    now = now.add(const Duration(hours: 5));
    await SocialAreaSync.sync('d-1');
    expect(api.sent, ['d-1']);
  });

  test('a resume after 6 h sends again so the area never goes stale', () async {
    await SocialAreaSync.sync('d-1');
    now = now.add(const Duration(hours: 6, minutes: 1));
    await SocialAreaSync.sync('d-1');
    expect(api.sent, ['d-1', 'd-1']);
  });

  test('a district change is sent at once', () async {
    await SocialAreaSync.sync('d-1');
    await SocialAreaSync.sync('d-2');
    expect(api.sent, ['d-1', 'd-2']);
  });

  test('no district (GPS not resolved yet) sends nothing', () async {
    await SocialAreaSync.sync(null);
    await SocialAreaSync.sync('  ');
    expect(api.sent, isEmpty);
  });

  test('offline is not remembered: the next start or resume tries again (no retry loop of its own)', () async {
    api.next = const BuddyOffline();
    await SocialAreaSync.sync('d-1');
    expect(api.sent, ['d-1']);
    api.next = const BuddyOk(null);
    await SocialAreaSync.sync('d-1');
    expect(api.sent, ['d-1', 'd-1']);
  });

  test('a refusal (owner role, unknown district) is remembered: never a retry storm', () async {
    api.next = const BuddyRefused(type: 'SeekerOnly', statusCode: 403);
    await SocialAreaSync.sync('d-1');
    await SocialAreaSync.sync('d-1');
    expect(api.sent, ['d-1']);
  });

  test('a change while a send is running is sent right after it, once', () async {
    final gate = Completer<void>();
    api.gate = gate;
    final first = SocialAreaSync.sync('d-1');
    await SocialAreaSync.sync('d-2');
    await SocialAreaSync.sync('d-3');
    expect(api.sent, ['d-1']);
    api.gate = null;
    gate.complete();
    await first;
    expect(api.sent, ['d-1', 'd-3']);
  });

  test('logout resets: a new login sends its district again', () async {
    await SocialAreaSync.sync('d-1');
    SocialAreaSync.reset();
    SocialAreaSync.api = api;
    SocialAreaSync.clock = () => now;
    await SocialAreaSync.sync('d-1');
    expect(api.sent, ['d-1', 'd-1']);
  });

  test('the request body is the district id only, never coordinates', () async {
    await initSocialTestStorage();
    SocialAreaSync.reset();
    final server = installServer();
    server.on('PUT', '/social/me/area', {'districtId': 'd-9', 'updatedAt': '2026-11-27T03:30:00Z'});
    await SocialAreaSync.sync('d-9');
    final body = server.calls('PUT', '/social/me/area').single.data as Map;
    expect(body, {'districtId': 'd-9'});
  });

  test('wiring: MainScreen syncs on start, on district change and on resume (seeker only); logout resets', () {
    final main = File('lib/screens/main_screen.dart').readAsStringSync();
    expect(main, contains('_socialAreaWorker = ever(_locationCtrl.selectedDistrict'));
    expect(RegExp(r'if \(traveller\) \{\s+_socialAreaWorker').hasMatch(main), isTrue);
    expect(main, contains('SocialAreaSync.sync(_locationCtrl.selectedDistrict.value?.id);'));
    expect(main, contains('if (SocialMeController.maybe != null) SocialAreaSync.sync(_locationCtrl.selectedDistrict.value?.id);'));
    expect(main, contains('_socialAreaWorker?.dispose();'));
    final hooks = File('lib/features/social/social_session_hooks.dart').readAsStringSync();
    expect(hooks, contains('SocialAreaSync.reset();'));
    final sync = File('lib/features/social/shared/social_area_sync.dart').readAsStringSync();
    expect(sync, isNot(contains('latitude')));
    expect(sync, isNot(contains('longitude')));
  });
}
