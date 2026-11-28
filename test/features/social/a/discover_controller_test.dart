import 'dart:async';

import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/a/people/discover/discover_controller.dart';
import 'package:bakhli/features/social/a/people/people_controller.dart';
import 'package:bakhli/features/social/shared/data/follow_api.dart';
import 'package:bakhli/features/social/shared/social_error_types.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

DiscoverPerson _p(String id, {String kind = DiscoverReasonKinds.mutual}) => DiscoverPerson(
      person: SocialPerson(userId: id, name: 'Name $id', initial: 'N'),
      reason: DiscoverReason(kind: kind, mutualName: 'Aman', mutualCount: 2),
    );

class _Call {
  _Call(this.chip, this.cursor, this.refresh);

  final String chip;
  final String? cursor;
  final bool refresh;
}

class _Api extends FollowApi {
  final calls = <_Call>[];
  final hides = <String>[];

  /// Answers by "chip|cursor"; a missing key returns an empty last page.
  final pages = <String, BuddyResult<DiscoverPage>>{};
  final holds = <String, Completer<BuddyResult<DiscoverPage>>>{};
  BuddyResult<void> hideResult = const BuddyOk<void>(null);

  @override
  Future<BuddyResult<DiscoverPage>> discover({String chip = DiscoverChips.forYou, String? cursor, int? limit, bool refresh = false}) async {
    calls.add(_Call(chip, cursor, refresh));
    final key = '$chip|${cursor ?? ''}';
    final h = holds[key];
    if (h != null) return h.future;
    return pages[key] ?? const BuddyOk(DiscoverPage.empty);
  }

  @override
  Future<BuddyResult<void>> hide(String userId) async {
    hides.add(userId);
    return hideResult;
  }
}

List<DiscoverPerson> _many(String prefix, int n) => [for (var i = 0; i < n; i++) _p('$prefix$i')];

