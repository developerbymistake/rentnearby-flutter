import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/stay_owner/home/stay_owner_home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_render.dart';
import 'stay_fixtures.dart';

String _replyBy() => DateTime(2026, 11, 21, 18, 40).toUtc().toIso8601String();

void main() {
  setUpAll(() => initTestStorage('stay_home_render'));
  useOwnerRenderScale();
  setUp(OwnerCache.clearAll);
  tearDown(resetOwnerTestState);

  final share = [att('ShareListing', 10, {'slug': 'x'}), att('AddShareDetails', 11)];
  final busy = [att('EnquiriesWaiting', 1, {'count': 2, 'replyBy': _replyBy(), 'urgent': false})];
  final cases = <String, (Map<String, dynamic>, bool, String?)>{
    'o_st_7': (homeJson(status: 'PendingReview', everApproved: false, stay: {}), true, null),
    'o_st_8': (homeJson(status: 'Rejected', everApproved: false, reason: 'photos are not clear. Add day-time photos of the rooms.', stay: {}), true, null),
    'o_st_9': (homeJson(attention: share), false, null),
    'o_st_10': (
      homeJson(
        statusLine: {'code': 'NewNeedReply', 'args': {'count': 2}},
        badge: 2,
        stay: {'newEnquiries': 2, 'offersWaiting': 1, 'confirmed': 3},
        attention: [
          ...busy,
          att('OfferAccepted', 3, {'enquiryId': 'q', 'travellerName': 'Rohit', 'checkIn': '2026-11-27', 'checkOut': '2026-11-29'}),
        ],
      ),
      false,
      null
    ),
    'o_st_11': (homeJson(areaPaused: true, stay: {'newEnquiries': 0, 'offersWaiting': 1, 'confirmed': 2}), false, null),
    'o_st_12': (
      homeJson(
        featured: true,
        statusLine: {'code': 'Featured', 'args': {'city': 'Mukteshwar'}},
        badge: 3,
        stay: {'newEnquiries': 3, 'offersWaiting': 2, 'confirmed': 5},
        attention: [att('EnquiriesWaiting', 1, {'count': 3, 'replyBy': DateTime(2026, 11, 21, 16, 15).toUtc().toIso8601String()})],
      ),
      false,
      null
    ),
    'o_st_52': (
      homeJson(switchOn: false, stay: {'offersWaiting': 1, 'confirmed': 3}, attention: [att('Reports', 7, {'count': 1, 'firstReason': 'A guest says the photos do not match'})]),
      true,
      null
    ),
    'o_st_70': (homeJson(status: 'Rejected', takenDown: true, reason: 'guests reported a wrong location.', stay: {'confirmed': 2}), false, null),
    'o_st_67_e': (
      homeJson(statusLine: {'code': 'NewNeedReply', 'args': {'count': 1}}, badge: 1, stay: {'newEnquiries': 1, 'offersWaiting': 0, 'confirmed': 2}),
      false,
      'E'
    ),
  };

  for (final e in cases.entries) {
    testWidgets('render ${e.key}', (tester) async {
      final h = StayHarness.setUp(e.value.$1, denied: e.value.$2);
      final id = e.key.startsWith('o_st_67') ? 'o_st_67' : e.key;
      await renderOwnerFrame(tester, id, const StayOwnerHomeScreen(), part: e.value.$3, arrange: (t) async {
        await t.runAsync(() => h.home.checkNotifications());
        await t.pump(const Duration(milliseconds: 100));
      });
    });
  }

  testWidgets('render o_st_48', (tester) async {
    final h = StayHarness.setUp(homeJson(
      statusLine: {'code': 'NewNeedReply', 'args': {'count': 2}},
      badge: 2,
      stay: {'newEnquiries': 2, 'offersWaiting': 1, 'confirmed': 3},
      attention: [
        ...busy,
        att('Festival', 10, {'name': 'Diwali week', 'dateFrom': '2026-11-06', 'dateTo': '2026-11-12', 'festivalId': 'f1'}),
        att('ShareListing', 11, {'slug': 'x'}),
      ],
    ));
    await renderOwnerFrame(tester, 'o_st_48', const StayOwnerHomeScreen(), arrange: (t) async {
      await t.runAsync(() => h.home.checkNotifications());
      await t.pump(const Duration(milliseconds: 100));
    });
    for (final s in ['Needs attention', '2 enquiries waiting', 'Diwali week starts 6 Nov', 'Set your price for those days.', 'Set price', 'See all (3)']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('render o_st_67 A', (tester) async {
    final h = StayHarness.setUp(homeJson(), offline: true);
    await renderOwnerFrame(tester, 'o_st_67', const StayOwnerHomeScreen(), part: 'A', arrange: (t) async {
      await h.home.reload();
      await t.pump(const Duration(milliseconds: 100));
    });
  });
}
