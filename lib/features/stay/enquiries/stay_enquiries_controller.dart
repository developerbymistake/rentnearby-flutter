import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../trip/data/trip_enquiry_repository.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/models/trip_offer_model.dart';
import '../../trip/trip_strings.dart';
import '../models/stay_owner_model.dart';
import '../setup/stay_repository.dart';

class StayEnquiryBucket {
  static const String newOnes = 'new';
  static const String offered = 'offered';
  static const String confirmed = 'confirmed';
  static const String closed = 'closed';
  static const List<String> all = [newOnes, offered, confirmed, closed];

  static bool hasEnded(TripEnquiryModel e) {
    final out = e.checkOut;
    if (out == null) return false;
    final now = DateTime.now();
    return DateTime(out.year, out.month, out.day).isBefore(DateTime(now.year, now.month, now.day));
  }

  static String of(TripEnquiryModel e) {
    final bucket = switch (e.status) {
      TripEnquiryStatuses.asked || TripEnquiryStatuses.countered => newOnes,
      TripEnquiryStatuses.offered => offered,
      TripEnquiryStatuses.confirmedByTraveller || TripEnquiryStatuses.confirmedByBoth => confirmed,
      _ => closed,
    };
    if (bucket == confirmed && hasEnded(e)) return closed;
    return bucket;
  }
}

class StayEnquiriesController extends GetxController {
  static StayEnquiriesController ensure() =>
      Get.isRegistered<StayEnquiriesController>() ? Get.find<StayEnquiriesController>() : Get.put(StayEnquiriesController());

  static const int pageSize = 20;
  static const String _offerLimit = 'OfferLimit';

  final _repo = const TripEnquiryRepository();
  final bucket = StayEnquiryBucket.newOnes.obs;
  final focusId = RxnString();
  final items = <TripEnquiryModel>[].obs;
  final counts = const TripOwnerCounts().obs;
  final newCount = 0.obs;
  final loading = false.obs;
  final loadingMore = false.obs;
  final loadMoreFailed = false.obs;
  final hasMore = false.obs;
  final failed = false.obs;
  final executionDisabled = false.obs;
  final busyIds = <String>{}.obs;
  final stay = Rxn<StayOwnerModel>();

  int _page = 1;
  int _requestId = 0;
  String? lastErrorType;
  String? lastErrorMessage;

  void reset() {
    _requestId++;
    items.clear();
    counts.value = const TripOwnerCounts();
    newCount.value = 0;
    bucket.value = StayEnquiryBucket.newOnes;
    hasMore.value = false;
    failed.value = false;
    executionDisabled.value = false;
    loading.value = false;
    loadingMore.value = false;
    busyIds.clear();
    stay.value = null;
    _page = 1;
  }

  Future<void> loadBadge() async {
    try {
      final page = await _repo.ownerList(status: StayEnquiryBucket.newOnes, pageSize: 1);
      counts.value = page.counts;
      newCount.value = page.counts.newCount;
    } catch (_) {}
  }

  Future<void> selectBucket(String value) async {
    if (bucket.value == value && !failed.value) return;
    bucket.value = value;
    await load();
  }

  Future<void> load() async {
    final id = ++_requestId;
    final status = bucket.value;
    _page = 1;
    loading.value = true;
    failed.value = false;
    executionDisabled.value = false;
    loadMoreFailed.value = false;
    items.clear();
    hasMore.value = false;
    try {
      final page = await _repo.ownerList(status: status, page: 1, pageSize: pageSize);
      if (id != _requestId) return;
      items.assignAll(page.items);
      hasMore.value = page.hasMore;
      _setCounts(page.counts);
    } catch (e) {
      if (id != _requestId) return;
      failed.value = true;
      executionDisabled.value = DioErrorMapper.errorType(e) == TripEnquiryErrorTypes.executionDisabled;
    } finally {
      if (id == _requestId) loading.value = false;
    }
  }

  Future<void> refreshList() async {
    final id = ++_requestId;
    final status = bucket.value;
    try {
      final page = await _repo.ownerList(status: status, page: 1, pageSize: pageSize);
      if (id != _requestId) return;
      _page = 1;
      items.assignAll(page.items);
      hasMore.value = page.hasMore;
      failed.value = false;
      executionDisabled.value = false;
      loadMoreFailed.value = false;
      _setCounts(page.counts);
    } catch (e) {
      if (id != _requestId) return;
      if (items.isEmpty) {
        failed.value = true;
        executionDisabled.value = DioErrorMapper.errorType(e) == TripEnquiryErrorTypes.executionDisabled;
      }
    }
  }

  Future<void> loadMore() async {
    if (loading.value || loadingMore.value || !hasMore.value) return;
    final id = _requestId;
    final status = bucket.value;
    loadingMore.value = true;
    loadMoreFailed.value = false;
    try {
      final page = await _repo.ownerList(status: status, page: _page + 1, pageSize: pageSize);
      if (id != _requestId) return;
      _page++;
      final known = items.map((e) => e.id).toSet();
      items.addAll(page.items.where((e) => !known.contains(e.id)));
      hasMore.value = page.hasMore;
      _setCounts(page.counts);
    } catch (_) {
      if (id == _requestId) loadMoreFailed.value = true;
    } finally {
      if (id == _requestId) loadingMore.value = false;
    }
  }

