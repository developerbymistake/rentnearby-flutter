import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/buddy/shared/widgets/segment_tabs.dart';
import 'package:bakhli/features/social/b/feed/feed_filter_sheet.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/b/widgets/social_widgets_b.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';

FeedFilter? _result;

Widget _host({required SocialLimits limits, FeedFilter initial = FeedFilter.none}) => Scaffold(
      body: Builder(
        builder: (c) => Center(
          child: TextButton(
            onPressed: () async => _result = await FeedFilterSheet.show(c, initial: initial, nearMe: limits.nearMe),
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
  newChats: LimitUse(limit: 10, used: 0),
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
      testWidgets('free seeker: Near me shows the Plus lock, no switch; Who can join is one SegmentTabs Anyone | Men | Women ($size, $scale)', (t) async {
        await _open(t, _host(limits: _freeLimits), size: size, scale: scale);
        expect(find.text(SocialStringsB.filtersKicker), findsOneWidget);
        // Mock D9c: the FILTERS kicker sits above the sheet title, one left edge.
        final title = find.descendant(of: find.byType(Sheet3D), matching: find.text(SocialStringsB.trips)).first;
        expect(t.getTopLeft(find.text(SocialStringsB.filtersKicker)).dy, lessThan(t.getTopLeft(title).dy));
        expect(t.getTopLeft(find.text(SocialStringsB.filtersKicker)).dx, t.getTopLeft(title).dx);
        expect(find.text(SocialStringsB.anywhere), findsOneWidget);
        for (final p in SocialStringsB.popularPlaces) {
          expect(find.text(p), findsOneWidget);
        }
        final who = find.byKey(FeedFilterSheet.whoKey);
        expect(who, findsOneWidget);
        final tabs = t.widget<SegmentTabs>(who);
        expect(tabs.labels, ['Anyone', 'Men', 'Women']);
        expect(tabs.selected, 0);
        expect(tabs.locked, isEmpty);
        expect(FeedFilter.whoValues, [FeedFilter.any, FeedFilter.men, FeedFilter.women]);
        expect(find.descendant(of: who, matching: find.byIcon(Icons.lock_rounded)), findsNothing);
        expect(find.byType(SocialPickChip).evaluate().length, SocialStringsB.popularPlaces.length);
        expect(find.text(SocialStringsB.women), findsOneWidget);
        expect(find.text(SocialStringsB.men), findsOneWidget);
        expect(find.text('Men only'), findsNothing);
        expect(find.byKey(FeedFilterSheet.nearPlusKey), findsOneWidget);
        expect(find.text(SocialStringsB.nearMeLine), findsOneWidget);
        expect(find.byKey(FeedFilterSheet.nearSwitchKey), findsNothing);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('Show trips returns the picked place and Women; the head shows the pick', (t) async {
    await _open(t, _host(limits: _freeLimits));
    await t.tap(find.text('Manali'));
    await t.tap(find.descendant(of: find.byKey(FeedFilterSheet.whoKey), matching: find.text(SocialStringsB.women)));
    await settle(t);
    expect(find.text(SocialStringsB.women), findsNWidgets(2));
    await t.ensureVisible(find.byKey(FeedFilterSheet.showKey));
    await t.tap(find.byKey(FeedFilterSheet.showKey));
    await settle(t);
    expect(_result, const FeedFilter(q: 'Manali', who: FeedFilter.women));
    expect(_result!.count, 2);
  });

  testWidgets('Men is picked; Anyone again clears the gender filter', (t) async {
    await _open(t, _host(limits: _freeLimits, initial: const FeedFilter(who: FeedFilter.men)));
    expect(find.text(SocialStringsB.men), findsNWidgets(2));
    await t.tap(find.descendant(of: find.byKey(FeedFilterSheet.whoKey), matching: find.text(SocialStringsB.anyone)));
    await settle(t);
    await t.ensureVisible(find.byKey(FeedFilterSheet.showKey));
    await t.tap(find.byKey(FeedFilterSheet.showKey));
    await settle(t);
    expect(_result, FeedFilter.none);
    expect(_result!.count, 0);
  });

  testWidgets('Plus seeker gets the Near me switch', (t) async {
    await _open(t, _host(limits: _plusLimits));
    expect(find.byKey(FeedFilterSheet.nearPlusKey), findsNothing);
    await t.ensureVisible(find.byKey(FeedFilterSheet.nearSwitchKey));
    await t.tap(find.byKey(FeedFilterSheet.nearSwitchKey));
    await settle(t);
    await t.ensureVisible(find.byKey(FeedFilterSheet.showKey));
    await t.tap(find.byKey(FeedFilterSheet.showKey));
    await settle(t);
    expect(_result?.near, isTrue);
  });
  testWidgets('T3: Travel by is one tab row Any | Public transport | Bike | Own car | Taxi; Any is the default and the pick is returned', (t) async {
    await _open(t, _host(limits: _freeLimits));
    final travel = find.byKey(FeedFilterSheet.travelKey);
    await t.ensureVisible(travel);
    await settle(t);
    expect(find.text(SocialStringsB.travelByCaps), findsOneWidget);
    expect(t.widget<SegmentTabs>(travel).labels, [SocialStringsB.travelAny, ...SocialStringsB.travelLabels]);
    expect(t.widget<SegmentTabs>(travel).selected, 0);
    await t.tap(find.descendant(of: travel, matching: find.text('Bike')));
    await settle(t);
    expect(t.widget<SegmentTabs>(travel).selected, 2);
    await t.ensureVisible(find.byKey(FeedFilterSheet.showKey));
    await t.tap(find.byKey(FeedFilterSheet.showKey));
    await settle(t);
    expect(_result?.travel, 'bike');
    expect(_result?.count, 1);
    await drain(t);
  });

  test('FeedFilter: travel takes part in equality and the count', () {
    expect(FeedFilter.none.travel, FeedFilter.any);
    expect(FeedFilter.none.copyWith(travel: 'taxi') == FeedFilter.none, isFalse);
    expect(FeedFilter.none.copyWith(travel: 'taxi').count, 1);
    expect(FeedFilter.travelValues, [FeedFilter.any, ...TravelModes.codes]);
  });
}
