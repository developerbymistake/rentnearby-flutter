import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../data/trip_enquiry_repository.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_offer_model.dart';
import '../trip_strings.dart';
import 'trip_plan_controller.dart';

class TripEnquiryController extends GetxController {
  static TripEnquiryController get to =>
      Get.isRegistered<TripEnquiryController>()
          ? Get.find<TripEnquiryController>()
          : Get.put(TripEnquiryController(), permanent: true);

  final _repo = const TripEnquiryRepository();

  final busyIds = <String>{}.obs;

  TripNightConflict? lastConflict;

  String? lastErrorType;

  String? lastErrorMessage;

  String? errorTypeOf(Object e) => DioErrorMapper.errorType(e);

  TripNightConflict? conflictOf(Object e) {
    if (e is! DioException) return null;
    final type = DioErrorMapper.errorType(e);
    if (type != TripEnquiryErrorTypes.nightAlreadyConfirmed && type != TripEnquiryErrorTypes.dayAlreadyBooked) return null;
    final body = e.response?.data;
    final data = body is Map<String, dynamic> ? body['data'] : null;
    if (data is! Map<String, dynamic>) return null;
    final id = data['enquiryId'] as String?;
    if (id == null) return null;
    return TripNightConflict(enquiryId: id, listingName: data['listingName'] as String? ?? '');
  }

  TripPlanController? get _plan => Get.isRegistered<TripPlanController>() ? Get.find<TripPlanController>() : null;

  void _applyToPlan(Iterable<TripEnquiryModel> items) {
    final plan = _plan;
    final tripId = plan?.trip.value?.id;
    if (plan == null || tripId == null) return;
    final mine = items.where((e) => e.tripId == tripId).toList();
    if (mine.isNotEmpty) plan.applyEnquiries(mine);
  }

  void _fail(Object e, {String? enquiryId, String fallback = TripStrings.couldNotLoad, Set<String> silent = const {}}) {
    if (conflictOf(e) != null) return;
    final type = DioErrorMapper.errorType(e);
    if (type != null && silent.contains(type)) return;
    if (type == TripEnquiryErrorTypes.concurrent) {
      AppToast.warning(TripStrings.justChanged);
      if (enquiryId != null) refreshOne(enquiryId);
      return;
    }
    if (DioErrorMapper.isNetworkError(e)) {
      AppToast.error(TripStrings.noNetwork);
      return;
    }
    if (type == TripEnquiryErrorTypes.executionDisabled) {
      AppToast.warning(DioErrorMapper.serverMessage(e) ?? fallback);
      return;
    }
    AppToast.error(DioErrorMapper.toMessage(e, fallback, showRawMessageForStatusCodes: {400, 403, 409, 422, 429}));
  }

  Future<T?> _guard<T>(String? id, Future<T> Function() run,
      {String fallback = TripStrings.couldNotLoad, Set<String> silent = const {}}) async {
    if (id != null) busyIds.add(id);
    lastConflict = null;
    lastErrorType = null;
    lastErrorMessage = null;
    try {
      return await run();
    } catch (e) {
      lastConflict = conflictOf(e);
      final network = DioErrorMapper.isNetworkError(e);
      lastErrorType = network ? null : DioErrorMapper.errorType(e);
      lastErrorMessage = network ? TripStrings.noNetwork : DioErrorMapper.serverMessage(e);
      _fail(e, enquiryId: id, fallback: fallback, silent: silent);
      return null;
    } finally {
      if (id != null) busyIds.remove(id);
    }
  }

  Future<String?> _tripId() async {
    final plan = TripPlanController.to;
    if (plan.trip.value == null) await plan.saveNow();
    final id = plan.trip.value?.id;
    if (id == null) AppToast.warning(TripStrings.notSavedYet);
    return id;
  }

  Future<TripEnquiryBatch?> sendEnquiry({required int day, required List<String> stayIds, required bool allNights}) async {
    final tripId = await _tripId();
    if (tripId == null) return null;
    final batch = await _guard(null, () => _repo.create(tripId, day: day, stayIds: stayIds, allNights: allNights));
    if (batch != null) _applyToPlan(batch.items);
    return batch;
  }

  Future<TripEnquiryBatch?> sendLead({
    required List<int> days,
    required List<String> taxiIds,
    String? pickupTime,
    String? pickupPlace,
  }) async {
    final tripId = await _tripId();
    if (tripId == null) return null;
    final batch = await _guard(
      null,
      () => _repo.createLead(tripId, days: days, taxiIds: taxiIds, pickupTime: pickupTime, pickupPlace: pickupPlace),
    );
    if (batch != null) _applyToPlan(batch.items);
    return batch;
  }

