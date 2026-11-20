import '../../../../services/api_service.dart';
import '../../shared/buddy_api_base.dart';
import '../../shared/buddy_json.dart';
import '../../shared/buddy_result.dart';
import '../models/viewer_models.dart';

class TripViewerApi {
  const TripViewerApi();

  Future<BuddyResult<InvitePreview>> invitePreview(String memberId) => BuddyApiBase.run(() async =>
      InvitePreview.fromJson(BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('/trips/invites/$memberId')))));

  Future<BuddyResult<String>> acceptInvite(String memberId) => BuddyApiBase.run(
      () async => BuddyJson.str(BuddyApiBase.dataOf(await ApiService.post('/trips/invites/$memberId/accept', const {}))['tripId']));

  Future<BuddyResult<void>> declineInvite(String memberId) =>
      BuddyApiBase.run(() async => ApiService.post('/trips/invites/$memberId/decline', const {}));

  Future<BuddyResult<LeaveResult>> leave(String tripId) =>
      BuddyApiBase.run(() async => LeaveResult.fromJson(BuddyApiBase.dataOf(await ApiService.post('/trips/$tripId/leave', const {}))));

  Future<BuddyResult<ViewerTripResponse>> view(String tripId, {String? etag}) => BuddyApiBase.run(() async {
        final res = await BuddyApiBase.read(
            () => ApiService.getRaw('/trips/$tripId/view', headers: etag == null ? null : {'If-None-Match': etag}));
        final tag = res.headers.value('etag') ?? etag;
        if (res.statusCode == 304) return ViewerTripResponse(notModified: true, etag: tag);
        return ViewerTripResponse(notModified: false, etag: tag, trip: ViewerTrip.fromJson(BuddyJson.map(BuddyJson.map(res.data)['data'])));
      });

  Future<BuddyResult<SharedTrips>> shared({String state = 'upcoming', String? cursor}) => BuddyApiBase.run(() async => SharedTrips.fromJson(
      BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('/trips/shared', params: BuddyApiBase.query({'state': state, 'cursor': cursor}))))));

  static InviteEnded? inviteEndedOf(BuddyRefused<Object?> r) => r.type == 'InviteEnded' ? InviteEnded.fromJson(r.data) : null;

  static NotOnTripInfo? notOnTripOf(BuddyRefused<Object?> r) => r.type == 'NotOnTrip' ? NotOnTripInfo.fromJson(r.data) : null;
}