void main() {
  tearDown(Get.reset);

  test('first page, then the cursor page; duplicates across pages are dropped', () async {
    final api = _Api()
      ..pages['forYou|'] = BuddyOk(DiscoverPage(items: _many('a', 10), nextCursor: 'c1'))
      ..pages['forYou|c1'] = BuddyOk(DiscoverPage(items: [_p('a9'), _p('b1'), _p('b2')]));
    final c = DiscoverController(api: api, nearAllowed: () => false);
    await c.load();
    expect(c.current.items, hasLength(10));
    expect(c.current.hasMore, isTrue);
    expect(c.current.state.value, ListLoad.ready);
    await c.load(more: true);
    expect(c.current.items.map((e) => e.userId).toList(), [..._many('a', 10).map((e) => e.userId), 'b1', 'b2']);
    expect(c.current.hasMore, isFalse);
    expect(api.calls.map((e) => e.cursor).toList(), [null, 'c1']);
    await c.load(more: true);
    expect(api.calls, hasLength(2), reason: 'no call after the last page');
  });

  test('a short page with a cursor keeps loading, at most 3 pages in one go', () async {
    final api = _Api()
      ..pages['forYou|'] = BuddyOk(DiscoverPage(items: [_p('a')], nextCursor: 'c1'))
      ..pages['forYou|c1'] = const BuddyOk(DiscoverPage(items: [], nextCursor: 'c2'))
      ..pages['forYou|c2'] = BuddyOk(DiscoverPage(items: [_p('b')], nextCursor: 'c3'));
    final c = DiscoverController(api: api, nearAllowed: () => false);
    await c.load();
    expect(api.calls.map((e) => e.cursor).toList(), [null, 'c1', 'c2']);
    expect(c.current.items.map((e) => e.userId).toList(), ['a', 'b']);
    expect(c.current.cursor, 'c3');
  });

  test('a stale page is dropped (gen guard)', () async {
    final api = _Api();
    final first = Completer<BuddyResult<DiscoverPage>>();
    api.holds['forYou|'] = first;
    final c = DiscoverController(api: api, nearAllowed: () => false);
    final stale = c.load();
    api.holds.remove('forYou|');
    api.pages['forYou|'] = BuddyOk(DiscoverPage(items: [_p('new')]));
    await c.refresh();
    first.complete(BuddyOk(DiscoverPage(items: [_p('old')])));
    await stale;
    expect(c.current.items.map((e) => e.userId).toList(), ['new']);
  });

  test('refresh=1 only on pull to refresh, and only on its first request', () async {
    final api = _Api()..pages['forYou|'] = BuddyOk(DiscoverPage(items: _many('a', 10), nextCursor: 'c1'));
    final c = DiscoverController(api: api, nearAllowed: () => false);
    await c.load();
    await c.load(more: true);
    await c.refresh();
    expect(api.calls.map((e) => e.refresh).toList(), [false, false, true]);
  });

  test('hide is optimistic, removes the person from every chip and is put back on failure', () async {
    final api = _Api()
      ..pages['forYou|'] = BuddyOk(DiscoverPage(items: [_p('a'), _p('b'), _p('c')]))
      ..pages['mutual|'] = BuddyOk(DiscoverPage(items: [_p('b')]));
    final c = DiscoverController(api: api, nearAllowed: () => false);
    await c.load();
    c.selectChip(DiscoverChips.mutual);
    await pumpEventQueue();
    expect(c.lists[DiscoverChips.mutual]!.items, hasLength(1));

    api.hideResult = const BuddyOffline<void>();
    final error = await c.hide('b');
    expect(error, SocialStrings.offline);
    expect(c.lists[DiscoverChips.forYou]!.items.map((e) => e.userId).toList(), ['a', 'b', 'c']);
    expect(c.lists[DiscoverChips.mutual]!.items.map((e) => e.userId).toList(), ['b']);

    api.hideResult = const BuddyOk<void>(null);
    expect(await c.hide('b'), isNull);
    expect(c.lists[DiscoverChips.forYou]!.items.map((e) => e.userId).toList(), ['a', 'c']);
    expect(c.lists[DiscoverChips.mutual]!.items, isEmpty);
    expect(api.hides, ['b', 'b']);

    await c.refresh();
    expect(c.current.items.map((e) => e.userId), isNot(contains('b')), reason: 'a hidden person never comes back');
  });

  test('each chip keeps its own list; switching back does not reload', () async {
    final api = _Api()
      ..pages['forYou|'] = BuddyOk(DiscoverPage(items: [_p('a')]))
      ..pages['sameTrip|'] = BuddyOk(DiscoverPage(items: [_p('s', kind: DiscoverReasonKinds.sameTrip)], myTrip: const DiscoverTrip(cityName: 'Manali', month: 202612)));
    final c = DiscoverController(api: api, nearAllowed: () => false);
    await c.load();
    c.selectChip(DiscoverChips.sameTrip);
    await pumpEventQueue();
    expect(c.current.items.single.userId, 's');
    expect(c.myTrip.value!.cityName, 'Manali');
    c.selectChip(DiscoverChips.forYou);
    await pumpEventQueue();
    expect(c.current.items.single.userId, 'a');
    expect(api.calls.map((e) => e.chip).toList(), [DiscoverChips.forYou, DiscoverChips.sameTrip]);
  });

  test('a locked Near you chip makes no API call and shows the For you list', () async {
    final api = _Api()..pages['forYou|'] = BuddyOk(DiscoverPage(items: [_p('a')]));
    final c = DiscoverController(api: api, nearAllowed: () => false);
    await c.load();
    c.selectChip(DiscoverChips.near);
    await pumpEventQueue();
    await c.load(more: true);
    expect(c.showsNearLock, isTrue);
    expect(c.listChip, DiscoverChips.forYou);
    expect(api.calls.where((e) => e.chip == DiscoverChips.near), isEmpty);
  });

  test('Plus user loads Near you; a 403 PlusRequired turns it into the locked view', () async {
    final api = _Api()
      ..pages['forYou|'] = BuddyOk(DiscoverPage(items: [_p('a')]))
      ..pages['near|'] = const BuddyRefused(type: SocialErrorTypes.plusRequired, statusCode: 403);
    final c = DiscoverController(api: api, nearAllowed: () => true);
    c.selectChip(DiscoverChips.near);
    await pumpEventQueue();
    expect(api.calls.first.chip, DiscoverChips.near);
    expect(c.showsNearLock, isTrue);
    expect(c.current.items.single.userId, 'a');
    expect(c.lists[DiscoverChips.near]!.state.value, isNot(ListLoad.failed));
  });

  test('a failed first page shows failed, offline shows offline', () async {
    final api = _Api()..pages['forYou|'] = const BuddyOffline<DiscoverPage>();
    final c = DiscoverController(api: api, nearAllowed: () => false);
    await c.load();
    expect(c.current.state.value, ListLoad.offline);
    api.pages['forYou|'] = const BuddyRefused(type: null, statusCode: 500);
    await c.load();
    expect(c.current.state.value, ListLoad.failed);
  });

  test('a follow flips the copy in every chip', () async {
    final api = _Api()
      ..pages['forYou|'] = BuddyOk(DiscoverPage(items: [_p('a')]))
      ..pages['mutual|'] = BuddyOk(DiscoverPage(items: [_p('a')]));
    final c = DiscoverController(api: api, nearAllowed: () => false);
    await c.load();
    c.selectChip(DiscoverChips.mutual);
    await pumpEventQueue();
    c.onFollowChanged('a', false, true);
    for (final chip in [DiscoverChips.forYou, DiscoverChips.mutual]) {
      expect(c.lists[chip]!.items.single.followRequested, isTrue);
    }
  });
}