  Map<String, dynamic> _taxiBody({
    required String taxiId,
    required List<int> days,
    required int agreedFare,
    required bool tollExtra,
    required String pickupTime,
    required String pickupPlace,
    required bool closeOthers,
    String? replaceEnquiryId,
  }) =>
      {
        'taxiId': taxiId,
        'days': days,
        'agreedFare': agreedFare,
        'tollExtra': tollExtra,
        'pickupTime': pickupTime,
        'pickupPlace': pickupPlace,
        'closeOthers': closeOthers,
        'replaceEnquiryId': ?replaceEnquiryId,
      };

  Future<TripEnquiryModel?> bookTaxi({
    required String taxiId,
    required List<int> days,
    required int agreedFare,
    required bool tollExtra,
    required String pickupTime,
    required String pickupPlace,
    bool closeOthers = true,
    String? replaceEnquiryId,
  }) async {
    final tripId = await _tripId();
    if (tripId == null) return null;
    final body = _taxiBody(
      taxiId: taxiId,
      days: days,
      agreedFare: agreedFare,
      tollExtra: tollExtra,
      pickupTime: pickupTime,
      pickupPlace: pickupPlace,
      closeOthers: closeOthers,
      replaceEnquiryId: replaceEnquiryId,
    );
    final e = await _guard(null, () => _repo.taxiBooking(tripId, body));
    if (e != null) _applyToPlan([e]);
    return e;
  }

  Future<TripEnquiryModel?> syncTaxiBooking(
    String tripId, {
    required String taxiId,
    required List<int> days,
    required int agreedFare,
    required bool tollExtra,
    required String pickupTime,
    required String pickupPlace,
  }) async {
    try {
      final e = await _repo.taxiBooking(
        tripId,
        _taxiBody(
          taxiId: taxiId,
          days: days,
          agreedFare: agreedFare,
          tollExtra: tollExtra,
          pickupTime: pickupTime,
          pickupPlace: pickupPlace,
          closeOthers: false,
        ),
      );
      _applyToPlan([e]);
      return e;
    } catch (_) {
      return null;
    }
  }

  Future<TripEnquiryModel?> askAdvance(
    String enquiryId, {
    required int amount,
    required DateTime holdUntil,
    required String upiId,
    required String whatsAppNumber,
  }) =>
      _guard(
        enquiryId,
        () => _repo.askAdvance(enquiryId, amount: amount, holdUntil: holdUntil, upiId: upiId, whatsAppNumber: whatsAppNumber),
      );

  Future<bool> proofSent(String enquiryId) async {
    final e = await _guard(enquiryId, () => _repo.proofSent(enquiryId));
    if (e != null) {
      _applyToPlan([e]);
      AppToast.success(TripStrings.proofSentToast);
      return true;
    }
    if (lastErrorType == TripEnquiryErrorTypes.holdExpired) await refreshOne(enquiryId);
    return false;
  }

  Future<bool> markReceived(String enquiryId) async {
    final e = await _guard(
      enquiryId,
      () => _repo.advanceReceived(enquiryId),
      silent: const {TripEnquiryErrorTypes.travellerMovedOn},
    );
    if (e != null) _applyToPlan([e]);
    return e != null;
  }

  Future<bool> notYet(String enquiryId) async {
    final e = await _guard(enquiryId, () => _repo.advanceNotYet(enquiryId));
    if (e != null) _applyToPlan([e]);
    return e != null;
  }

  Future<TripPhoneBookingResult?> savePhoneBooking({
    required String stayId,
    required int day,
    required bool allNights,
    required Map<String, dynamic> fields,
    String? replaceEnquiryId,
    bool closeOthers = true,
  }) async {
    final tripId = await _tripId();
    if (tripId == null) return null;
    final res = await _guard(
      null,
      () => _repo.createPhoneBooking(tripId, {
        'stayId': stayId,
        'day': day,
        'allNights': allNights,
        ...fields,
        'closeOthers': closeOthers,
        'replaceEnquiryId': ?replaceEnquiryId,
      }),
    );
    if (res != null) _applyToPlan([res.enquiry]);
    return res;
  }

  Future<TripPhoneBookingResult?> editPhoneBooking(String enquiryId, Map<String, dynamic> fields) async {
    final res = await _guard(enquiryId, () => _repo.editPhoneBooking(enquiryId, fields));
    if (res != null) _applyToPlan([res.enquiry]);
    return res;
  }

