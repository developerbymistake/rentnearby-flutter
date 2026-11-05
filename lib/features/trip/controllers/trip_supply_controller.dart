import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../utils/network_retry.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../../taxi/models/taxi_browse_item.dart';
import '../trip_constants.dart';
import '../trip_strings_a2.dart';
import '../utils/trip_geo.dart';
import '../utils/trip_stay_base.dart';
import '../utils/trip_stay_rank.dart';
import '../utils/trip_taxi_fit.dart';
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
  String? _taxisKey;
  final Map<String, TripTaxiFit> _taxiFits = {};

  final stays = <StayNearbyModel>[].obs;
  final stayLoading = false.obs;
  final stayFailed = false.obs;
  final stayRadiusKm = TripConstants.stayRadiusKm.obs;
  int _staySeq = 0;
  int? _staysDay;
  String? _staysDistrict;
  String? _staysWhere;
  TripPoint? _searchPoint;
  final Map<String, TripStayFit> _stayFits = {};

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

  TripStayFit? stayFitOf(String id) => _stayFits[id];

  int? stayPriceOf(StayNearbyModel s) => TripStayRank.priceOf(_stayFits[s.id], s.minPricePerNight);

  List<StayNearbyModel> get filteredStays {
    final max = maxPrice.value;
    final homestay = onlyHomestay.value;
    final hostel = onlyHostel.value && hostelAvailable.value;
    if (max == null && !homestay && !hostel) return stays.toList();
    return stays.where((s) {
      if (max != null) {
        final price = stayPriceOf(s);
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

  TripTaxiFit? taxiFitOf(String id) => _taxiFits[id];

  TripTaxiNeed _taxiNeed(int d) {
    final p = _plan.plan.value;
    final spots = p?.dayAt(d)?.spots ?? const [];
    final first = spots.isEmpty ? null : spots.first;
    final start = p == null ? null : TripStayBase.startOf(p, d);
    return TripTaxiNeed.of(
      people: _plan.settings.peopleCount,
      km: _plan.dayKm(d),
      lat: start?.lat ?? first?.latitude,
      lng: start?.lng ?? first?.longitude,
    );
  }

  String _taxiKeyFor(String districtId, int d) => '$districtId#${_taxiNeed(d).key}';

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
    if (_taxisKey == _taxiKeyFor(districtId, day.value)) return;
    await loadTaxis();
  }

  Future<void> ensureStays() async {
    if (_staysDay != day.value || _staysDistrict != dayDistrictId) {
      await loadStays();
      return;
    }
    if (_loadKey(_nightOf(day.value)) != _staysWhere) {
      stayRadiusKm.value = TripConstants.stayRadiusKm;
      await loadStays();
    }
  }

  void _clearTaxis() {
    _taxiSeq++;
    _taxisDistrict = null;
    _taxisKey = null;
    _taxiFits.clear();
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
    final need = _taxiNeed(day.value);
    if (reset) {
      taxis.clear();
      _taxiFits.clear();
      _taxiPage = 1;
      taxiHasMore.value = false;
      taxiFailed.value = false;
      taxiLoading.value = true;
      taxiLoadingMore.value = false;
    } else {
      taxiLoadingMore.value = true;
    }
    _taxisDistrict = districtId;
    _taxisKey = '$districtId#${need.key}';
    try {
      final res = await ApiService.get('/taxis/browse', params: {
        'districtId': districtId,
        'localRate': 'true',
        'page': page,
        'pageSize': _taxiPageSize,
        ...need.params,
      });
      if (seq != _taxiSeq) return;
      final data = res['data'];
      final rows = (data is Map<String, dynamic> ? (data['items'] as List?) ?? const [] : const [])
          .whereType<Map<String, dynamic>>();
      final known = taxis.map((t) => t.id).toSet();
      for (final r in rows) {
        final t = TaxiBrowseItem.fromJson(r);
        if (!known.add(t.id)) continue;
        taxis.add(t);
        final fit = TripTaxiFit.fromJson(r);
        if (!fit.isEmpty) _taxiFits[t.id] = fit;
      }
      _taxiPage = page;
      taxiHasMore.value = data is Map<String, dynamic> && data['hasMore'] == true;
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

  TripStayNight? _nightOf(int d) {
    final near = _searchPoint;
    if (near != null) return TripStayNight(spots: [near]);
    final p = _plan.plan.value;
    final day = p?.dayAt(d);
    if (p == null || day == null) return null;
    final spots = [for (final s in day.spots) (lat: s.latitude, lng: s.longitude)].where(TripGeo.valid).toList();
    final nextDay = p.dayAt(d + 1);
    TripPoint? next;
    if (nextDay != null && nextDay.spots.isNotEmpty && p.legIndexOf(d + 1) == p.legIndexOf(d)) {
      final f = nextDay.spots.first;
      final pt = (lat: f.latitude, lng: f.longitude);
      if (TripGeo.valid(pt)) next = pt;
    }
    if (spots.isNotEmpty) return TripStayNight(spots: spots, next: next);
    final leg = p.legOf(d);
    final centre = (lat: leg.latitude, lng: leg.longitude);
    return TripGeo.valid(centre) ? TripStayNight(spots: [centre], next: next) : null;
  }

  static String? _whereKey(TripStayNight? n) =>
      n == null ? null : [for (final p in n.points) '${p.lat.toStringAsFixed(5)},${p.lng.toStringAsFixed(5)}'].join('|');

  String? _loadKey(TripStayNight? n) {
    final where = _whereKey(n);
    return where == null ? null : '$where#${_partyParams()}';
  }

  Map<String, dynamic> _partyParams() {
    final s = _plan.settings;
    final guests = s.peopleCount;
    final rooms = s.rooms;
    return {
      if (guests > 0) 'guests': guests.clamp(1, TripConstants.stayGuestsMax).toInt(),
      if (guests > 0 && rooms != null && rooms > 0) 'rooms': rooms.clamp(1, TripConstants.stayRoomsMax).toInt(),
      if (guests > 0) 'nights': 1,
      if (s.needs.contains(TripNeeds.noStairs)) 'groundFloor': true,
    };
  }

  static double _queryRadius(double discKm, double radiusKm) {
    final r = ((discKm + radiusKm) * 2).ceil() / 2;
    return r.clamp(TripConstants.stayQueryRadiusMinKm, TripConstants.stayQueryRadiusMaxKm).toDouble();
  }

  Future<void> loadStays() async {
    final p = _plan.plan.value;
    final districtId = p?.districtIdOf(day.value);
    if (p == null || districtId == null || _plan.stayTabOff.value) {
      _staySeq++;
      _staysDay = day.value;
      _staysDistrict = null;
      _stayFits.clear();
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
    _stayFits.clear();
    hostelAvailable.value = false;
    stayFailed.value = false;
    final night = _nightOf(d);
    _staysWhere = _loadKey(night);
    if (night == null) return;
    final radius = stayRadiusKm.value;
    final discs = TripGeo.cover(night.points, radius);
    if (discs.isEmpty) return;
    final party = _partyParams();
    stayLoading.value = true;
    try {
      final pages = await Future.wait([
        for (final disc in discs)
          withRetry(() => ApiService.get('/stays/nearby', params: {
                'latitude': disc.centre.lat,
                'longitude': disc.centre.lng,
                'radius': _queryRadius(disc.radiusKm, radius),
                'districtId': districtId,
                ...party,
              })),
      ]);
      if (seq != _staySeq) return;
      final rows = <Map<String, dynamic>>[];
      for (final res in pages) {
        final data = res['data'];
        final list = data is Map<String, dynamic> ? (data['items'] as List?) ?? const [] : const [];
        rows.addAll(list.whereType<Map<String, dynamic>>());
      }
      final byId = <String, StayNearbyModel>{};
      for (final r in rows) {
        final m = StayNearbyModel.fromJson(r);
        byId.putIfAbsent(m.id, () => m);
      }
      final ranked = TripStayRank.rank(rows, night, radius);
      _stayFits
        ..clear()
        ..addEntries(ranked.map((f) => MapEntry(f.id, f)));
      final items = [for (final f in ranked) ?byId[f.id]];
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
