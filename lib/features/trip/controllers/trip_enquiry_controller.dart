import 'dart:async';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../data/trip_enquiry_repository.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_offer_model.dart';
import '../trip_strings.dart';
import '../trip_strings_v2_find.dart';
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

  int? lastRetryAfterMinutes;

  int? lastAsksLeft;

  bool get lastWasAskLimit => lastErrorType == TripEnquiryErrorTypes.enquiryLimit;

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
    if (enquiryId != null &&
        (type == TripEnquiryErrorTypes.offerExpired ||
            type == TripEnquiryErrorTypes.offerNotPending ||
            type == TripEnquiryErrorTypes.enquiryClosed)) {
      unawaited(refreshOne(enquiryId));
    }
    if (type == TripEnquiryErrorTypes.dayInPast) {
      AppToast.warning(TripStringsV2Find.pastNight);
      return;
    }
    if (type == TripEnquiryErrorTypes.enquiryLimit) {
      AppToast.warning('${TripStrings.askLimitTitle}. ${TripStrings.askLimitBody(lastRetryAfterMinutes ?? 1)}');
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
    lastRetryAfterMinutes = null;
    try {
      return await run();
    } catch (e) {
      _readLimits(e);
      lastConflict = conflictOf(e);
      final network = DioErrorMapper.isNetworkError(e);
      lastErrorType = network ? null : DioErrorMapper.errorType(e);
      lastErrorMessage = network
          ? TripStrings.noNetwork
          : DioErrorMapper.toMessage(e, fallback, showRawMessageForStatusCodes: {400, 403, 409, 422, 429});
      _fail(e, enquiryId: id, fallback: fallback, silent: silent);
      return null;
    } finally {
      if (id != null) busyIds.remove(id);
    }
  }

  Future<String?> _tripId() async {
    final plan = TripPlanController.to;
    final ok = await plan.flushPendingSave();
    final id = plan.trip.value?.id;
    if (!ok || id == null) {
      plan.toastNotSaved();
      return null;
    }
    return id;
  }

  void _readLimits(Object e) {
    if (e is! DioException) return;
    final res = e.response;
    lastAsksLeft = TripEnquiryRepository.asksLeftOf(res) ?? lastAsksLeft;
    if (res?.statusCode != 429) return;
    final seconds = int.tryParse(res?.headers.value('retry-after') ?? '');
    lastRetryAfterMinutes = seconds == null || seconds <= 0 ? 1 : (seconds / 60).ceil();
  }

  void _readBatch(TripEnquiryBatch? batch) {
    if (batch != null) lastAsksLeft = batch.asksLeft ?? lastAsksLeft;
  }

  Future<TripEnquiryBatch?> sendEnquiry({
    required int day,
    required List<String> stayIds,
    required int nights,
    String? clientRequestId,
    String? stepKey,
  }) async {
    final tripId = await _tripId();
    if (tripId == null) return null;
    final batch = await _guard(
        null,
        () => _repo.create(tripId,
            day: day, stayIds: stayIds, nights: nights, clientRequestId: clientRequestId, stepKey: stepKey),
        silent: const {TripEnquiryErrorTypes.enquiryLimit});
    _readBatch(batch);
    if (batch != null) _applyToPlan(batch.items);
    return batch;
  }

  Future<TripEnquiryBatch?> sendLead({
    required List<int> days,
    required List<String> taxiIds,
    String? pickupTime,
    String? pickupPlace,
    String? clientRequestId,
    String? stepKey,
  }) async {
    final tripId = await _tripId();
    if (tripId == null) return null;
    final batch = await _guard(
      null,
      () => _repo.createLead(tripId,
          days: days,
          taxiIds: taxiIds,
          pickupTime: pickupTime,
          pickupPlace: pickupPlace,
          clientRequestId: clientRequestId,
          stepKey: stepKey),
      silent: const {TripEnquiryErrorTypes.enquiryLimit, TripEnquiryErrorTypes.leadLimit},
    );
    _readBatch(batch);
    if (batch != null) _applyToPlan(batch.items);
    return batch;
  }

  Map<String, dynamic> _taxiBody({
    required String taxiId,
    required List<int> days,
    int? agreedFare,
    required bool tollExtra,
    required String pickupTime,
    required String pickupPlace,
    required bool closeOthers,
    String? replaceEnquiryId,
    List<String>? replaceEnquiryIds,
  }) =>
      {
        'taxiId': taxiId,
        'days': days,
        'agreedFare': ?agreedFare,
        'tollExtra': tollExtra,
        'pickupTime': pickupTime,
        'pickupPlace': pickupPlace,
        'closeOthers': closeOthers,
        'replaceEnquiryId': ?replaceEnquiryId,
        'replaceEnquiryIds': ?replaceEnquiryIds,
      };

  Future<TripEnquiryModel?> bookTaxi({
    required String taxiId,
    required List<int> days,
    int? agreedFare,
    required bool tollExtra,
    required String pickupTime,
    required String pickupPlace,
    bool closeOthers = true,
    String? replaceEnquiryId,
    List<String>? replaceEnquiryIds,
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
      replaceEnquiryIds: replaceEnquiryIds,
    );
    final e = await _guard(null, () => _repo.taxiBooking(tripId, body));
    if (e == null) return null;
    _applyToPlan([e]);
    // The server also shrinks a replaced booking and closes other leads; only the target row comes back.
    final touchedOthers = closeOthers || replaceEnquiryId != null || (replaceEnquiryIds?.isNotEmpty ?? false);
    if (touchedOthers) unawaited(_plan?.refreshEnquiries());
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

  // Saves the plan first: the server rebuilds the driver's lead from the saved plan.
  Future<bool> updateLead(String enquiryId) async {
    final p = _plan;
    if (p != null && !await p.flushPendingSave()) return false;
    final e = await _guard(enquiryId, () => _repo.updateLead(enquiryId));
    if (e != null) _applyToPlan([e]);
    return e != null;
  }

  // Sends the stay host the day's current places; the server allows three real refreshes per row.
  Future<bool> refreshContext(String enquiryId) async {
    final p = _plan;
    if (p != null && !await p.flushPendingSave()) return false;
    final e = await _guard(enquiryId, () => _repo.refreshContext(enquiryId));
    if (e != null) _applyToPlan([e]);
    return e != null;
  }

  Future<void> refreshStayContexts(List<String> ids) async {
    for (final id in ids) {
      try {
        final e = await _repo.refreshContext(id);
        _applyToPlan([e]);
      } catch (_) {}
    }
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

  Future<bool> closeRow(TripEnquiryModel row) async {
    if (!row.isOpen) return true;
    const quiet = {TripEnquiryErrorTypes.enquiryClosed, TripEnquiryErrorTypes.concurrent};
    Future<bool> run(TripEnquiryModel e) async {
      final res = await _guard(e.id, () => e.isBooked ? _repo.cancel(e.id) : _repo.withdraw(e.id), silent: quiet);
      if (res != null) _applyToPlan([res]);
      return res != null;
    }

    if (await run(row)) return true;
    if (!quiet.contains(lastErrorType)) return false;
    final said = lastErrorMessage;
    final fresh = await refreshOne(row.id);
    if (fresh == null) {
      AppToast.error(TripStrings.noNetwork);
      return false;
    }
    if (!fresh.isOpen) return true;
    if (fresh.isBooked == row.isBooked) {
      AppToast.warning(said ?? TripStrings.justChanged);
      return false;
    }
    return fresh.isBooked ? cancel(fresh.id) : withdraw(fresh.id);
  }

  Future<TripEnquiryModel?> accept(String enquiryId, String offerId, {bool closeOthers = true, String? replaceEnquiryId}) async {
    final e = await _guard(
      enquiryId,
      () => _repo.acceptOffer(enquiryId, offerId, closeOthers: closeOthers, replaceEnquiryId: replaceEnquiryId),
    );
    if (e != null) {
      _applyToPlan([e]);
      if (closeOthers || replaceEnquiryId != null) unawaited(_plan?.refreshEnquiries());
    }
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
    final p = _plan;
    if (p != null && !await p.flushPendingSave()) {
      p.toastNotSaved();
      return null;
    }
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
