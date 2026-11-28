import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/b/data/join_api.dart';
import 'package:bakhli/features/social/b/join/join_requests_controller.dart';
import 'package:bakhli/features/social/shared/data/social_me_api.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../shared/social_test_support.dart';
import 'social_b_test_kit.dart';

class _MeApi extends SocialMeApi {
  _MeApi();

  @override
  Future<BuddyResult<SocialMe>> me() async => const BuddyOffline();
}

class _Me extends SocialMeController {
  _Me() : super(api: _MeApi());

  int quiet = 0;

  @override
  Future<void> refreshQuiet() async => quiet++;
}

class _Join extends JoinApi {
  _Join({required this.ok});

  final bool ok;

  @override
  Future<BuddyResult<JoinRequestsPage>> list(String tripId) async => BuddyOk(JoinRequestsPage.fromJson({
        'trip': publicTripJson(isMine: true),
        'items': [
          {'id': 'jr-1', 'person': rowJson('aman', 'Aman Kumar'), 'tier': 2},
        ],
      }));

  @override
  Future<BuddyResult<JoinAccepted>> accept(String id, {required bool addToBuddies}) async =>
      ok ? BuddyOk(JoinAccepted.fromJson({'memberId': 'm-1', 'seatsLeft': 1, 'roomId': 'room-1'})) : const BuddyOffline();

  @override
  Future<BuddyResult<void>> decline(String id) async => ok ? const BuddyOk(null) : const BuddyOffline();
}

Future<(JoinRequestsController, _Me)> _ready({required bool ok}) async {
  final me = _Me();
  Get.put<SocialMeController>(me);
  final c = Get.put(JoinRequestsController(tripId: 'trip-1', api: _Join(ok: ok)));
  await c.load();
  return (c, me);
}

void main() {
  setUp(Get.reset);
  tearDown(Get.reset);

  test('accept success refreshes the Home counts', () async {
    final (c, me) = await _ready(ok: true);
    final (ok, _) = await c.accept(c.items.single);
    expect(ok, isTrue);
    expect(me.quiet, 1);
  });

  test('decline success refreshes the Home counts', () async {
    final (c, me) = await _ready(ok: true);
    final (ok, _) = await c.decline(c.items.single);
    expect(ok, isTrue);
    expect(me.quiet, 1);
  });

  test('a failed accept or decline leaves the counts alone', () async {
    final (c, me) = await _ready(ok: false);
    expect((await c.accept(c.items.single)).$1, isFalse);
    expect((await c.decline(c.items.single)).$1, isFalse);
    expect(me.quiet, 0);
  });
}
