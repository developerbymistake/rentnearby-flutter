import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../utils/network_retry.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../../taxi/guest/taxi_browse_repository.dart';
import '../../taxi/models/taxi_browse_item.dart';
import '../trip_constants.dart';
import '../trip_strings_a2.dart';
import 'trip_plan_controller.dart';

class TripSupplyController extends GetxController {
  static TripSupplyController get to =>
      Get.isRegistered<TripSupplyController>()
          ? Get.find<TripSupplyController>()
          : Get.put(TripSupplyController(), permanent: true);

  static const _taxiPageSize = 20;
  static const _homestay = 'Homestay';
  static const _hostel = 'Hostel';
  static const _suv = 'SUV';
  static const pricePresets = [2000, 4000, 8000];

  final day = 1.obs;

  final taxis = <TaxiBrowseItem>[].obs;
  final taxiLoading = false.obs;
  final taxiLoadingMore = false.obs;
  final taxiFailed = false.obs;
  final taxiHasMore = false.obs;
  int _taxiPage = 1;
  int _taxiSeq = 0;
  String? _taxisDistrict;

  final stays = <StayNearbyModel>[].obs;
  final stayLoading = false.obs;
  final stayFailed = false.obs;
  final stayRadiusKm = TripConstants.stayRadiusKm.obs;
  int _staySeq = 0;
  int? _staysDay;
  String? _staysDistrict;
  ({double lat, double lng})? _staysPoint;
  ({double lat, double lng})? _searchPoint;

  final maxPrice = RxnInt();
  final onlyHomestay = false.obs;
  final onlyHostel = false.obs;
  final hostelAvailable = false.obs;
  final asksLeft = RxnInt();

  final minSeats = RxnInt();
  final onlySuv = false.obs;

  TripPlanController get _plan => TripPlanController.to;

  bool get canWidenRadius => stayRadiusKm.value < TripConstants.stayRadiusWideKm;

  bool _isTabInactive(Object e) => DioErrorMapper.errorType(e) == ApiService.tabInactiveType;

  bool _isUnauthorized(Object e) => e is DioException && e.response?.statusCode == 401;

  bool get hasStayFilters => maxPrice.value != null || onlyHomestay.value || onlyHostel.value;

  List<StayNearbyModel> get filteredStays {
    final max = maxPrice.value;
    final homestay = onlyHomestay.value;
    final hostel = onlyHostel.value && hostelAvailable.value;
    if (max == null && !homestay && !hostel) return stays.toList();
    return stays.where((s) {
      if (max != null) {
        final price = s.minPricePerNight;
        if (price == null || price > max) return false;
      }
      if (homestay || hostel) {
        final type = s.stayTypeName;
        final match = (homestay && type == _homestay) || (hostel && type == _hostel);
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  void clearStayFilters() {
    maxPrice.value = null;
    onlyHomestay.value = false;
    onlyHostel.value = false;
  }

  List<TaxiBrowseItem> get filteredTaxis {
    final seats = minSeats.value;
    final suv = onlySuv.value;
    if (seats == null && !suv) return taxis.toList();
    return taxis.where((t) {
      if (seats != null && (t.seats == null || t.seats! < seats)) return false;
      if (suv && t.vehicleCategory != _suv) return false;
      return true;
    }).toList();
  }

  void setDay(int d) {
    if (d == day.value) return;
    day.value = d;
    _searchPoint = null;
    stayRadiusKm.value = TripConstants.stayRadiusKm;
  }

  void setSearchPoint(double lat, double lng) {
    _searchPoint = (lat: lat, lng: lng);
  }

  void clearSearchPoint() {
    _searchPoint = null;
  }

  String? get dayDistrictId => _plan.plan.value?.districtIdOf(day.value);

  Future<void> ensureTaxis() async {
    final districtId = dayDistrictId;
    if (districtId == null || _plan.taxiTabOff.value) {
      _clearTaxis();
      return;
    }
    if (_taxisDistrict == districtId) return;
    await loadTaxis();
  }

  Future<void> ensureStays() async {
    if (_staysDay != day.value || _staysDistrict != dayDistrictId) {
      await loadStays();
      return;
    }
    if (_middlePoint(day.value) != _staysPoint) {
      stayRadiusKm.value = TripConstants.stayRadiusKm;
      await loadStays();
    }
  }

  void _clearTaxis() {
    _taxiSeq++;
    _taxisDistrict = null;
    taxis.clear();
    taxiHasMore.value = false;
    taxiFailed.value = false;
    taxiLoading.value = false;
    taxiLoadingMore.value = false;
  }

  Future<void> loadTaxis({bool reset = true}) async {
    final p = _plan.plan.value;
    final districtId = p?.districtIdOf(day.value);
    if (p == null || districtId == null) return;
    if (_plan.taxiTabOff.value) {
      _clearTaxis();
      return;
    }
    if (!reset && (!taxiHasMore.value || taxiLoadingMore.value || taxiLoading.value)) return;
    if (!reset && districtId != _taxisDistrict) return;
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
    _taxisDistrict = districtId;
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
        taxis.clear();
        AppToast.warning(TripStringsA2.taxisOff);
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
    final near = _searchPoint;
    if (near != null) return near;
    final p = _plan.plan.value;
    final spots = p?.dayAt(d)?.spots ?? const [];
    if (spots.isNotEmpty) {
      final lat = spots.fold<double>(0, (sum, s) => sum + s.latitude) / spots.length;
      final lng = spots.fold<double>(0, (sum, s) => sum + s.longitude) / spots.length;
      return (lat: lat, lng: lng);
    }
    if (p == null || p.dayAt(d) == null) return null;
    final leg = p.legOf(d);
    if (leg.latitude == 0 && leg.longitude == 0) return null;
    return (lat: leg.latitude, lng: leg.longitude);
  }

  Future<void> loadStays() async {
    final p = _plan.plan.value;
    final districtId = p?.districtIdOf(day.value);
    if (p == null || districtId == null || _plan.stayTabOff.value) {
      _staySeq++;
      _staysDay = day.value;
      _staysDistrict = null;
      stays.clear();
      stayFailed.value = false;
      stayLoading.value = false;
      return;
    }
    final d = day.value;
    final seq = ++_staySeq;
    _staysDay = d;
    _staysDistrict = districtId;
    stays.clear();
    hostelAvailable.value = false;
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
      hostelAvailable.value = items.any((s) => s.stayTypeName == _hostel);
      _plan.fillStayCoordinates(items);
    } catch (e) {
      if (seq != _staySeq) return;
      if (_isTabInactive(e)) {
        _plan.stayTabOff.value = true;
        stays.clear();
        AppToast.warning(TripStringsA2.staysOff);
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
