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

  final stayLeg = 1.obs;
  final taxiLeg = 1.obs;
  int _taxiDay = 1;

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
  int _staySeq = 0;
  int? _staysLeg;
  String? _staysDistrict;
  String? _staysWhere;
  final Map<String, TripStayFit> _stayFits = {};

  final maxPrice = RxnInt();
  final onlyHomestay = false.obs;
  final onlyHostel = false.obs;
  final hostelAvailable = false.obs;
  final asksLeft = RxnInt();

  final minSeats = RxnInt();
  final onlySuv = false.obs;

  TripPlanController get _plan => TripPlanController.to;

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
    final start = p == null ? null : TripStayBase.startOf(p, d, _plan.enquiryList);
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

  int _anchor(int legIndex) {
    final start = _plan.plan.value?.legStart(legIndex) ?? 0;
    return start > 0 ? start : 1;
  }

  String? _districtOf(int legIndex) => _plan.plan.value?.legAt(legIndex)?.districtId;

  String? get stayDistrictId => _districtOf(stayLeg.value);

  String? get taxiDistrictId => _districtOf(taxiLeg.value);

  bool get stayDistrictPending => _plan.supplyPendingFor(_anchor(stayLeg.value));

  bool get taxiDistrictPending => _plan.supplyPendingFor(_anchor(taxiLeg.value));

  bool get staysOutOfDate => stayDistrictId != null && (_staysLeg != stayLeg.value || _staysDistrict != stayDistrictId);

  bool get taxisOutOfDate =>
      taxiDistrictId != null && !_plan.taxiTabOff.value && _taxisKey != _taxiKeyFor(taxiDistrictId!, _taxiDay);

  Future<void> ensureTaxis(int legIndex, {int? day}) async {
    taxiLeg.value = legIndex;
    _taxiDay = day ?? _anchor(legIndex);
    final districtId = taxiDistrictId;
    if (districtId == null || _plan.taxiTabOff.value) {
      _clearTaxis();
      return;
    }
    if (_taxisKey == _taxiKeyFor(districtId, _taxiDay)) return;
    await loadTaxis();
  }

  Future<void> ensureStays(int legIndex) async {
    stayLeg.value = legIndex;
    if (_staysLeg != legIndex || _staysDistrict != stayDistrictId || _staysWhere != _loadKey(legIndex)) {
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
    final districtId = taxiDistrictId;
    if (p == null || districtId == null) return;
    if (_plan.taxiTabOff.value) {
      _clearTaxis();
      return;
    }
    if (!reset && (!taxiHasMore.value || taxiLoadingMore.value || taxiLoading.value)) return;
    if (!reset && districtId != _taxisDistrict) return;
    final seq = ++_taxiSeq;
    final page = reset ? 1 : _taxiPage + 1;
    final need = _taxiNeed(_taxiDay);
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

  TripPoint? _near;

  void setNear(double? lat, double? lng) {
    final point = lat == null || lng == null ? null : (lat: lat, lng: lng);
    _near = point != null && TripGeo.valid(point) ? point : null;
  }

  TripStayNight? _legNight(int legIndex) {
    final near = _near;
    if (near != null) return TripStayNight(spots: [near]);
    final p = _plan.plan.value;
    final leg = p?.legAt(legIndex);
    if (p == null || leg == null) return null;
    final spots = <TripPoint>[
      for (final d in p.daysOf(legIndex))
        for (final s in d.spots) (lat: s.latitude, lng: s.longitude),
    ].where(TripGeo.valid).toList();
    final centre = (lat: leg.latitude, lng: leg.longitude);
    if (spots.isNotEmpty) return TripStayNight(spots: spots);
    return TripGeo.valid(centre) ? TripStayNight(spots: [centre]) : null;
  }

  TripPoint? _centre(int legIndex) {
    if (_near != null) return _near;
    final leg = _plan.plan.value?.legAt(legIndex);
    if (leg != null && leg.hasPoint) {
      final c = (lat: leg.latitude, lng: leg.longitude);
      if (TripGeo.valid(c)) return c;
    }
    return _legNight(legIndex)?.spots.first;
  }

  String? _loadKey(int legIndex) {
    final c = _centre(legIndex);
    if (c == null) return null;
    return '${c.lat.toStringAsFixed(5)},${c.lng.toStringAsFixed(5)}#${_partyParams(legIndex)}';
  }

  Map<String, dynamic> _partyParams(int legIndex) {
    final guests = _plan.settings.peopleCount;
    final nights = _plan.plan.value?.legDayCount(legIndex) ?? 1;
    return {
      if (guests > 0) 'guests': guests.clamp(1, TripConstants.stayGuestsMax).toInt(),
      if (guests > 0) 'nights': nights < 1 ? 1 : nights,
    };
  }

  Future<void> loadStays() async {
    final k = stayLeg.value;
    final p = _plan.plan.value;
    final districtId = stayDistrictId;
    if (p == null || districtId == null || _plan.stayTabOff.value) {
      _staySeq++;
      _staysLeg = k;
      _staysDistrict = null;
      _staysWhere = null;
      _stayFits.clear();
      stays.clear();
      stayFailed.value = false;
      stayLoading.value = false;
      return;
    }
    final seq = ++_staySeq;
    _staysLeg = k;
    _staysDistrict = districtId;
    stays.clear();
    _stayFits.clear();
    hostelAvailable.value = false;
    stayFailed.value = false;
    final night = _legNight(k);
    final centre = _centre(k);
    _staysWhere = _loadKey(k);
    if (night == null || centre == null) return;
    stayLoading.value = true;
    try {
      final res = await withRetry(() => ApiService.get('/stays/nearby', params: {
            'latitude': centre.lat,
            'longitude': centre.lng,
            'radius': TripConstants.stayQueryRadiusMaxKm,
            'districtId': districtId,
            ..._partyParams(k),
          }));
      if (seq != _staySeq) return;
      final data = res['data'];
      final rows = (data is Map<String, dynamic> ? (data['items'] as List?) ?? const [] : const [])
          .whereType<Map<String, dynamic>>();
      final byId = <String, StayNearbyModel>{};
      final good = <Map<String, dynamic>>[];
      for (final r in rows) {
        try {
          final m = StayNearbyModel.fromJson(r);
          byId.putIfAbsent(m.id, () => m);
          good.add(r);
        } catch (_) {}
      }
      final ranked = TripStayRank.rank(good, night, double.infinity);
      _stayFits
        ..clear()
        ..addEntries(ranked.map((f) => MapEntry(f.id, f)));
      final items = [for (final f in ranked) ?byId[f.id]];
      stays.assignAll(items);
      hostelAvailable.value = items.any((s) => s.stayTypeName == _hostel);
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
}
