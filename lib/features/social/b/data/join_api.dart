import '../../../../services/api_service.dart';
import '../../../buddy/shared/buddy_api_base.dart';
import '../../../buddy/shared/buddy_json.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../shared/social_models.dart';

class JoinRequestItem {
  const JoinRequestItem({required this.id, required this.person, this.tier = 2, this.note, this.interests = const [], this.createdAt});

  static const int tierBuddy = 0;
  static const int tierFollower = 1;
  static const int tierOther = 2;

  final String id;
  final PersonRow person;
  final int tier;
  final String? note;
  final List<String> interests;
  final DateTime? createdAt;

  factory JoinRequestItem.fromJson(Map<String, dynamic> j) {
    final tier = BuddyJson.integer(j['tier'], tierOther);
    final note = BuddyJson.strOrNull(j['note'])?.trim();
    return JoinRequestItem(
      id: BuddyJson.str(j['id']),
      person: PersonRow.fromJson(BuddyJson.map(j['person'])),
      tier: tier < tierBuddy || tier > tierOther ? tierOther : tier,
      note: note == null || note.isEmpty ? null : note,
      interests: BuddyJson.strings(j['interests']),
      createdAt: BuddyJson.time(j['createdAt']),
    );
  }
}

class JoinRequestsPage {
  const JoinRequestsPage({required this.trip, this.items = const []});

  final PublicTrip trip;
  final List<JoinRequestItem> items;

  factory JoinRequestsPage.fromJson(Map<String, dynamic> j) =>
      JoinRequestsPage(trip: PublicTrip.fromJson(BuddyJson.map(j['trip'])), items: BuddyJson.list(j['items'], JoinRequestItem.fromJson));
}

class JoinAccepted {
  const JoinAccepted({required this.memberId, required this.seatsLeft, required this.roomId});

  final String memberId;
  final int seatsLeft;
  final String roomId;

  factory JoinAccepted.fromJson(Map<String, dynamic> j) =>
      JoinAccepted(memberId: BuddyJson.str(j['memberId']), seatsLeft: BuddyJson.integer(j['seatsLeft']), roomId: BuddyJson.str(j['roomId']));
}

class JoinApi {
  const JoinApi();

  static const int noteMax = 200;

  Future<BuddyResult<String>> send(String tripId, {String? note, required String clientRequestId}) => BuddyApiBase.run(() async => BuddyJson.str(
      BuddyApiBase.dataOf(await ApiService.post('/social/trips/$tripId/join-requests', {
        'note': note == null || note.trim().isEmpty ? null : note.trim(),
        'clientRequestId': clientRequestId,
      }))['id']));

  Future<BuddyResult<void>> cancel(String tripId) => BuddyApiBase.run(() async => ApiService.deleteJson('/social/trips/$tripId/join-requests/mine'));

  Future<BuddyResult<JoinRequestsPage>> list(String tripId) => BuddyApiBase.run(() async =>
      JoinRequestsPage.fromJson(BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('/social/trips/$tripId/join-requests')))));

  Future<BuddyResult<JoinAccepted>> accept(String id, {required bool addToBuddies}) => BuddyApiBase.run(() async =>
      JoinAccepted.fromJson(BuddyApiBase.dataOf(await ApiService.post('/social/join-requests/$id/accept', {'addToBuddies': addToBuddies}))));

  Future<BuddyResult<void>> decline(String id) => BuddyApiBase.run(() async => ApiService.post('/social/join-requests/$id/decline', const {}));
}
