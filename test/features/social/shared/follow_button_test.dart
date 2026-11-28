import 'dart:async';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_snack.dart';
import 'package:bakhli/features/social/shared/data/follow_api.dart';
import 'package:bakhli/features/social/shared/social_live.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:bakhli/features/social/shared/widgets/follow_button.dart';
import 'package:bakhli/features/social/shared/widgets/follow_limit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'social_test_support.dart';

class _Api extends FollowApi {
  _Api(this.followResult, {this.unfollowResult = const BuddyOk<void>(null)});

  final BuddyResult<String> followResult;
  final BuddyResult<void> unfollowResult;
  Completer<BuddyResult<String>>? hold;
  int follows = 0;
  int unfollows = 0;

  @override
  Future<BuddyResult<String>> follow(String userId) async {
    follows++;
    final h = hold;
    return h == null ? followResult : h.future;
  }

  @override
  Future<BuddyResult<void>> unfollow(String userId) async {
    unfollows++;
    return unfollowResult;
  }
}

Widget _host(_Api api, {bool iFollow = false, bool requested = false, bool followsMe = false, List<(bool, bool)>? log, List<(bool, bool)>? settled}) => Scaffold(
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
            onSettled: (f, r) => settled?.add((f, r)),
          ),
        ),
      ),
    );

