import 'dart:math' as math;

import 'package:get/get.dart';
import '../../../utils/dio_error_mapper.dart';
import 'models/taxi_ways_models.dart';
import 'taxi_ways_repository.dart';

enum ChangeDriverSort { bestFit, lowestPrice }

class ChangeDriverController extends GetxController {
  ChangeDriverController({required this.leg, required this.people, TaxiWaysRepository? repository})
      : _repo = repository ?? const TaxiWaysRepository();

  static const int pageSize = 4;

  final WayLeg leg;
  final int people;
  final TaxiWaysRepository _repo;

  final items = <WayDriver>[].obs;
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final loadFailed = false.obs;
  final isOffline = false.obs;
  final moreFailed = false.obs;
  final hasMore = false.obs;
  final total = 0.obs;

  final seats6 = false.obs;
  final suv = false.obs;
  final repliesOnly = false.obs;
  final sort = ChangeDriverSort.bestFit.obs;

  int _page = 1;
  int _gen = 0;

  @override
  void onInit() {
    super.onInit();
    loadFirst();
  }

  void toggleSeats6() {
    seats6.toggle();
    loadFirst();
  }

  void toggleSuv() {
    suv.toggle();
    loadFirst();
  }

  void toggleReplies() {
    repliesOnly.toggle();
    loadFirst();
  }

  void toggleLowestPrice() {
    sort.value = sort.value == ChangeDriverSort.lowestPrice ? ChangeDriverSort.bestFit : ChangeDriverSort.lowestPrice;
    loadFirst();
  }

  int get remaining => math.min(pageSize, math.max(0, total.value - items.length));

  bool isLowest(WayDriver d) {
    if (items.length < 2) return false;
    if (sort.value == ChangeDriverSort.lowestPrice) return items.first.taxiId == d.taxiId;
    if (items.length < total.value) return false;
    int? best;
    String? bestId;
    for (final x in items) {
      final f = x.listedFare;
      if (f <= 0) continue;
      if (best == null || f < best) {
        best = f;
        bestId = x.taxiId;
      }
    }
    return bestId == d.taxiId;
  }

  Future<void> loadFirst() async {
    final gen = ++_gen;
    _page = 1;
    isLoading.value = true;
    isLoadingMore.value = false;
    loadFailed.value = false;
    isOffline.value = false;
    moreFailed.value = false;
    items.clear();
    try {
      final page = await _fetch(1);
      if (gen != _gen) return;
      items.assignAll(page.items);
      hasMore.value = page.hasMore;
      total.value = page.total;
    } catch (e) {
      if (gen != _gen) return;
      loadFailed.value = true;
      isOffline.value = DioErrorMapper.isNetworkError(e);
      hasMore.value = false;
    } finally {
      if (gen == _gen) isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoading.value || isLoadingMore.value || !hasMore.value) return;
    final gen = _gen;
    isLoadingMore.value = true;
    moreFailed.value = false;
    try {
      final page = await _fetch(_page + 1);
      if (gen != _gen) return;
      _page++;
      final known = items.map((d) => d.taxiId).toSet();
      items.addAll(page.items.where((d) => !known.contains(d.taxiId)));
      hasMore.value = page.hasMore;
      total.value = page.total;
    } catch (_) {
      if (gen == _gen) moreFailed.value = true;
    } finally {
      if (gen == _gen) isLoadingMore.value = false;
    }
  }

  Future<void> retry() => loadFirst();

  Future<WayDriverPage> _fetch(int page) => _repo.legDrivers(
        leg.legKey,
        people: people,
        minSeats: seats6.value ? 6 : null,
        category: suv.value ? 'SUV' : null,
        repliesInApp: repliesOnly.value,
        sort: sort.value == ChangeDriverSort.lowestPrice ? 'lowestPrice' : 'bestFit',
        page: page,
        pageSize: pageSize,
      );
}
