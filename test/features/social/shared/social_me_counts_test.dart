import 'package:bakhli/features/buddy/buddy_live.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/shared/data/social_me_api.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/social/shared/social_live.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'social_test_support.dart';

Map<String, dynamic> _json(Map<String, dynamic> extra) {
  final j = socialMeJson(profile: myProfileJson());
  j['counts'] = {...(j['counts'] as Map), ...extra};
  return j;
}

class _CountingApi extends SocialMeApi {
  _CountingApi();

  int calls = 0;

  @override
  Future<BuddyResult<SocialMe>> me() async {
    calls++;
    return BuddyOk(SocialMe.fromJson(_json({'tripInvites': calls})));
  }
}

void main() {
  tearDown(Get.reset);

  test('fromJson reads the trip invite and join request counts', () {
    final me = SocialMe.fromJson(_json({'tripInvites': 2, 'joinRequests': 3}));
    expect(me.tripInvites, 2);
    expect(me.joinRequests, 3);
    expect(me.followRequests, 2);
  });

  test('missing or null values fall back to 0', () {
    final missing = SocialMe.fromJson(_json({}));
    expect(missing.tripInvites, 0);
    expect(missing.joinRequests, 0);
    final empty = SocialMe.fromJson(_json({'tripInvites': null, 'joinRequests': null}));
    expect(empty.tripInvites, 0);
    expect(empty.joinRequests, 0);
  });

  test('copyWith keeps the new counts', () {
    final me = SocialMe.fromJson(_json({'tripInvites': 4, 'joinRequests': 5}));
    final next = me.copyWith(followRequests: 9, chatUnread: ChatUnread.zero, guidelinesAccepted: true);
    expect(next.followRequests, 9);
    expect(next.tripInvites, 4);
    expect(next.joinRequests, 5);
  });

  test('a tripInvites hub scope reloads the shared trips list', () {
    final before = BuddyLive.sharedTrips.value;
    SocialLive.onScope('tripInvites');
    expect(BuddyLive.sharedTrips.value, before + 1);
  });

  testWidgets('a sharedTrips bump reloads me once after the debounce', (t) async {
    final api = _CountingApi();
    final c = Get.put(SocialMeController(api: api));
    await t.pump();
    expect(api.calls, 1);
    BuddyLive.sharedTrips.value++;
    await t.pump(const Duration(milliseconds: 300));
    BuddyLive.sharedTrips.value++;
    await t.pump(SocialMeController.sharedTripsDebounce - const Duration(milliseconds: 1));
    expect(api.calls, 1);
    await t.pump(const Duration(milliseconds: 1));
    await t.pump();
    expect(api.calls, 2);
    expect(c.me.value?.tripInvites, 2);
  });

  testWidgets('no reload runs after the controller closes', (t) async {
    final api = _CountingApi();
    Get.put(SocialMeController(api: api));
    await t.pump();
    BuddyLive.sharedTrips.value++;
    await t.pump(const Duration(milliseconds: 100));
    Get.delete<SocialMeController>();
    await t.pump(const Duration(seconds: 2));
    expect(api.calls, 1);
  });
}
