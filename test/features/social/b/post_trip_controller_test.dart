import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/b/models/post_draft.dart';
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

  test('I-6 Where: Ready cities only, ONE city: a tap picks, another tap replaces, the same tap clears; no state filter', () async {
    installServer();
    final c = await ready(PostTripController(persist: false));
    expect(c.visibleCities().map((e) => e.name), isNot(contains('Chopta')));
    expect(c.visibleCities().map((e) => e.name), containsAll(['Manali', 'Rishikesh']));
    expect(c.canNext(PostTripController.stepWhere), isFalse);
    c.toggleCity(manali);
    expect(c.draft.value.cities.map((e) => e.name), ['Manali']);
    expect(c.visibleCities().map((e) => e.name), containsAll(['Manali', 'Rishikesh']), reason: 'no state filter after the pick');
    c.toggleCity(rishikesh);
    expect(c.draft.value.cities.map((e) => e.name), ['Rishikesh']);
    c.toggleCity(kasol);
    expect(c.draft.value.cities.map((e) => e.name), ['Kasol']);
    expect(c.canNext(PostTripController.stepWhere), isTrue);
    c.toggleCity(kasol);
    expect(c.draft.value.cities, isEmpty);
    expect(c.canNext(PostTripController.stepWhere), isFalse);
  });

  test('I-6 How long: a post is 1 to 4 days', () async {
    installServer();
    final c = await ready(PostTripController(persist: false));
    c.setDays(11);
    expect(c.draft.value.days, PostDraft.maxDays);
    expect(PostDraft.maxDays, 4);
    c.setDays(0);
    expect(c.draft.value.days, 1);
    expect(PostDraft.fromStore({...const PostDraft().toStore(), 'days': 11}).days, 4);
  });

  test('I-6: an older saved draft with several cities keeps only the first one', () async {
    installServer();
    await PostDraftStore.init();
    await PostDraftStore.save(const PostDraft(cities: [manali, kasol]), userId: 'me');
    final c = await ready(PostTripController());
    expect(c.draft.value.cities.map((e) => e.name), ['Manali']);
    await PostDraftStore.clear();
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
    c.setDate(DateTime(2026, 12, 12));
    c.setDays(4);
    c.setSeats(11);
    final r = await c.submit();
    expect(r, isA<BuddyOk<PublicTrip>>());
    final body = server.calls('POST', '/social/trips').single.data as Map;
    expect(body['cityKeys'], [101]);
    expect(body['whenKind'], 'exact');
    expect(body['startDate'], '2026-12-12');
    expect(body.containsKey('withinMonths'), isFalse);
    expect(body['days'], 4);
    expect(body['joinGender'], 'A');
    expect(body['seats'], 11);
    expect(body['text'], isNotEmpty);
    expect(body['clientTripId'], c.clientTripId);
    expect(body['travelMode'], TravelModes.taxi, reason: 'I-1: Taxi, the first option, is picked by default');
  });

  test('T2: the picked travel mode goes in the create body; unknown codes are ignored', () async {
    final server = installServer();
    server.on('POST', '/social/trips', publicTripJson(id: 'new-2', isMine: true, travelMode: 'bike'));
    final c = await ready(PostTripController(persist: false));
    c.toggleCity(manali);
    c.setTravelMode('bike');
    c.setTravelMode('plane');
    expect(c.draft.value.travelMode, 'bike');
    final r = await c.submit();
    expect((r as BuddyOk<PublicTrip>).value.travelMode, 'bike');
    expect((server.calls('POST', '/social/trips').single.data as Map)['travelMode'], 'bike');
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
    expect(c.draft.value.days, 4, reason: 'I-6: a post is at most 4 days');
    c.toggleCity(manali);
    expect(c.draft.value.cities, hasLength(2));
    expect(c.back(), isFalse);
    await c.submit();
    final body = server.calls('PUT', '/social/trips/t-9/post').single.data as Map;
    expect(body.containsKey('cityKeys'), isFalse);
    expect(body['whenKind'], 'within');
    expect(body['withinMonths'], 2);
    expect(body['travelMode'], TravelModes.taxi, reason: 'PUT replaces the stored value, so the current choice is always sent');
  });

  test('the stored draft keeps the travel mode; an old draft without it or with an old or bad value starts on Taxi', () {
    final d = PostDraft.fromStore(const PostDraft(travelMode: 'train').toStore());
    expect(d.travelMode, 'train');
    final old = const PostDraft().toStore()..remove('travelMode');
    expect(PostDraft.fromStore(old).travelMode, TravelModes.taxi);
    for (final bad in ['plane', 'public', 'car']) {
      expect(PostDraft.fromStore({...const PostDraft().toStore(), 'travelMode': bad}).travelMode, TravelModes.taxi);
    }
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
