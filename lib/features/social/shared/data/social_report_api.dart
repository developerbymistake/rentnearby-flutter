import '../../../../services/api_service.dart';
import '../../../buddy/shared/buddy_api_base.dart';
import '../../../buddy/shared/buddy_result.dart';

class SocialReportApi {
  const SocialReportApi();

  Future<BuddyResult<void>> reportTripPost(String tripId, {required String reasonId, String? note, bool alsoBlock = false}) =>
      BuddyApiBase.run(() async => ApiService.post('/social/reports', {
            'scope': 'TripPost',
            'tripId': tripId,
            'reasonId': reasonId,
            'note': ?note,
            'alsoBlock': alsoBlock,
          }));

  Future<BuddyResult<void>> reportMessage(String roomId, int seq, {required String reasonId, String? note, bool alsoBlock = false}) =>
      BuddyApiBase.run(() async => ApiService.post('/social/reports', {
            'scope': 'Message',
            'roomId': roomId,
            'seq': seq,
            'reasonId': reasonId,
            'note': ?note,
            'alsoBlock': alsoBlock,
          }));
}
