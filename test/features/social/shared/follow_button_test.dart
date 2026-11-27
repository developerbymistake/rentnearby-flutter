import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/shared/data/follow_api.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:bakhli/features/social/shared/widgets/follow_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'social_test_support.dart';

class _Api extends FollowApi {
  _Api(this.followResult, {this.unfollowResult = const BuddyOk<void>(null)});

  final BuddyResult<String> followResult;
  final BuddyResult<void> unfollowResult;
  int follows = 0;
  int unfollows = 0;

  @override
  Future<BuddyResult<String>> follow(String userId) async {
    follows++;
    return followResult;
  }

  @override
  Future<BuddyResult<void>> unfollow(String userId) async {
    unfollows++;
    return unfollowResult;
  }
}

Widget _host(_Api api, {bool iFollow = false, bool requested = false, bool followsMe = false, List<(bool, bool)>? log}) => Scaffold(
      body: Center(
        child: SizedBox(
          width: 220,
          child: FollowButton(
            userId: 'u1',
            iFollow: iFollow,
            followRequested: requested,
            followsMe: followsMe,
            api: api,
            onChanged: (f, r) => log?.add((f, r)),
          ),
        ),
      ),
    );

void main() {
  useBuddyRenderScale();
  tearDown(Get.reset);

  test('labels', () {
    expect(FollowButton.labelOf(iFollow: false, requested: false, followsMe: false), SocialStrings.follow);
    expect(FollowButton.labelOf(iFollow: false, requested: false, followsMe: true), SocialStrings.followBack);
    expect(FollowButton.labelOf(iFollow: true, requested: false, followsMe: true), SocialStrings.following);
    expect(FollowButton.labelOf(iFollow: false, requested: true, followsMe: false), SocialStrings.requested);
  });

  for (final size in socialSizes) {
    for (final scale in socialScales) {
      testWidgets('follow is optimistic and lands on Requested for a private profile ($size, $scale)', (t) async {
        final api = _Api(const BuddyOk('requested'));
        final log = <(bool, bool)>[];
        await pumpSocial(t, _host(api, followsMe: true, log: log), size: size, textScale: scale);
        expect(find.text(SocialStrings.followBack), findsOneWidget);
        await t.tap(find.text(SocialStrings.followBack));
        await settle(t);
        expect(api.follows, 1);
        expect(find.text(SocialStrings.requested), findsOneWidget);
        expect(log.first, (true, false));
        expect(log.last, (false, true));
        await drain(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('a failed follow rolls back', (t) async {
    final api = _Api(const BuddyOffline());
    await pumpSocial(t, _host(api));
    await t.tap(find.text(SocialStrings.follow));
    await settle(t);
    expect(find.text(SocialStrings.follow), findsOneWidget);
    expect(find.text(SocialStrings.following), findsNothing);
    await drain(t);
  });

  testWidgets('abuse guard: the daily follow cap (429 TooManyRequests) shows the calm follow line and rolls back', (t) async {
    final api = _Api(const BuddyRefused<String>(type: 'TooManyRequests', statusCode: 429, message: 'Too many tries. Please wait.'));
    await pumpSocial(t, _host(api));
    await t.tap(find.text(SocialStrings.follow));
    await settle(t);
    expect(find.text(SocialStrings.followLimit), findsOneWidget);
    expect(find.text(SocialStrings.follow), findsOneWidget);
    await drain(t);
  });

  testWidgets('unfollow failure restores Following', (t) async {
    final api = _Api(const BuddyOk('following'), unfollowResult: const BuddyFailed(message: 'x'));
    await pumpSocial(t, _host(api, iFollow: true));
    await t.tap(find.text(SocialStrings.following));
    await settle(t);
    expect(api.unfollows, 1);
    expect(find.text(SocialStrings.following), findsOneWidget);
    await drain(t);
  });

  testWidgets('light Follow is a white pill and still follows; default stays the teal gradient', (t) async {
    final api = _Api(const BuddyOk('following'));
    await pumpSocial(t, Scaffold(body: Center(child: FollowButton(userId: 'u1', iFollow: false, followRequested: false, followsMe: false, compact: true, light: true, api: api))));
    expect(find.byType(WhitePillButton), findsOneWidget);
    expect(find.byType(GradientPillButton), findsNothing);
    await t.tap(find.text(SocialStrings.follow));
    await settle(t);
    expect(api.follows, 1);
    expect(find.text(SocialStrings.following), findsOneWidget);
    await drain(t);
  });

  testWidgets('default Follow stays the teal gradient pill', (t) async {
    await pumpSocial(t, _host(_Api(const BuddyOk('following'))));
    expect(find.byType(GradientPillButton), findsOneWidget);
    expect(find.byType(WhitePillButton), findsNothing);
  });
}
