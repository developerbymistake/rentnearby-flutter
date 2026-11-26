import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/b/models/post_draft.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/b/wizard/post_trip_controller.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../shared/social_test_support.dart';
import 'social_b_test_kit.dart';

Future<PostTripController> ready(PostTripController c) async {
  Get.put(c, tag: 'test-${identityHashCode(c)}');
  for (var i = 0; i < 20 && c.preparing.value; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return c;
}

void main() {
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    putSeeker();
    seedCities();
  });
  tearDown(Get.reset);

  test('Where: Ready cities only, the first city fixes the state, max 4 in order', () async {
    installServer();
    final c = await ready(PostTripController(persist: false));
    expect(c.visibleCities().map((e) => e.name), isNot(contains('Chopta')));
    expect(c.visibleCities().map((e) => e.name), containsAll(['Manali', 'Rishikesh']));
    expect(c.canNext(PostTripController.stepWhere), isFalse);
    c.toggleCity(manali);
    expect(c.visibleCities().every((e) => e.stateName == 'Himachal Pradesh'), isTrue);
    expect(c.toggleCity(rishikesh), isNull);
    expect(c.draft.value.cities.map((e) => e.name), ['Manali']);
    c.toggleCity(kasol);
    c.toggleCity(shimla);
    c.toggleCity(dharamshala);
    expect(c.toggleCity(tosh), SocialStringsB.maxCities(4));
    expect(c.draft.value.cities.map((e) => e.name), ['Manali', 'Kasol', 'Shimla', 'Dharamshala']);
    c.toggleCity(manali);
    expect(c.draft.value.cities.first.name, 'Kasol');
    expect(c.canNext(PostTripController.stepWhere), isTrue);
  });

  test('auto text follows the answers until the user edits it; chips add a line', () async {
    installServer();
    final c = await ready(PostTripController(persist: false));
    c.toggleCity(manali);
    c.setMonths(2);
    c.setDays(4);
    expect(c.draft.value.text, 'Heading to Manali for 4 days in the next 2 months. Looking for a travel buddy, open to anyone.');
    c.toggleChip('Happy to split a cab');
    c.toggleChip('Up for treks');
    expect(c.draft.value.text, 'Heading to Manali for 4 days in the next 2 months. Looking for a travel buddy, open to anyone. Happy to split a cab. Up for treks.');
    c.setDate(DateTime(2026, 12, 12));
    expect(c.draft.value.text, startsWith('Heading to Manali for 4 days in December.'));
    c.setText('My own words.');
    c.setDays(6);
    expect(c.draft.value.text, 'My own words.');
    c.toggleChip('Budget trip');
    expect(c.draft.value.text, 'My own words. Budget trip.');
    c.toggleChip('Budget trip');
    expect(c.draft.value.text, 'My own words.');
  });

  for (final gender in ['Male', 'Female', 'Other']) {
    test('Free $gender poster: Men only is free, Women only shows the Plus lock and stays Anyone (spec 22)', () async {
      final server = installServer();
      final me = putSocialMe(server, socialMeWith(gender: gender));
      await me.load();
      final c = await ready(PostTripController(persist: false));
      expect(c.canWomenOnly, isFalse);
      c.setJoinGender('M');
      expect(c.genderLocked.value, isFalse);
      expect(c.draft.value.joinGender, 'M');
      c.setJoinGender('F');
      expect(c.genderLocked.value, isTrue);
      expect(c.draft.value.joinGender, 'A');
      c.setJoinGender('A');
      expect(c.genderLocked.value, isFalse);
      expect(c.draft.value.joinGender, 'A');
      c.setJoinGender('X');
      expect(c.draft.value.joinGender, 'A');
    });
  }

  test('with Plus any poster, also a man, can post a Women-only trip', () async {
    final server = installServer();
    final me = putSocialMe(server, socialMeWith(isPlus: true, genderOnly: true, gender: 'Male'));
    await me.load();
    final c = await ready(PostTripController(persist: false));
    expect(c.canWomenOnly, isTrue);
    c.setJoinGender('F');
    expect(c.genderLocked.value, isFalse);
    expect(c.draft.value.joinGender, 'F');
    c.toggleCity(manali);
    expect(c.draft.value.text, contains('women only'));
  });

  test('a restored Women-only draft without Plus falls back to Anyone; Men only is kept', () {
    final c = PostTripController(persist: false);
    expect(c.allowedJoin('A'), isTrue);
    expect(c.allowedJoin('M'), isTrue);
    expect(c.allowedJoin('F'), isFalse);
    expect(c.allowedJoin('X'), isFalse);
  });

  test('the draft is saved and restored for the same user', () async {
    installServer();
    await PostDraftStore.clear();
    final c = await ready(PostTripController());
    c.toggleCity(manali);
    c.setSeats(2);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(c.saved.value, isTrue);
    final again = await ready(PostTripController());
    expect(again.draft.value.cities.map((e) => e.name), ['Manali']);
    expect(again.draft.value.seats, 2);
    expect(again.saved.value, isTrue);
    expect(await PostDraftStore.read(userId: 'someone-else'), isNull);
    await PostDraftStore.clear();
  });

  test('create body: city keys in order, window or exact date, days, gender, seats, text', () async {
    final server = installServer();
    server.on('POST', '/social/trips', publicTripJson(id: 'new-1', isMine: true));
    final c = await ready(PostTripController(persist: false));
    c.toggleCity(manali);
    c.toggleCity(kasol);
    c.setDate(DateTime(2026, 12, 12));
    c.setDays(11);
    c.setSeats(11);
    final r = await c.submit();
    expect(r, isA<BuddyOk<PublicTrip>>());
    final body = server.calls('POST', '/social/trips').single.data as Map;
    expect(body['cityKeys'], [101, 102]);
    expect(body['whenKind'], 'exact');
    expect(body['startDate'], '2026-12-12');
    expect(body.containsKey('withinMonths'), isFalse);
    expect(body['days'], 11);
    expect(body['joinGender'], 'A');
    expect(body['seats'], 11);
    expect(body['text'], isNotEmpty);
    expect(body['clientTripId'], c.clientTripId);
  });

  test('from my trip: cities come from the trip, the wizard starts at When and publishes with PUT', () async {
    final server = installServer();
    server.on('PUT', '/social/trips/t-9/post', publicTripJson(id: 't-9', isMine: true));
    final c = await ready(PostTripController(
      tripId: 't-9',
      persist: false,
      loadTrip: (_) async => (cities: const [manali, kasol], startDate: null, days: 5),
    ));
    expect(c.step.value, PostTripController.stepWhen);
    expect(c.draft.value.cities.map((e) => e.name), ['Manali', 'Kasol']);
    expect(c.draft.value.days, 5);
    expect(c.toggleCity(manali), isNull);
    expect(c.draft.value.cities, hasLength(2));
    expect(c.back(), isFalse);
    await c.submit();
    final body = server.calls('PUT', '/social/trips/t-9/post').single.data as Map;
    expect(body.containsKey('cityKeys'), isFalse);
    expect(body['whenKind'], 'within');
    expect(body['withinMonths'], 2);
  });

  test('PostDraft.autoText follows the chosen join value, whatever the poster gender; unknown values read as anyone', () {
    const women = PostDraft(cities: [manali], joinGender: 'F', days: 3, withinMonths: 1);
    expect(women.autoText(), 'Heading to Manali for 3 days in the next month. Looking for a travel buddy, women only.');
    const men = PostDraft(cities: [manali], joinGender: 'M', days: 3, withinMonths: 1);
    expect(men.autoText(), contains('men only'));
    const odd = PostDraft(cities: [manali], joinGender: 'Z', days: 3, withinMonths: 1);
    expect(odd.autoText(), contains('open to anyone'));
  });
}
