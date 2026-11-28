import 'package:bakhli/features/social/b/data/public_trips_api.dart';
import 'package:bakhli/features/social/b/models/post_draft.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../shared/social_test_support.dart';
import 'social_b_test_kit.dart';

const _feed = '/social/trips/feed';

void main() {
  setUpAll(initSocialTestStorage);
  setUp(() {
    Get.reset();
    putSeeker();
  });
  tearDown(Get.reset);

  test('T3: feed sends travel only when a mode is picked', () async {
    final server = installServer();
    server.on('GET', _feed, feedPage());
    await const PublicTripsApi().feed(travel: 'taxi');
    await const PublicTripsApi().feed();
    final calls = server.calls('GET', _feed);
    expect(calls[0].queryParameters['travel'], 'taxi');
    expect(calls[1].queryParameters.containsKey('travel'), isFalse);
  });

  test('I-37: Explore reads only feed items; My posts comes from /social/trips/mine, newest first as sent', () async {
    final server = installServer();
    server.on('GET', _feed, feedPage(items: [publicTripJson(id: 'a')]));
    server.on('GET', minePath, minePage([publicTripJson(id: 'm2', isMine: true, waitingRequests: 3), publicTripJson(id: 'm1', isMine: true)]));
    final feed = (await const PublicTripsApi().feed()).valueOrNull!;
    expect(feed.items.map((t) => t.tripId), ['a']);
    final mine = (await const PublicTripsApi().mine()).valueOrNull!;
    expect(mine.map((t) => t.tripId), ['m2', 'm1']);
    expect(mine.first.isMine, isTrue);
    expect(mine.first.waitingRequests, 3);
    expect(server.calls('GET', minePath), hasLength(1));
  });

  test('T2/T5: the post body always carries travelMode and the answer is parsed', () async {
    final server = installServer();
    server.on('PUT', '/social/trips/t-1/post', publicTripJson(id: 't-1', isMine: true, travelMode: 'taxi'));
    final r = await const PublicTripsApi().publish('t-1', const PostDraft(travelMode: 'taxi'));
    expect((server.calls('PUT', '/social/trips/t-1/post').single.data as Map)['travelMode'], 'taxi');
    expect(r.valueOrNull?.travelMode, 'taxi');
    expect(const PostDraft().toJson()['travelMode'], TravelModes.taxi);
  });
}
