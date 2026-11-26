import 'package:bakhli/features/social/b/feed/feed_filter_sheet.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';

FeedFilter? _result;

Widget _host({required String gender, required SocialLimits limits, FeedFilter initial = FeedFilter.none}) => Scaffold(
      body: Builder(
        builder: (c) => Center(
          child: TextButton(
            onPressed: () async => _result = await FeedFilterSheet.show(c, initial: initial, myGender: gender, nearMe: limits.nearMe),
            child: const Text('open'),
          ),
        ),
      ),
    );

const _freeLimits = SocialLimits(
  isPlus: false,
  canUpgrade: true,
  activeTrips: LimitUse(limit: 1, used: 0),
  publicTrips: LimitUse(limit: 1, used: 0),
  joinRequests: LimitUse(limit: 1, used: 0),
  newChats: LimitUse(limit: 3, used: 0),
  genderOnlyTrips: false,
  nearMe: false,
);

const _plusLimits = SocialLimits(
  isPlus: true,
  canUpgrade: true,
  activeTrips: LimitUse(limit: 10, used: 0),
  publicTrips: LimitUse(limit: 3, used: 0),
  joinRequests: LimitUse(limit: 5, used: 0),
  newChats: LimitUse(limit: 15, used: 0),
  genderOnlyTrips: true,
  nearMe: true,
);

Future<void> _open(WidgetTester t, Widget host, {Size size = const Size(392, 1400), double scale = 1.0}) async {
  await pumpSocial(t, host, size: size, textScale: scale);
  await t.tap(find.text('open'));
  await settle(t);
}

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    putSeeker();
    installServer();
    _result = null;
  });
  tearDown(Get.reset);

  for (final size in socialSizes) {
    for (final scale in socialScales) {
      testWidgets('free seeker: Near me shows the Plus lock, no switch; a man sees Anyone / Men only ($size, $scale)', (t) async {
        await _open(t, _host(gender: 'Male', limits: _freeLimits), size: size, scale: scale);
        expect(find.text(SocialStringsB.filtersKicker), findsOneWidget);
        expect(find.text(SocialStringsB.anywhere), findsOneWidget);
        for (final p in SocialStringsB.popularPlaces) {
          expect(find.text(p), findsOneWidget);
        }
        expect(find.text('Men only'), findsOneWidget);
        expect(find.text('Women only'), findsNothing);
        expect(find.byKey(FeedFilterSheet.nearPlusKey), findsOneWidget);
        expect(find.text(SocialStringsB.nearMeLine), findsOneWidget);
        expect(find.byKey(FeedFilterSheet.nearSwitchKey), findsNothing);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('a woman sees Women only', (t) async {
    await _open(t, _host(gender: 'Female', limits: _freeLimits));
    expect(find.text('Women only'), findsOneWidget);
    expect(find.text('Men only'), findsNothing);
  });

  testWidgets('gender Other sees only Anyone', (t) async {
    await _open(t, _host(gender: 'Other', limits: _freeLimits));
    expect(find.text('Women only'), findsNothing);
    expect(find.text('Men only'), findsNothing);
    expect(find.text(SocialStringsB.anyone), findsWidgets);
  });

  testWidgets('Show trips returns the picked place and gender; Near me needs Plus', (t) async {
    await _open(t, _host(gender: 'Male', limits: _freeLimits));
    await t.tap(find.text('Manali'));
    await t.tap(find.text('Men only'));
    await settle(t);
    await t.ensureVisible(find.byKey(FeedFilterSheet.showKey));
    await t.tap(find.byKey(FeedFilterSheet.showKey));
    await settle(t);
    expect(_result, const FeedFilter(q: 'Manali', who: FeedFilter.mine));
    expect(_result!.count, 2);
  });

  testWidgets('Plus seeker gets the Near me switch', (t) async {
    await _open(t, _host(gender: 'Male', limits: _plusLimits));
    expect(find.byKey(FeedFilterSheet.nearPlusKey), findsNothing);
    await t.ensureVisible(find.byKey(FeedFilterSheet.nearSwitchKey));
    await t.tap(find.byKey(FeedFilterSheet.nearSwitchKey));
    await settle(t);
    await t.ensureVisible(find.byKey(FeedFilterSheet.showKey));
    await t.tap(find.byKey(FeedFilterSheet.showKey));
    await settle(t);
    expect(_result?.near, isTrue);
  });
}