  Future<TripPhoneBookingResult?> resendLink(String enquiryId) async {
    final res = await _guard(enquiryId, () => _repo.resendHostLink(enquiryId));
    if (res != null) _applyToPlan([res.enquiry]);
    return res;
  }

  Future<bool> withdraw(String enquiryId) async {
    final e = await _guard(enquiryId, () => _repo.withdraw(enquiryId));
    if (e != null) _applyToPlan([e]);
    return e != null;
  }

  Future<bool> cancel(String enquiryId, {String? reason}) async {
    final trimmed = reason?.trim();
    final e = await _guard(enquiryId, () => _repo.cancel(enquiryId, reason: trimmed == null || trimmed.isEmpty ? null : trimmed));
    if (e != null) _applyToPlan([e]);
    return e != null;
  }

  Future<TripEnquiryModel?> accept(String enquiryId, String offerId, {bool closeOthers = true, String? replaceEnquiryId}) async {
    final e = await _guard(
      enquiryId,
      () => _repo.acceptOffer(enquiryId, offerId, closeOthers: closeOthers, replaceEnquiryId: replaceEnquiryId),
    );
    if (e != null) _applyToPlan([e]);
    return e;
  }

  Future<bool> decline(String enquiryId, String offerId) async {
    final e = await _guard(enquiryId, () => _repo.declineOffer(enquiryId, offerId));
    if (e != null) _applyToPlan([e]);
    return e != null;
  }

  void _mapped(Map<String, String> copy) {
    final type = lastErrorType;
    final text = type == null ? null : copy[type];
    if (text == null) return;
    lastErrorMessage = text;
    AppToast.warning(text);
  }

  Future<TripOfferModel?> counter(String enquiryId, {required int pricePerNight, String? note}) async {
    final trimmed = note?.trim();
    const copy = {TripEnquiryErrorTypes.counterLimit: TripStrings.counterLimit};
    final res = await _guard(
      enquiryId,
      () => _repo.counter(enquiryId, pricePerNight: pricePerNight, note: trimmed == null || trimmed.isEmpty ? null : trimmed),
      silent: copy.keys.toSet(),
    );
    if (res == null) {
      _mapped(copy);
      return null;
    }
    _applyToPlan([res.enquiry]);
    return res.offer;
  }

  Future<TripOfferModel?> changeRequest(
    String enquiryId, {
    required DateTime checkIn,
    required DateTime checkOut,
    required int adults,
    required int kids,
    required int rooms,
    String? note,
  }) async {
    final trimmed = note?.trim();
    const copy = {
      TripEnquiryErrorTypes.nothingChanged: TripStrings.nothingChanged,
      TripEnquiryErrorTypes.changeNotAllowed: TripStrings.changeWaiting,
    };
    final res = await _guard(
      enquiryId,
      () => _repo.changeRequest(enquiryId, {
        'checkIn': _isoDate(checkIn),
        'checkOut': _isoDate(checkOut),
        'adults': adults,
        'kids': kids,
        'rooms': rooms,
        'note': trimmed == null || trimmed.isEmpty ? null : trimmed,
      }),
      silent: copy.keys.toSet(),
    );
    if (res == null) {
      _mapped(copy);
      return null;
    }
    _applyToPlan([res.enquiry]);
    return res.offer;
  }

  Future<TripEnquiryModel?> acceptRevised(String enquiryId, String offerId) =>
      accept(enquiryId, offerId, closeOthers: false);

  Future<bool> keepPrice(String enquiryId, String offerId) => decline(enquiryId, offerId);

  Future<TripEnquiryBatch?> askAgain({required String kind, required int day}) async {
    final tripId = await _tripId();
    if (tripId == null) return null;
    const copy = {TripEnquiryErrorTypes.askAgainNothing: TripStrings.askAgainNothing};
    final batch = await _guard(null, () => _repo.askAgain(tripId, kind: kind, day: day), silent: copy.keys.toSet());
    if (batch == null) {
      _mapped(copy);
      return null;
    }
    _applyToPlan(batch.items);
    return batch;
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<TripEnquiryModel?> refreshOne(String enquiryId) async {
    try {
      final e = await _repo.get(enquiryId);
      _applyToPlan([e]);
      return e;
    } catch (_) {
      return null;
    }
  }

  Future<TripEnquiryModel?> forConversation(String conversationId) async {
    try {
      final e = await _repo.byConversation(conversationId);
      if (e != null) _applyToPlan([e]);
      return e;
    } catch (_) {
      return null;
    }
  }
}