void main() {
  useBuddyRenderScale();
  tearDown(() {
    SocialLive.reset();
    Get.reset();
  });

  bool ignoring(WidgetTester t) =>
      t.widget<IgnorePointer>(find.descendant(of: find.byType(FollowButton), matching: find.byType(IgnorePointer)).first).ignoring;

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

  Finder sheetText() => find.descendant(of: find.byKey(FollowLimitSheet.sheetKey), matching: find.byType(Text));

  Future<void> expectLimitSheet(WidgetTester t) async {
    expect(find.byKey(FollowLimitSheet.sheetKey), findsOneWidget);
    expect(find.text(SocialStrings.tryLaterTitle), findsOneWidget);
    expect(find.text(SocialStrings.tryLaterLine), findsOneWidget);
    final texts = t.widgetList<Text>(sheetText()).map((w) => w.data ?? w.textSpan?.toPlainText() ?? '');
    expect(texts.where((x) => RegExp(r'\d').hasMatch(x)), isEmpty);
    expect(find.byType(BuddySnackBar), findsNothing);
    expect(find.text(SocialStrings.follow), findsOneWidget);
    await t.tap(find.byKey(FollowLimitSheet.okKey));
    await settle(t);
    expect(find.byKey(FollowLimitSheet.sheetKey), findsNothing);
    expect(find.text(SocialStrings.follow), findsOneWidget);
  }

  final limitCases = <String, BuddyResult<String>>{
    'TryLater': const BuddyRefused<String>(type: 'TryLater', statusCode: 429, message: 'Try again later. We limit some actions to keep Bakhli safe.'),
    'TooManyRequests': const BuddyRefused<String>(type: 'TooManyRequests', statusCode: 429, message: 'Too many tries. Please wait.'),
    'edge 429 with no body': const BuddyRefused<String>(type: null, statusCode: 429),
  };
  for (final c in limitCases.entries) {
    testWidgets('limit or block (${c.key}) opens the Try again later sheet, no counter or date, and rolls back', (t) async {
      final api = _Api(c.value);
      await pumpSocial(t, _host(api));
      await t.tap(find.text(SocialStrings.follow));
      await settle(t);
      expect(api.follows, 1);
      await expectLimitSheet(t);
      await drain(t);
    });
  }

  testWidgets('another refusal keeps the snack and opens no sheet', (t) async {
    final api = _Api(const BuddyRefused<String>(type: 'FollowingLimit', statusCode: 400, message: 'You follow too many people.'));
    await pumpSocial(t, _host(api));
    await t.tap(find.text(SocialStrings.follow));
    await settle(t);
    expect(find.byKey(FollowLimitSheet.sheetKey), findsNothing);
    expect(find.byType(BuddySnackBar), findsOneWidget);
    expect(find.text('You follow too many people.'), findsOneWidget);
    expect(find.text(SocialStrings.follow), findsOneWidget);
    await drain(t);
  });

  testWidgets('while waiting the button is disabled and a second tap is ignored', (t) async {
    final api = _Api(const BuddyOk('following'))..hold = Completer<BuddyResult<String>>();
    await pumpSocial(t, _host(api));
    await t.tap(find.text(SocialStrings.follow));
    await t.pump();
    expect(find.text(SocialStrings.following), findsOneWidget);
    expect(ignoring(t), isTrue);
    expect(t.widget<WhitePillButton>(find.byType(WhitePillButton)).onTap, isNotNull);
    expect(find.descendant(of: find.byType(FollowButton), matching: find.byType(Opacity)), findsNothing);
    await t.tap(find.text(SocialStrings.following), warnIfMissed: false);
    await t.pump();
    expect(api.follows, 1);
    expect(api.unfollows, 0);
    api.hold!.complete(const BuddyOk('following'));
    await settle(t);
    expect(find.text(SocialStrings.following), findsOneWidget);
    expect(ignoring(t), isFalse);
    await drain(t);
  });

  testWidgets('a refusal after waiting reverts and enables the button again', (t) async {
    final api = _Api(const BuddyOk('following'))..hold = Completer<BuddyResult<String>>();
    await pumpSocial(t, _host(api));
    await t.tap(find.text(SocialStrings.follow));
    await t.pump();
    expect(find.text(SocialStrings.following), findsOneWidget);
    api.hold!.complete(const BuddyRefused<String>(type: 'TryLater', statusCode: 429));
    await settle(t);
    await expectLimitSheet(t);
    expect(t.widget<GradientPillButton>(find.byType(GradientPillButton)).onTap, isNotNull);
    expect(ignoring(t), isFalse);
    await drain(t);
  });

  testWidgets('every change is announced per user, a repeat of the same state too', (t) async {
    final api = _Api(const BuddyOk('requested'));
    final seen = <(String, bool, bool)?>[];
    final w = ever<(String, bool, bool)?>(SocialLive.followChange, seen.add);
    await pumpSocial(t, _host(api));
    await t.tap(find.text(SocialStrings.follow));
    await settle(t);
    expect(seen, [('u1', true, false), ('u1', false, true)]);
    SocialLive.followChange.trigger(('u1', false, true));
    expect(seen, hasLength(3));
    w.dispose();
    await drain(t);
  });

  testWidgets('the parent still gets the final state when the button left the screen mid-flight', (t) async {
    final api = _Api(const BuddyOk('following'))..hold = Completer<BuddyResult<String>>();
    final log = <(bool, bool)>[];
    final settled = <(bool, bool)>[];
    await pumpSocial(t, _host(api, log: log, settled: settled));
    await t.tap(find.text(SocialStrings.follow));
    await t.pump();
    await t.pumpWidget(const SizedBox());
    api.hold!.complete(const BuddyOk('requested'));
    await t.pump();
    expect(log.last, (false, true));
    expect(SocialLive.followChange.value, ('u1', false, true));
    expect(settled, isEmpty);
    await drain(t);
  });

  testWidgets('onSettled fires once after an accepted follow', (t) async {
    final ok = <(bool, bool)>[];
    await pumpSocial(t, _host(_Api(const BuddyOk('following')), settled: ok));
    await t.tap(find.text(SocialStrings.follow));
    await settle(t);
    expect(ok, [(true, false)]);
    await drain(t);
  });

  testWidgets('a refused follow never calls onSettled', (t) async {
    final refused = <(bool, bool)>[];
    await pumpSocial(t, _host(_Api(const BuddyRefused<String>(type: 'TryLater', statusCode: 429)), settled: refused));
    await t.tap(find.text(SocialStrings.follow));
    await settle(t);
    expect(refused, isEmpty);
    await t.tap(find.byKey(FollowLimitSheet.okKey));
    await settle(t);
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
