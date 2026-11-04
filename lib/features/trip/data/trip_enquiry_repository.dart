import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../utils/network_retry.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_offer_model.dart';

class TripEnquiryErrorTypes {
  static const String tripDatesRequired = 'TripDatesRequired';
  static const String dayInPast = 'DayInPast';
  static const String nightAlreadyConfirmed = 'NightAlreadyConfirmed';
  static const String offerExpired = 'OfferExpired';
  static const String offerNotPending = 'OfferNotPending';
  static const String enquiryClosed = 'TripEnquiryClosed';
  static const String phoneBookingPaused = 'PhoneBookingPaused';
  static const String resendTooSoon = 'HostLinkResendTooSoon';
  static const String linkLimit = 'HostLinkLimit';
  static const String executionDisabled = 'TripExecutionDisabled';
  static const String concurrent = 'CONCURRENT_UPDATE';
  static const String notOwner = 'NotEnquiryOwner';
  static const String notTraveller = 'NotEnquiryTraveller';
  static const String advanceNotAllowed = 'AdvanceNotAllowed';
  static const String holdExpired = 'HoldExpired';
  static const String travellerMovedOn = 'TravellerMovedOn';
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
  static const String askAgainNothing = 'AskAgainNothing';
  static const String tripNotEnded = 'TripNotEnded';
  static const String problemOutsideTrip = 'ProblemOutsideTrip';
  static const String offerLimit = 'OfferLimit';
  static const String enquiryLimit = 'EnquiryLimitReached';
  static const String enquiryEnded = 'EnquiryEnded';
  static const String offerOutsideTrip = 'OfferOutsideTrip';
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

  Future<TripEnquiryBatch> create(String tripId, {required int day, required List<String> stayIds, required bool allNights}) =>
      _batch('/trips/$tripId/enquiries', {
        'kind': TripEnquiryKinds.stay,
        'day': day,
        'listingIds': stayIds,
        'allNights': allNights,
      });

  Future<TripEnquiryBatch> createLead(String tripId,
          {required List<int> days, required List<String> taxiIds, String? pickupTime, String? pickupPlace}) =>
      _batch('/trips/$tripId/enquiries', {
        'kind': TripEnquiryKinds.taxi,
        'days': days,
        'listingIds': taxiIds,
        'pickupTime': ?pickupTime,
        'pickupPlace': ?pickupPlace,
      });

  Future<TripEnquiryModel> taxiBooking(String tripId, Map<String, dynamic> body) async =>
      _one(await ApiService.post('/trips/$tripId/taxi-bookings', body));

  Future<TripEnquiryModel> askAdvance(String enquiryId,
          {required int amount, required DateTime holdUntil, required String upiId, required String whatsAppNumber}) async =>
      _one(await ApiService.post('/trips/enquiries/$enquiryId/advance/ask', {
        'amount': amount,
        'holdUntil': holdUntil.toUtc().toIso8601String(),
        'upiId': upiId,
        'whatsAppNumber': whatsAppNumber,
      }));

  Future<TripEnquiryModel> proofSent(String enquiryId) async =>
      _one(await ApiService.post('/trips/enquiries/$enquiryId/advance/proof-sent', const {}));

  Future<TripEnquiryModel> advanceReceived(String enquiryId) async =>
      _one(await ApiService.post('/trips/enquiries/$enquiryId/advance/received', const {}));

  Future<TripEnquiryModel> advanceNotYet(String enquiryId) async =>
      _one(await ApiService.post('/trips/enquiries/$enquiryId/advance/not-yet', const {}));

  Future<TripPhoneBookingResult> createPhoneBooking(String tripId, Map<String, dynamic> body) async =>
      TripPhoneBookingResult.fromJson(_data(await ApiService.post('/trips/$tripId/phone-bookings', body)));

  Future<TripPhoneBookingResult> editPhoneBooking(String enquiryId, Map<String, dynamic> body) async =>
      TripPhoneBookingResult.fromJson(_data(await ApiService.put('/trips/enquiries/$enquiryId/phone-booking', body)));

  Future<TripPhoneBookingResult> resendHostLink(String enquiryId) async => TripPhoneBookingResult.fromJson(
      _data(await ApiService.post('/trips/enquiries/$enquiryId/host-confirm-link/resend', const {})));

  Future<TripEnquiryModel> withdraw(String enquiryId) async =>
      _one(await ApiService.post('/trips/enquiries/$enquiryId/withdraw', const {}));

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

  Future<({TripEnquiryModel enquiry, TripOfferModel offer})> counter(String enquiryId,
          {required int pricePerNight, String? note}) async =>
      _offerResult(await ApiService.post('/trips/enquiries/$enquiryId/counter', {
        'pricePerNight': pricePerNight,
        'note': ?note,
      }));

  Future<({TripEnquiryModel enquiry, TripOfferModel offer})> changeRequest(
          String enquiryId, Map<String, dynamic> body) async =>
      _offerResult(await ApiService.post('/trips/enquiries/$enquiryId/change-request', body));

  Future<({TripEnquiryModel enquiry, TripOfferModel offer})> revisedOffer(
          String enquiryId, Map<String, dynamic> body) async =>
      _offerResult(await ApiService.post('/trips/enquiries/$enquiryId/revised-offer', body));

  Future<TripEnquiryModel> acceptChange(String enquiryId, String offerId) async =>
      _one(await ApiService.post('/trips/enquiries/$enquiryId/change-request/$offerId/accept', const {}));

  Future<TripEnquiryBatch> askAgain(String tripId, {required String kind, required int day}) =>
      _batch('/trips/$tripId/enquiries/ask-again', {'kind': kind, 'day': day});

  Future<String> reportTraveller(String enquiryId, {required String reasonId, String? details}) async {
    final data = _data(await ApiService.post('/trips/enquiries/$enquiryId/report-traveller', {
      'reasonId': reasonId,
      'details': ?details,
    }));
    return data['reportId'] as String? ?? '';
  }

  Future<TripEnquiryModel> notAvailable(String enquiryId) async =>
      _one(await ApiService.post('/trips/enquiries/$enquiryId/not-available', const {}));

  Future<TripEnquiryModel> hostConfirm(String enquiryId, {required bool confirm}) async =>
      _one(await ApiService.post('/trips/enquiries/$enquiryId/host-confirm', {'confirm': confirm}));
}
