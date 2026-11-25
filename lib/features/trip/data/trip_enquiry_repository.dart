import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../utils/network_retry.dart';
import '../enquiries/similar_stays.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_offer_model.dart';
import '../models/trip_shortlist_model.dart';

typedef ShortlistWithSteps = ({TripShortlist shortlist, Map<String, TripStepSlots> steps});

class TripEnquiryErrorTypes {
  static const String tripDatesRequired = 'TripDatesRequired';
  static const String dayInPast = 'DayInPast';
  static const String nightAlreadyConfirmed = 'NightAlreadyConfirmed';
  static const String offerExpired = 'OfferExpired';
  static const String offerNotPending = 'OfferNotPending';
  static const String enquiryClosed = 'TripEnquiryClosed';
  static const String executionDisabled = 'TripExecutionDisabled';
  static const String concurrent = 'CONCURRENT_UPDATE';
  static const String notOwner = 'NotEnquiryOwner';
  static const String notTraveller = 'NotEnquiryTraveller';
  static const String fareEditLimit = 'FareEditLimit';
  static const String dayAlreadyBooked = 'DayAlreadyBooked';
  static const String leadLimit = 'LeadLimitReached';
  static const String tabInactive = 'TabInactive';
  static const String counterLimit = 'CounterLimit';
  static const String counterNotAllowed = 'CounterNotAllowed';
  static const String revisedNotAllowed = 'RevisedNotAllowed';
  static const String changeNotAllowed = 'ChangeNotAllowed';
  static const String changeNotPending = 'ChangeNotPending';
  static const String nothingChanged = 'NothingChanged';
  static const String tripNotEnded = 'TripNotEnded';
  static const String problemOutsideTrip = 'ProblemOutsideTrip';
  static const String offerLimit = 'OfferLimit';
  static const String enquiryLimit = 'EnquiryLimitReached';
  static const String enquiryEnded = 'EnquiryEnded';
  static const String offerOutsideTrip = 'OfferOutsideTrip';
  static const String stepFull = 'StepFull';
  static const String undoWindowOver = 'UndoWindowOver';
  static const String enquiryAlreadyOpen = 'EnquiryAlreadyOpen';
  static const String notShortlisted = 'NotShortlisted';
}

class TripEnquiryRepository {
  const TripEnquiryRepository();

  Map<String, dynamic> _data(Map<String, dynamic> res) {
    final data = res['data'];
    return data is Map<String, dynamic> ? data : const {};
  }

  TripEnquiryModel _one(Map<String, dynamic> res) => TripEnquiryModel.fromJson(_data(res));

  static const String asksLeftHeader = 'x-trip-asks-left';

  static int? asksLeftOf(Response? res) => int.tryParse(res?.headers.value(asksLeftHeader) ?? '');

  Future<TripEnquiryBatch> _batch(String path, Map<String, dynamic> body) async {
    final res = await ApiService.postRaw(path, body);
    final raw = res.data;
    final map = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return TripEnquiryBatch.fromJson(_data(map), asksLeft: asksLeftOf(res));
  }

  Future<TripEnquiryBatch> create(String tripId,
          {required int day, required List<String> stayIds, required int nights, String? clientRequestId, String? stepKey}) =>
      _batch('/trips/$tripId/enquiries', {
        'clientRequestId': ?clientRequestId,
        'stepKey': ?stepKey,
        'kind': TripEnquiryKinds.stay,
        'day': day,
        'listingIds': stayIds,
        'allNights': nights > 1,
        'nights': nights,
        'sharePhone': true,
      });

  Future<TripEnquiryModel> taxiBooking(String tripId, Map<String, dynamic> body) async =>
      _one(await ApiService.post('/trips/$tripId/taxi-bookings', body));

  Future<TripEnquiryModel> journeyCarBooking(
    String tripId, {
    required String journeyId,
    required int journeyLegIndex,
    required String taxiId,
    int? agreedFare,
    required bool tollExtra,
    required String pickupTime,
    required String pickupPlace,
    List<String> replaceEnquiryIds = const [],
  }) =>
      taxiBooking(tripId, {
        'taxiId': taxiId,
        'days': const <int>[],
        'agreedFare': ?agreedFare,
        'tollExtra': tollExtra,
        'pickupTime': pickupTime,
        'pickupPlace': pickupPlace,
        'closeOthers': true,
        if (replaceEnquiryIds.isNotEmpty) 'replaceEnquiryIds': replaceEnquiryIds,
        'journeyId': journeyId,
        'journeyLegIndex': journeyLegIndex,
      });

  Future<TripEnquiryModel> updateLead(String enquiryId) async =>
      _one(await ApiService.post('/trips/enquiries/$enquiryId/lead-update', const {}));

  Future<TripEnquiryModel> refreshContext(String enquiryId) async =>
      _one(await ApiService.post('/trips/enquiries/$enquiryId/refresh-context', const {}));