  Future<String?> bucketFor(String enquiryId) async {
    try {
      return StayEnquiryBucket.of(await _repo.get(enquiryId));
    } catch (_) {
      return null;
    }
  }

  Future<void> refreshOne(String enquiryId) async {
    try {
      _upsert(await _repo.get(enquiryId));
    } catch (_) {}
  }

  Future<StayOwnerModel?> ensureStay() async {
    try {
      stay.value = await const StayRepository().getMine();
    } catch (_) {}
    return stay.value;
  }

  Future<bool> sendOffer(TripEnquiryModel e, Map<String, dynamic> body) async {
    final result = await _act<({TripEnquiryModel enquiry, TripOfferModel offer})>(
      e.id,
      () => _repo.sendOffer(e.id, body),
      TripStrings.couldNotLoad,
      (r) => r.enquiry,
      inline: true,
    );
    if (result != null) AppToast.success(TripStrings.offerSent);
    return result != null;
  }

  Future<bool> revisedOffer(TripEnquiryModel e, Map<String, dynamic> body) async {
    final result = await _act<({TripEnquiryModel enquiry, TripOfferModel offer})>(
      e.id,
      () => _repo.revisedOffer(e.id, body),
      TripStrings.couldNotLoad,
      (r) => r.enquiry,
      limitMessage: TripStrings.revisedLimit,
      inline: true,
    );
    if (result != null) AppToast.success(TripStrings.revisedSent);
    return result != null;
  }

  Future<bool> acceptChange(String id, String offerId) async {
    final result = await _act<TripEnquiryModel>(id, () => _repo.acceptChange(id, offerId), TripStrings.couldNotLoad, (r) => r);
    if (result != null) AppToast.success(TripStrings.changeAccepted);
    return result != null;
  }

  Future<bool> notAvailable(String enquiryId) async =>
      await _act<TripEnquiryModel>(enquiryId, () => _repo.notAvailable(enquiryId), TripStrings.couldNotLoad, (r) => r) != null;

  Future<bool> askAdvance(
    String id, {
    required int amount,
    required DateTime holdUntil,
    required String upiId,
    required String whatsAppNumber,
  }) async =>
      await _act<TripEnquiryModel>(
        id,
        () => _repo.askAdvance(id, amount: amount, holdUntil: holdUntil, upiId: upiId, whatsAppNumber: whatsAppNumber),
        TripStrings.couldNotLoad,
        (r) => r,
        inline: true,
      ) !=
      null;

  Future<bool> markReceived(String id) async =>
      await _act<TripEnquiryModel>(id, () => _repo.advanceReceived(id), TripStrings.couldNotLoad, (r) => r) != null;

  Future<bool> notYet(String id) async {
    final ok = await _act<TripEnquiryModel>(id, () => _repo.advanceNotYet(id), TripStrings.couldNotLoad, (r) => r) != null;
    if (ok) AppToast.info(TripStrings.notYetNoted);
    return ok;
  }

  Future<void> afterExternalChange(String enquiryId) async {
    await refreshOne(enquiryId);
    await loadBadge();
  }

  Future<T?> _act<T>(
    String id,
    Future<T> Function() call,
    String fallback,
    TripEnquiryModel Function(T) pick, {
    bool inline = false,
    String? limitMessage,
  }) async {
    if (busyIds.contains(id)) return null;
    lastErrorType = null;
    lastErrorMessage = null;
    busyIds.add(id);
    try {
      final result = await call();
      _upsert(pick(result));
      loadBadge();
      return result;
    } catch (e) {
      lastErrorType = DioErrorMapper.errorType(e);
      lastErrorMessage = DioErrorMapper.serverMessage(e);
      final status = e is DioException ? e.response?.statusCode : null;
      final showInline = inline && lastErrorMessage != null && (status == 400 || status == 409 || status == 422);
      if (lastErrorType == TripEnquiryErrorTypes.travellerMovedOn) {
        AppToast.warning(TripStrings.guestMovedOn);
      } else if (limitMessage != null && lastErrorType == _offerLimit) {
        AppToast.warning(limitMessage);
      } else if (!showInline) {
        _toastError(e, fallback);
      }
      if (lastErrorType == TripEnquiryErrorTypes.concurrent || lastErrorType == TripEnquiryErrorTypes.enquiryClosed) refreshOne(id);
      return null;
    } finally {
      busyIds.remove(id);
    }
  }

  void _toastError(Object e, String fallback) {
    final type = DioErrorMapper.errorType(e);
    if (type == TripEnquiryErrorTypes.concurrent) {
      AppToast.warning(TripStrings.justChanged);
    } else if (DioErrorMapper.isNetworkError(e)) {
      AppToast.error(TripStrings.noNetwork);
    } else {
      AppToast.error(DioErrorMapper.toMessage(e, fallback, showRawMessageForStatusCodes: {400, 403, 409, 422, 429}));
    }
  }

  void _upsert(TripEnquiryModel updated) {
    final i = items.indexWhere((e) => e.id == updated.id);
    if (i < 0) return;
    if (StayEnquiryBucket.of(updated) == bucket.value) {
      items[i] = updated;
    } else {
      items.removeAt(i);
    }
  }

  void _setCounts(TripOwnerCounts c) {
    counts.value = c;
    newCount.value = c.newCount;
  }
}
