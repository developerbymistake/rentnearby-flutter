import '../../../services/api_service.dart';
import '../shared/buddy_api_base.dart';
import '../shared/buddy_result.dart';
import 'trip_limit_models.dart';

class TripLimitApi {
  const TripLimitApi();

  Future<BuddyResult<TripSlots>> slots() => BuddyApiBase.run(() async => TripSlots.fromRefusal(BuddyApiBase.dataOf(await ApiService.get('/trips/slots'))));
}