  Future<TripEnquiryModel> withdraw(String enquiryId, {bool undo = false}) async =>
      _one(await ApiService.post('/trips/enquiries/$enquiryId/withdraw${undo ? '?undo=true' : ''}', const {}));

  Future<ShortlistWithSteps> shortlistWithSteps(String tripId) async {
    final res = await ApiService.get('/trips/$tripId/shortlist');
    final d = res['data'];
    final data = d is Map<String, dynamic> ? d : res;
    return (shortlist: TripShortlist.fromJson(data), steps: TripStepSlots.mapOf(data['steps']));
  }

  Future<TripEnquiryModel> restore(String enquiryId) async =>
      _one(await ApiService.post('/trips/enquiries/$enquiryId/restore', const {}));

  Future<MyEnquiryPage> mine({required String bucket, String? cursor, bool counts = true, int pageSize = 20}) async =>
      MyEnquiryPage.fromJson(_data(await withRetry(() => ApiService.get('/trips/enquiries/mine', params: {
            'bucket': bucket,
            'pageSize': pageSize,
            'cursor': ?cursor,
            if (!counts) 'counts': false,
          }))));

  Future<SimilarStays> similar({required String tripId, required String stepKey, String? likeListingId, int limit = 3}) async =>
      SimilarStays.fromJson(_data(await withRetry(() => ApiService.get(
            '/trips/$tripId/steps/${Uri.encodeComponent(stepKey)}/similar-stays',
            params: {'like': ?likeListingId, 'limit': limit},
          ))));

  Future<TripEnquiryModel> cancel(String enquiryId, {String? reason}) async =>
      _one(await ApiService.post('/trips/enquiries/$enquiryId/cancel', {'reason': ?reason}));

  Future<TripEnquiryModel> acceptOffer(String enquiryId, String offerId,
          {bool closeOthers = true, String? replaceEnquiryId}) async =>
      _one(await ApiService.post('/trips/enquiries/$enquiryId/offers/$offerId/accept', {
        'closeOthers': closeOthers,
        'replaceEnquiryId': ?replaceEnquiryId,
      }));

  Future<TripEnquiryModel> declineOffer(String enquiryId, String offerId) async =>
      _one(await ApiService.post('/trips/enquiries/$enquiryId/offers/$offerId/decline', const {}));

  Future<TripEnquiryModel> get(String enquiryId) async =>
      _one(await withRetry(() => ApiService.get('/trips/enquiries/$enquiryId')));

  Future<TripEnquiryModel?> byConversation(String conversationId) async {
    try {
      return _one(await withRetry(() => ApiService.get('/trips/enquiries/by-conversation/$conversationId')));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<TripOwnerEnquiryPage> ownerList({required String status, int page = 1, int pageSize = 20}) async =>
      TripOwnerEnquiryPage.fromJson(_data(await withRetry(() => ApiService.get('/trips/enquiries/owner', params: {
            'status': status,
            'page': page,
            'pageSize': pageSize,
          }))));

  Future<({TripEnquiryModel enquiry, TripOfferModel offer})> sendOffer(String enquiryId, Map<String, dynamic> body) async {
    final data = _data(await ApiService.post('/trips/enquiries/$enquiryId/offers', body));
    return (
      enquiry: TripEnquiryModel.fromJson((data['enquiry'] as Map<String, dynamic>?) ?? const {}),
      offer: TripOfferModel.fromJson((data['offer'] as Map<String, dynamic>?) ?? const {}),
    );
  }

  ({TripEnquiryModel enquiry, TripOfferModel offer}) _offerResult(Map<String, dynamic> res) {
    final data = _data(res);
    return (
      enquiry: TripEnquiryModel.fromJson((data['enquiry'] as Map<String, dynamic>?) ?? const {}),
      offer: TripOfferModel.fromJson((data['offer'] as Map<String, dynamic>?) ?? const {}),
    );
  }

  Future<({TripEnquiryModel enquiry, TripOfferModel offer})> revisedOffer(
          String enquiryId, Map<String, dynamic> body) async =>
      _offerResult(await ApiService.post('/trips/enquiries/$enquiryId/revised-offer', body));

  Future<TripEnquiryModel> acceptChange(String enquiryId, String offerId) async =>
      _one(await ApiService.post('/trips/enquiries/$enquiryId/change-request/$offerId/accept', const {}));

  Future<String> reportTraveller(String enquiryId, {required String reasonId, String? details}) async {
    final data = _data(await ApiService.post('/trips/enquiries/$enquiryId/report-traveller', {
      'reasonId': reasonId,
      'details': ?details,
    }));
    return data['reportId'] as String? ?? '';
  }

  Future<TripEnquiryModel> notAvailable(String enquiryId) async =>
      _one(await ApiService.post('/trips/enquiries/$enquiryId/not-available', const {}));
}
