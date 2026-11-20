import '../../../../services/api_service.dart';
import '../../shared/buddy_api_base.dart';
import '../../shared/buddy_json.dart';
import '../../shared/buddy_result.dart';
import '../models/sharing_models.dart';

class TripMembersApi {
  const TripMembersApi();

  Future<BuddyResult<TripMembers>> members(String tripId) => BuddyApiBase.run(() async =>
      TripMembers.fromJson(BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('/trips/$tripId/members')))));

  Future<BuddyResult<InviteResult>> invite(String tripId, List<String> userIds, {required String clientRequestId}) =>
      BuddyApiBase.run(() async => InviteResult.fromJson(
          BuddyApiBase.dataOf(await ApiService.post('/trips/$tripId/invites', {'userIds': userIds, 'clientRequestId': clientRequestId}))));

  Future<BuddyResult<void>> cancelInvite(String tripId, String userId) =>
      BuddyApiBase.run(() async => ApiService.deleteJson('/trips/$tripId/invites/$userId'));

  Future<BuddyResult<RemoveResult>> remove(String tripId, String userId) => BuddyApiBase.run(
      () async => RemoveResult.fromJson(BuddyApiBase.dataOf(await ApiService.deleteJson('/trips/$tripId/members/$userId'))));

  Future<BuddyResult<int>> expenseCount(String tripId, String userId) => BuddyApiBase.run(() async => BuddyJson.integer(BuddyApiBase.dataOf(
      await BuddyApiBase.read(() => ApiService.get('/trips/$tripId/members/$userId/expense-count')))['count']));

  Future<BuddyResult<List<InviteOption>>> inviteOptions(String userId) => BuddyApiBase.run(() async => [
        for (final o in BuddyApiBase.listOf(await BuddyApiBase.read(() => ApiService.get('/trips/invite-options', params: {'userId': userId}))))
          if (o is Map) InviteOption.fromJson(BuddyJson.map(o)),
      ]);

  Future<BuddyResult<void>> deleteTrip(String tripId) => BuddyApiBase.run(() async => ApiService.deleteJson('/trips/$tripId'));
}
