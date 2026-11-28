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

  group('I-38 edit post', () {
    PostTripController editC({DateTime? start}) => PostTripController(
          tripId: 't-9',
          edit: true,
          loadTrip: (_) async => (cities: const [manali, kasol], startDate: start, days: 3),
        );

    test('prefills from the live post: within months, text, seats, gender, travel mode; starts at When', () async {
      final server = installServer();
      server.on('GET', '/social/trips/t-9', publicTripJson(
        id: 't-9',
        isMine: true,
        when: const {'kind': 'within', 'months': 3},
        days: 3,
        joinGender: 'F',
        seats: 2,
        text: 'My own post words.',
        travelMode: 'bike',
      ));
      final c = await ready(editC());
      expect(c.editing, isTrue);
      expect(c.prepareFailed.value, isFalse);
      expect(c.step.value, PostTripController.stepWhen);
      final d = c.draft.value;
      expect(d.cities.map((e) => e.name), ['Manali', 'Kasol']);
      expect(d.whenKind, PostDraft.within);
      expect(d.withinMonths, 3);
      expect(d.days, 3);
      expect(d.joinGender, 'F', reason: 'a live Women only post is never turned into Anyone on edit');
      expect(d.seats, 2);
      expect(d.text, 'My own post words.');
      expect(d.textEdited, isTrue);
      expect(d.travelMode, 'bike');
      expect(c.saved.value, isFalse);
      expect(c.back(), isFalse);
    });

    test('a month post becomes exact with the trip start date; no travel mode reads as taxi', () async {
      final server = installServer();
      server.on('GET', '/social/trips/t-9', publicTripJson(id: 't-9', isMine: true));
      final c = await ready(editC(start: DateTime(2026, 12, 12, 9)));
      final d = c.draft.value;
      expect(d.whenKind, PostDraft.exact);
      expect(d.startDate, DateTime(2026, 12, 12));
      expect(d.travelMode, TravelModes.taxi);
    });

    test('a month post whose trip has no start date asks for the day before Next', () async {
      final server = installServer();
      server.on('GET', '/social/trips/t-9', publicTripJson(id: 't-9', isMine: true));
      final c = await ready(editC());
      expect(c.draft.value.whenKind, PostDraft.exact);
      expect(c.draft.value.startDate, isNull);
      expect(c.canNext(PostTripController.stepWhen), isFalse);
      c.setDate(DateTime(2026, 12, 20));
      expect(c.canNext(PostTripController.stepWhen), isTrue);
    });

    test('never reads, writes or clears the stored draft', () async {
      final server = installServer();
      server.on('GET', '/social/trips/t-9', publicTripJson(id: 't-9', isMine: true, seats: 2, text: 'Live text.'));
      server.on('PUT', '/social/trips/t-9/post', publicTripJson(id: 't-9', isMine: true));
      await PostDraftStore.init();
      await PostDraftStore.save(const PostDraft(seats: 1, text: 'Stored draft.', textEdited: true), userId: 'me', tripId: 't-9');
      final c = await ready(editC());
      expect(c.draft.value.text, 'Live text.');
      expect(c.draft.value.seats, 2);
      c.setSeats(3);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(c.saved.value, isFalse);
      expect((await PostDraftStore.read(userId: 'me', tripId: 't-9'))?.text, 'Stored draft.');
      await c.submit();
      expect((await PostDraftStore.read(userId: 'me', tripId: 't-9'))?.text, 'Stored draft.');
      await PostDraftStore.clear();
    });

    test('save = PUT /social/trips/{id}/post with notifyNearby false; the nearby switch is off', () async {
      final server = installServer();
      server.on('GET', '/social/trips/t-9', publicTripJson(id: 't-9', isMine: true, when: const {'kind': 'within', 'months': 2}));
      server.on('PUT', '/social/trips/t-9/post', publicTripJson(id: 't-9', isMine: true));
      final c = await ready(editC());
      expect(c.canNotifyNearby, isFalse);
      c.setNotifyNearby(true);
      expect(c.draft.value.notifyNearby, isFalse);
      c.setSeats(1);
      final r = await c.submit();
      expect(r, isA<BuddyOk<PublicTrip>>());
      final body = server.calls('PUT', '/social/trips/t-9/post').single.data as Map;
      expect(body['notifyNearby'], isFalse);
      expect(body['seats'], 1);
      expect(body.containsKey('cityKeys'), isFalse);
      expect(server.calls('POST', '/social/trips'), isEmpty);
    });

    test('a post that is not mine, or is gone, fails to prepare', () async {
      final server = installServer();
      server.on('GET', '/social/trips/t-9', publicTripJson(id: 't-9'));
      final other = await ready(editC());
      expect(other.prepareFailed.value, isTrue);
      final gone = installServer();
      final missing = await ready(editC());
      expect(missing.prepareFailed.value, isTrue);
      expect(gone.calls('GET', '/social/trips/t-9'), hasLength(1));
      expect(server.calls('GET', '/social/trips/t-9'), hasLength(1));
    });

    test('edit without a trip id is a normal new post', () {
      expect(PostTripController(edit: true, persist: false).editing, isFalse);
    });
  });

  test('PostDraft.fromPost clamps days and months', () {
    final p = PublicTrip.fromJson(publicTripJson(when: const {'kind': 'within', 'months': 9}, days: 7, isMine: true));
    final d = PostDraft.fromPost(p, cities: const [manali]);
    expect(d.withinMonths, PostDraft.maxMonths);
    expect(d.days, PostDraft.maxDays);
    final month = PostDraft.fromPost(PublicTrip.fromJson(publicTripJson(isMine: true)), cities: const [manali]);
    expect(month.whenKind, PostDraft.exact, reason: 'a month post is never silently turned into a window');
    expect(month.startDate, isNull);
    expect(month.whenReady, isFalse, reason: 'with no trip start date the user picks the day again');
  });
}
