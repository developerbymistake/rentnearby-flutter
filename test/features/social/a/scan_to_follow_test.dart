import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/features/buddy/buddies/data/buddies_api.dart';
import 'package:bakhli/features/buddy/buddies/models/buddy_models.dart';
import 'package:bakhli/features/buddy/scan/scan_outcome.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/a/people/scan_to_follow.dart';
import 'package:bakhli/features/social/a/people/username_entry_sheet.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';

const _friend = 'Bakhli#29583047';
const _mine = 'Bakhli#48291736';

class _Api extends BuddiesApi {
  BuddyResult<FindResult> result = const BuddyOk(FindResult(found: false));
  final finds = <(String, String)>[];

  @override
  Future<BuddyResult<FindResult>> find(String query, {required String source}) async {
    finds.add((query, source));
    return result;
  }
}

BuddyOk<FindResult> _found(String userId) => BuddyOk(FindResult(
      found: true,
      person: FoundPerson(userId: userId, name: 'Vikram', username: _friend, initial: 'V', relation: BuddyRelation.none),
    ));

late _Api api;
late List<String> opened;

ScanToFollow _flow({ScanOutcome? outcome, String? typed}) => ScanToFollow(
      api: api,
      scan: () async => outcome,
      typeUsername: (_) async => typed,
      openTraveller: opened.add,
    );

Future<void> _start(WidgetTester t, ScanToFollow flow) async {
  await pumpSocial(t, Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => flow.start(c), child: const Text('go')))));
  await t.tap(find.text('go'));
  await settle(t);
}

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    putSeeker();
    api = _Api();
    opened = [];
  });
  tearDown(Get.reset);

  testWidgets('Q2: a scanned username is looked up with source Qr and opens that traveller profile', (t) async {
    api.result = _found('vikram');
    await _start(t, _flow(outcome: const ScanFound(_friend)));
    expect(api.finds, [(_friend, BuddySource.qr)]);
    expect(opened, ['vikram']);
    expect(find.text(SocialStringsA.noTravellerFound), findsNothing);
    await drain(t);
  });

  testWidgets('Type username: the typed text is normalised and looked up with source Search', (t) async {
    api.result = _found('vikram');
    await _start(t, _flow(outcome: const ScanTypeInstead(), typed: ' bakhli#29583047 '));
    expect(api.finds, [(_friend, BuddySource.search)]);
    expect(opened, ['vikram']);
    await drain(t);
  });

  testWidgets('back from the scanner or from the username sheet does nothing', (t) async {
    await _start(t, _flow());
    await _start(t, _flow(outcome: const ScanTypeInstead()));
    expect(api.finds, isEmpty);
    expect(opened, isEmpty);
    await drain(t);
  });

  testWidgets('Q4: my own username opens my own profile, never a follow lookup', (t) async {
    await _start(t, _flow(outcome: const ScanTypeInstead(), typed: _mine));
    expect(api.finds, isEmpty);
    expect(opened, ['me']);
    await drain(t);
  });

  testWidgets('Q4: a lookup that answers with me also lands on my profile', (t) async {
    api.result = _found('me');
    await _start(t, _flow(outcome: const ScanFound(_friend)));
    expect(opened, ['me']);
    await drain(t);
  });

  testWidgets('Q5: unknown, blocked or deleted (found:false) shows the calm not-found line and opens nothing', (t) async {
    await _start(t, _flow(outcome: const ScanFound(_friend)));
    expect(find.text(SocialStringsA.noTravellerFound), findsOneWidget);
    expect(opened, isEmpty);
    await drain(t);
  });

  for (final (name, result, line) in <(String, BuddyResult<FindResult>, String)>[
    ('rate limited', const BuddyRefused(type: 'TooManyRequests', statusCode: 429, retryAfterSeconds: 60), SocialStringsA.scanTryLater),
    ('offline', const BuddyOffline(), SocialStrings.offline),
    ('refused', const BuddyRefused(type: 'SeekerOnly', statusCode: 403), SocialStrings.failed),
    ('server error', const BuddyFailed(message: 'x'), SocialStrings.failed),
  ]) {
    testWidgets('Q5: $name shows a calm line and opens nothing', (t) async {
      api.result = result;
      await _start(t, _flow(outcome: const ScanFound(_friend)));
      expect(find.text(line), findsOneWidget);
      expect(opened, isEmpty);
      await drain(t);
    });
  }

  test('Q5: a text that is not a username is refused without a server call', () async {
    final r = await _flow().lookup('hello', source: BuddySource.search);
    expect(r, ScanLookup.notFound);
    expect(api.finds, isEmpty);
    expect(opened, isEmpty);
  });

  group('username sheet', () {
    Future<List<String?>> open(WidgetTester t) async {
      final popped = <String?>[];
      await pumpSocial(t, Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () async => popped.add(await UsernameEntrySheet.show(c)), child: const Text('go')))));
      await t.tap(find.text('go'));
      await settle(t);
      return popped;
    }

    testWidgets('a bad text shows the hint line and keeps the sheet open', (t) async {
      final popped = await open(t);
      expect(find.text(SocialStringsA.findByUsername), findsOneWidget);
      await t.enterText(find.descendant(of: find.byKey(UsernameEntrySheet.fieldKey), matching: find.byType(TextField)), 'Bakhli#12');
      await t.tap(find.byKey(UsernameEntrySheet.findKey));
      await settle(t);
      expect(find.text(SocialStringsA.usernameBad), findsOneWidget);
      expect(popped, isEmpty);
      await drain(t);
    });

    testWidgets('a good text returns the normalised username', (t) async {
      final popped = await open(t);
      await t.enterText(find.descendant(of: find.byKey(UsernameEntrySheet.fieldKey), matching: find.byType(TextField)), ' bakhli#29583047');
      await t.tap(find.byKey(UsernameEntrySheet.findKey));
      await settle(t);
      expect(popped, [_friend]);
      expect(find.text(SocialStringsA.findByUsername), findsNothing);
      await drain(t);
    });
  });

  group('with the real navigation (SocialNav.openTraveller)', () {
    final pages = [GetPage(name: AppRoutes.traveller, page: () => Scaffold(body: Text('TRAVELLER ${(Get.arguments as Map)['userId']}')))];

    Future<void> run(WidgetTester t, ScanToFollow flow) async {
      await pumpSocial(t, Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => flow.start(c), child: const Text('go')))), pages: pages);
      await t.tap(find.text('go'));
      await settle(t);
    }

    testWidgets('Q2: a scanned friend opens the traveller page of that user id', (t) async {
      api.result = _found('vikram');
      await run(t, ScanToFollow(api: api, scan: () async => const ScanFound(_friend), typeUsername: (_) async => null));
      expect(find.text('TRAVELLER vikram'), findsOneWidget);
      await drain(t);
    });

    testWidgets('Q4: my own QR lands on my Profile tab, never on a traveller page with Follow', (t) async {
      final auth = Get.find<AuthController>();
      auth.tabIndex.value = AppTabs.home;
      await run(t, ScanToFollow(api: api, scan: () async => const ScanFound(_mine), typeUsername: (_) async => null));
      expect(find.textContaining('TRAVELLER'), findsNothing);
      expect(api.finds, isEmpty);
      expect(auth.tabIndex.value, AppTabs.profile);
      await drain(t);
    });
  });
}
