import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../services/api_service.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../utils/network_retry.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../../taxi/guest/taxi_browse_repository.dart';
import '../../taxi/models/taxi_browse_item.dart';
import '../trip_constants.dart';
import 'trip_plan_controller.dart';

class TripSupplyController extends GetxController {
  static TripSupplyController get to =>
      Get.isRegistered<TripSupplyController>()
          ? Get.find<TripSupplyController>()
          : Get.put(TripSupplyController(), permanent: true);

  static const _taxiPageSize = 20;

  final day = 1.obs;

  final taxis = <TaxiBrowseItem>[].obs;
  final taxiLoading = false.obs;
  final taxiLoadingMore = false.obs;
  final taxiFailed = false.obs;
  final taxiHasMore = false.obs;
  int _taxiPage = 1;
  int _taxiSeq = 0;
  bool _taxisLoaded = false;

  final stays = <StayNearbyModel>[].obs;
  final stayLoading = false.obs;
  final stayFailed = false.obs;
  final stayRadiusKm = TripConstants.stayRadiusKm.obs;
  int _staySeq = 0;
  int? _staysDay;
  ({double lat, double lng})? _staysPoint;

  TripPlanController get _plan => TripPlanController.to;

  bool get canWidenRadius => stayRadiusKm.value < TripConstants.stayRadiusWideKm;

  bool _isTabInactive(Object e) => DioErrorMapper.errorType(e) == ApiService.tabInactiveType;

  bool _isUnauthorized(Object e) => e is DioException && e.response?.statusCode == 401;

  void setDay(int d) {
    if (d == day.value) return;
    day.value = d;
    if (_taxisLoaded) loadTaxis(reset: true);
    if (_staysDay != null) {
      stayRadiusKm.value = TripConstants.stayRadiusKm;
      loadStays();
    }
  }

  Future<void> ensureTaxis() async {
    if (!_taxisLoaded && !taxiLoading.value) await loadTaxis();
  }

  Future<void> ensureStays() async {
    if (_staysDay != day.value) {
      if (!stayLoading.value) await loadStays();
      return;
    }
    if (_middlePoint(day.value) != _staysPoint) {
      stayRadiusKm.value = TripConstants.stayRadiusKm;
      await loadStays();
    }
  }

  Future<void> loadTaxis({bool reset = true}) async {
    final p = _plan.plan.value;
    final districtId = p?.districtId;
    if (p == null || districtId == null) return;
    if (!reset && (!taxiHasMore.value || taxiLoadingMore.value || taxiLoading.value)) return;
    final seq = ++_taxiSeq;
    final page = reset ? 1 : _taxiPage + 1;
    if (reset) {
      taxis.clear();
      _taxiPage = 1;
      taxiHasMore.value = false;
      taxiFailed.value = false;
      taxiLoading.value = true;
      taxiLoadingMore.value = false;
    } else {
      taxiLoadingMore.value = true;
    }
    _taxisLoaded = true;
    try {
      final res = await const TaxiBrowseRepository().browseLocal(
        districtId: districtId,
        localRate: true,
        page: page,
        pageSize: _taxiPageSize,
      );
      if (seq != _taxiSeq) return;
      final known = taxis.map((t) => t.id).toSet();
      taxis.addAll(res.items.where((t) => known.add(t.id)));
      _taxiPage = page;
      taxiHasMore.value = res.hasMore;
    } catch (e) {
      if (seq != _taxiSeq) return;
      if (_isTabInactive(e)) {
        _plan.taxiTabOff.value = true;
        Get.back();
      } else if (reset && !_isUnauthorized(e)) {
        taxiFailed.value = true;
      }
    } finally {
      if (seq == _taxiSeq) {
        taxiLoading.value = false;
        taxiLoadingMore.value = false;
      }
    }
  }

  Future<void> loadMoreTaxis() async {
    if (taxiHasMore.value && !taxiLoadingMore.value) await loadTaxis(reset: false);
  }

  ({double lat, double lng})? _middlePoint(int d) {
    final p = _plan.plan.value;
    final spots = p?.dayAt(d)?.spots ?? const [];
    if (spots.isNotEmpty) {
      final lat = spots.fold<double>(0, (sum, s) => sum + s.latitude) / spots.length;
      final lng = spots.fold<double>(0, (sum, s) => sum + s.longitude) / spots.length;
      return (lat: lat, lng: lng);
    }
    final cLat = p?.centreLatitude;
    final cLng = p?.centreLongitude;
    if (cLat != null && cLng != null) return (lat: cLat, lng: cLng);
    return null;
  }

  Future<void> loadStays() async {
    final p = _plan.plan.value;
    final districtId = p?.districtId;
    if (p == null || districtId == null) return;
    final d = day.value;
    final seq = ++_staySeq;
    _staysDay = d;
    stays.clear();
    stayFailed.value = false;
    final point = _middlePoint(d);
    _staysPoint = point;
    if (point == null) return;
    stayLoading.value = true;
    try {
      final res = await withRetry(() => ApiService.get('/stays/nearby', params: {
            'latitude': point.lat,
            'longitude': point.lng,
            'radius': stayRadiusKm.value,
            'districtId': districtId,
          }));
      if (seq != _staySeq) return;
      final data = res['data'];
      final list = data is Map<String, dynamic> ? (data['items'] as List?) ?? const [] : const [];
      final items = list.map((e) => StayNearbyModel.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      stays.assignAll(items);
      _plan.fillStayCoordinates(items);
    } catch (e) {
      if (seq != _staySeq) return;
      if (_isTabInactive(e)) {
        _plan.stayTabOff.value = true;
        Get.back();
      } else if (!_isUnauthorized(e)) {
        stayFailed.value = true;
      }
    } finally {
      if (seq == _staySeq) stayLoading.value = false;
    }
  }

  Future<void> widenRadius() async {
    if (!canWidenRadius) return;
    stayRadiusKm.value = TripConstants.stayRadiusWideKm;
    await loadStays();
  }
}
