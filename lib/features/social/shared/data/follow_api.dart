import '../../../../services/api_service.dart';
import '../../../buddy/shared/buddy_api_base.dart';
import '../../../buddy/shared/buddy_json.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../social_models.dart';

class PeoplePage {
  const PeoplePage({required this.items, this.nextCursor, this.total = 0, this.buddies = 0});

  final List<PersonRow> items;
  final String? nextCursor;
  final int total;
  final int buddies;

  bool get hasMore => nextCursor != null;

  factory PeoplePage.fromJson(Map<String, dynamic> j) => PeoplePage(
        items: BuddyJson.list(j['items'], PersonRow.fromJson),
        nextCursor: BuddyJson.strOrNull(j['nextCursor']),
        total: BuddyJson.integer(j['total']),
        buddies: BuddyJson.integer(j['buddies']),
      );
}

class FollowApi {
  const FollowApi();

  static const String stateFollowing = 'following';
  static const String stateRequested = 'requested';

  Future<BuddyResult<String>> follow(String userId) => BuddyApiBase.run(() async =>
      BuddyJson.str(BuddyApiBase.dataOf(await ApiService.put('/social/travellers/$userId/follow', const {}))['state'], stateFollowing));

  Future<BuddyResult<void>> unfollow(String userId) =>
      BuddyApiBase.run(() async => ApiService.deleteJson('/social/travellers/$userId/follow'));

  Future<BuddyResult<PeoplePage>> followers({String? cursor, String? q}) => BuddyApiBase.run(() async => PeoplePage.fromJson(BuddyApiBase.dataOf(
      await BuddyApiBase.read(() => ApiService.get('/social/followers', params: BuddyApiBase.query({'cursor': cursor, 'q': q}))))));

  Future<BuddyResult<PeoplePage>> following({String? cursor}) => BuddyApiBase.run(() async => PeoplePage.fromJson(BuddyApiBase.dataOf(
      await BuddyApiBase.read(() => ApiService.get('/social/following', params: BuddyApiBase.query({'cursor': cursor}))))));

  Future<BuddyResult<void>> removeFollower(String userId) =>
      BuddyApiBase.run(() async => ApiService.deleteJson('/social/followers/$userId'));

  Future<BuddyResult<PeoplePage>> requests({String? cursor}) => BuddyApiBase.run(() async => PeoplePage.fromJson(BuddyApiBase.dataOf(
      await BuddyApiBase.read(() => ApiService.get('/social/follow-requests', params: BuddyApiBase.query({'cursor': cursor}))))));

  Future<BuddyResult<void>> acceptRequest(String userId) =>
      BuddyApiBase.run(() async => ApiService.post('/social/follow-requests/$userId/accept', const {}));

  Future<BuddyResult<void>> declineRequest(String userId) =>
      BuddyApiBase.run(() async => ApiService.post('/social/follow-requests/$userId/decline', const {}));

  Future<BuddyResult<void>> addBuddy(String userId) => BuddyApiBase.run(() async => ApiService.put('/social/buddies/$userId', const {}));

  Future<BuddyResult<void>> removeBuddy(String userId) => BuddyApiBase.run(() async => ApiService.deleteJson('/buddies/$userId'));
}
