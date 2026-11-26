import '../../../../services/api_service.dart';
import '../../../buddy/shared/buddy_api_base.dart';
import '../../../buddy/shared/buddy_json.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../shared/social_models.dart';
import '../models/post_draft.dart';

class FeedPage {
  const FeedPage({this.mine = const [], this.items = const [], this.nextCursor});

  final List<PublicTrip> mine;
  final List<PublicTrip> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  factory FeedPage.fromJson(Map<String, dynamic> j) => FeedPage(
        mine: BuddyJson.list(j['mine'], PublicTrip.fromJson),
        items: BuddyJson.list(j['items'], PublicTrip.fromJson),
        nextCursor: BuddyJson.strOrNull(j['nextCursor']),
      );
}

class PublicTripsApi {
  const PublicTripsApi();

  Future<BuddyResult<FeedPage>> feed({String? cursor, String? q, String who = 'any', bool near = false, double? lat, double? lng}) =>
      BuddyApiBase.run(() async => FeedPage.fromJson(BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get(
            '/social/trips/feed',
            params: BuddyApiBase.query({
              'cursor': cursor,
              'q': q == null || q.trim().isEmpty ? null : q.trim(),
              'who': who == 'any' ? null : who,
              'near': near ? true : null,
              'lat': near ? lat : null,
              'lng': near ? lng : null,
            }),
          )))));

  Future<BuddyResult<List<PublicTrip>>> rail() => BuddyApiBase.run(() async =>
      BuddyJson.list(BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('/social/trips/rail')))['items'], PublicTrip.fromJson));

  Future<BuddyResult<PublicTrip>> post(String tripId) =>
      BuddyApiBase.run(() async => PublicTrip.fromJson(BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('/social/trips/$tripId')))));

  Future<BuddyResult<PublicTrip>> create(PostDraft d, {required String clientTripId}) => BuddyApiBase.run(() async => PublicTrip.fromJson(
      BuddyApiBase.dataOf(await ApiService.post('/social/trips', {
        'clientTripId': clientTripId,
        'cityKeys': [for (final c in d.cities) c.cityKey],
        ...d.toJson(),
      }))));

  Future<BuddyResult<PublicTrip>> publish(String tripId, PostDraft d) =>
      BuddyApiBase.run(() async => PublicTrip.fromJson(BuddyApiBase.dataOf(await ApiService.put('/social/trips/$tripId/post', d.toJson()))));

  Future<BuddyResult<void>> unpublish(String tripId) => BuddyApiBase.run(() async => ApiService.deleteJson('/social/trips/$tripId/post'));
}
