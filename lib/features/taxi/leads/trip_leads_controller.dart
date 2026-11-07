import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/auth_controller.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../trip/data/trip_enquiry_repository.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/trip_strings.dart';
import '../../trip/widgets/trip_cancel_sheet.dart';
import 'trip_lead_repository.dart';

class TripLeadBucket {
  static const String newOnes = 'new';
  static const String replied = 'replied';
  static const String booked = 'booked';
  static const String closed = 'closed';
  static const List<String> all = [newOnes, replied, booked, closed];

  static bool hasEnded(TripEnquiryModel e) {
    final out = e.checkOut;
    if (out == null) return false;
    final now = DateTime.now();
    return DateTime(out.year, out.month, out.day).isBefore(DateTime(now.year, now.month, now.day));
  }

  static String of(TripEnquiryModel e) {
    final isBooked = e.status == TripEnquiryStatuses.bookedByTraveller || e.status == TripEnquiryStatuses.confirmedByBoth;
    if (isBooked && hasEnded(e)) return closed;
    return switch (e.status) {
      TripEnquiryStatuses.asked || TripEnquiryStatuses.bookedByTraveller => newOnes,
      TripEnquiryStatuses.fareSent => replied,
      TripEnquiryStatuses.confirmedByBoth => TripLeadBucket.booked,
      _ => closed,
    };
  }
}

class TripLeadsController extends GetxController {
  static TripLeadsController ensure() {
    final userId = Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null;
    if (Get.isRegistered<TripLeadsController>()) {
      final c = Get.find<TripLeadsController>();
      if (c._userId != userId) c.reset();
      c._userId = userId;
      return c;
    }
    final c = TripLeadsController().._userId = userId;
    return Get.put(c, permanent: true);
  }

  static const int pageSize = 20;

  final _repo = const TripLeadRepository();
  final bucket = TripLeadBucket.newOnes.obs;
  final items = <TripEnquiryModel>[].obs;
  final newCount = 0.obs;
  final repliedCount = 0.obs;
  final bookedCount = 0.obs;
  final closedCount = 0.obs;
  final loading = false.obs;
  final loadingMore = false.obs;
  final loadMoreFailed = false.obs;
  final hasMore = false.obs;
  final failed = false.obs;
  final executionDisabled = false.obs;
  final busyIds = <String>{}.obs;
  final focusId = RxnString();

  String? _userId;
  int _page = 1;
  int _requestId = 0;
  bool _badgeLoaded = false;

  void reset() {
    _requestId++;
    items.clear();
    newCount.value = 0;
    repliedCount.value = 0;
    bookedCount.value = 0;
    closedCount.value = 0;
    bucket.value = TripLeadBucket.newOnes;
    hasMore.value = false;
    failed.value = false;
    executionDisabled.value = false;
    loading.value = false;
    loadingMore.value = false;
    loadMoreFailed.value = false;
    busyIds.clear();
    focusId.value = null;
    _page = 1;
    _badgeLoaded = false;
  }

  Future<void> loadBadge({bool force = false}) async {
    if (_badgeLoaded && !force) return;
    try {
      final page = await _repo.list(status: TripLeadBucket.newOnes, pageSize: 1);
      _badgeLoaded = true;
      _setCounts(page.counts);
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
      final page = await _repo.list(status: status, page: 1, pageSize: pageSize);
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
      final page = await _repo.list(status: status, page: 1, pageSize: pageSize);
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
      final page = await _repo.list(status: status, page: _page + 1, pageSize: pageSize);
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

  Future<void> focus(String enquiryId) async {
    final target = await bucketFor(enquiryId);
    if (target != null && target != bucket.value) {
      bucket.value = target;
      await load();
    } else {
      await refreshList();
    }
    focusId.value = enquiryId;
  }

  Future<String?> bucketFor(String enquiryId) async {
    try {
      return TripLeadBucket.of(await const TripEnquiryRepository().get(enquiryId));
    } catch (_) {
      return null;
    }
  }

  Future<void> refreshOne(String enquiryId) async {
    try {
      _upsert(await const TripEnquiryRepository().get(enquiryId));
    } catch (_) {}
  }

  Future<bool> fare(String id, int fare, String? note) async {
    final trimmed = note?.trim();
    final sent = trimmed == null || trimmed.isEmpty ? null : trimmed;
    return await _act(id, () => _repo.fare(id, fare: fare, note: sent)) != null;
  }

  Future<bool> notAvailable(String id) async => await _act(id, () => _repo.notAvailable(id)) != null;

  Future<bool> confirm(String id) async => await _act(id, () => _repo.confirm(id)) != null;

  Future<bool> deny(String id) async => await _act(id, () => _repo.deny(id)) != null;

  Future<bool> cancel(BuildContext context, TripEnquiryModel e) async {
    final cancelled = await TripCancelSheet.show(context, enquiry: e, ownerSide: true);
    if (cancelled) {
      await refreshOne(e.id);
      await loadBadge(force: true);
    }
    return cancelled;
  }

  Future<TripEnquiryModel?> _act(String id, Future<TripEnquiryModel> Function() call) async {
    if (busyIds.contains(id)) return null;
    busyIds.add(id);
    try {
      final result = await call();
      _upsert(result);
      loadBadge(force: true);
      return result;
    } catch (e) {
      _toastError(e);
      final type = DioErrorMapper.errorType(e);
      if (type == TripEnquiryErrorTypes.concurrent || type == TripEnquiryErrorTypes.enquiryClosed) refreshOne(id);
      return null;
    } finally {
      busyIds.remove(id);
    }
  }

  void _toastError(Object e) {
    final type = DioErrorMapper.errorType(e);
    if (type == TripEnquiryErrorTypes.concurrent) {
      AppToast.warning(TripStrings.justChanged);
    } else if (type == TripEnquiryErrorTypes.fareEditLimit) {
      AppToast.warning(TripStrings.fareLimit);
    } else if (DioErrorMapper.isNetworkError(e)) {
      AppToast.error(TripStrings.noNetwork);
    } else {
      AppToast.error(DioErrorMapper.toMessage(e, TripStrings.couldNotLoad, showRawMessageForStatusCodes: {400, 403, 409, 422, 429}));
    }
  }

  void _upsert(TripEnquiryModel updated) {
    final i = items.indexWhere((e) => e.id == updated.id);
    if (i < 0) return;
    if (TripLeadBucket.of(updated) == bucket.value) {
      items[i] = updated;
    } else {
      items.removeAt(i);
    }
  }

  void _setCounts(TripDriverCounts c) {
    newCount.value = c.newOnes;
    repliedCount.value = c.replied;
    bookedCount.value = c.booked;
    closedCount.value = c.closed;
  }
}
