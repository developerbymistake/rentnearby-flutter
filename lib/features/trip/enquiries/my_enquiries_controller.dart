import 'package:get/get.dart';
import '../data/trip_enquiry_repository.dart';
import '../models/trip_enquiry_model.dart';
import 'my_enquiry_count_controller.dart';

class MyEnquiryBucket {
  static const String waiting = 'waiting';
  static const String offers = 'offers';
  static const String booked = 'booked';
  static const String past = 'past';
  static const List<String> all = [waiting, offers, booked, past];

  static DateTime _todayIst([DateTime? now]) {
    final t = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateTime(t.year, t.month, t.day);
  }

  static String of(TripEnquiryModel e, {DateTime? now}) => switch (e.status) {
        TripEnquiryStatuses.asked || TripEnquiryStatuses.countered => waiting,
        TripEnquiryStatuses.offered => offers,
        TripEnquiryStatuses.confirmedByBoth when e.checkOut == null || !e.checkOut!.isBefore(_todayIst(now)) => booked,
        _ => past,
      };

  static String? parse(Object? raw) {
    final v = raw?.toString().toLowerCase();
    return all.contains(v) ? v : null;
  }
}

class MyEnquiriesController extends GetxController {
  MyEnquiriesController({TripEnquiryRepository? repo}) : _repo = repo ?? const TripEnquiryRepository();

  static MyEnquiriesController ensure() =>
      Get.isRegistered<MyEnquiriesController>() ? Get.find<MyEnquiriesController>() : Get.put(MyEnquiriesController());

  static MyEnquiriesController? get maybe =>
      Get.isRegistered<MyEnquiriesController>() ? Get.find<MyEnquiriesController>() : null;

  final TripEnquiryRepository _repo;
  final bucket = MyEnquiryBucket.waiting.obs;
  final focusId = RxnString();
  final items = <TripEnquiryModel>[].obs;
  final counts = const MyEnquiryCounts().obs;
  final loading = false.obs;
  final loadingMore = false.obs;
  final hasMore = false.obs;
  final failed = false.obs;

  String? _cursor;
  int _requestId = 0;

  int countOf(String b) => switch (b) {
        MyEnquiryBucket.offers => counts.value.offers,
        MyEnquiryBucket.booked => counts.value.booked,
        MyEnquiryBucket.past => counts.value.past,
        _ => counts.value.waiting,
      };

  void _apply(MyEnquiryPage page) {
    items.assignAll(page.items);
    hasMore.value = page.hasMore;
    _cursor = page.nextCursor;
    final c = page.counts;
    if (c != null) {
      counts.value = c;
      MyEnquiryCountController.maybe?.apply(waiting: c.waiting, offers: c.offers, booked: c.booked);
    }
  }

  Future<void> selectBucket(String value) async {
    if (bucket.value == value && !failed.value && items.isNotEmpty) return;
    bucket.value = value;
    await load();
  }

  Future<void> load() async {
    final id = ++_requestId;
    loading.value = true;
    failed.value = false;
    items.clear();
    hasMore.value = false;
    _cursor = null;
    try {
      final page = await _repo.mine(bucket: bucket.value);
      if (id != _requestId || isClosed) return;
      _apply(page);
    } catch (_) {
      if (id == _requestId) failed.value = true;
    } finally {
      if (id == _requestId) loading.value = false;
    }
  }

  Future<void> refreshList() async {
    final id = ++_requestId;
    try {
      final page = await _repo.mine(bucket: bucket.value);
      if (id != _requestId || isClosed) return;
      _apply(page);
      failed.value = false;
    } catch (_) {
      if (id == _requestId && items.isEmpty) failed.value = true;
    }
  }

  Future<void> loadMore() async {
    final cursor = _cursor;
    if (loading.value || loadingMore.value || !hasMore.value || cursor == null) return;
    final id = _requestId;
    loadingMore.value = true;
    try {
      final page = await _repo.mine(bucket: bucket.value, cursor: cursor, counts: false);
      if (id != _requestId || isClosed) return;
      final known = items.map((e) => e.id).toSet();
      items.addAll(page.items.where((e) => !known.contains(e.id)));
      hasMore.value = page.hasMore;
      _cursor = page.nextCursor;
    } catch (_) {
    } finally {
      if (id == _requestId) loadingMore.value = false;
    }
  }

  Future<String?> bucketFor(String enquiryId) async {
    for (final e in items) {
      if (e.id == enquiryId) return MyEnquiryBucket.of(e);
    }
    try {
      return MyEnquiryBucket.of(await _repo.get(enquiryId));
    } catch (_) {
      return null;
    }
  }

  void onRowChanged(TripEnquiryModel row) {
    if (row.isTaxi) return;
    final i = items.indexWhere((e) => e.id == row.id);
    if (i >= 0) {
      if (MyEnquiryBucket.of(row) == bucket.value) {
        items[i] = row;
      } else {
        items.removeAt(i);
      }
    } else if (MyEnquiryBucket.of(row) == bucket.value) {
      items.insert(0, row);
    }
    refreshList();
  }
}
