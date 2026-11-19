import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../utils/network_retry.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../data/trip_repository.dart';
import '../trip_constants.dart';
import '../trip_strings_a2.dart';
import '../utils/trip_geo.dart';
import '../utils/trip_stay_rank.dart';
import '../utils/trip_supply_area.dart';
import 'trip_plan_controller.dart';

class TripSupplyController extends GetxController {
  static TripSupplyController get to =>
      Get.isRegistered<TripSupplyController>()
          ? Get.find<TripSupplyController>()
          : Get.put(TripSupplyController(), permanent: true);

  static const _homestay = 'Homestay';
  static const _hostel = 'Hostel';
  static const pricePresets = [2000, 4000, 8000];

  final stayLeg = 1.obs;
  final stays = <StayNearbyModel>[].obs;
  final stayLoading = false.obs;
  final stayFailed = false.obs;
  int _staySeq = 0;
  int? _staysLeg;
  int? _staysCity;
  final citiesUnavailable = false.obs;
  String? _staysWhere;
  final Map<String, TripStayFit> _stayFits = {};

  final maxPrice = RxnInt();
  final onlyHomestay = false.obs;
  final onlyHostel = false.obs;
  final hostelAvailable = false.obs;
  final asksLeft = RxnInt();

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

  int _anchor(int legIndex) {
    final start = _plan.plan.value?.legStart(legIndex) ?? 0;
    return start > 0 ? start : 1;
  }

  int? _cityOf(int legIndex) {
    final leg = _plan.plan.value?.legAt(legIndex);
    return TripSupplyArea.hasCity(leg) ? leg!.cityKey : null;
  }

  int? get stayCityKey => _cityOf(stayLeg.value);

  bool _isCitiesUnavailable(Object e) => DioErrorMapper.errorType(e) == TripErrorTypes.citiesUnavailable;

  bool get stayDistrictPending => _plan.supplyPendingFor(_anchor(stayLeg.value));

  bool get staysOutOfDate => stayCityKey != null && (_staysLeg != stayLeg.value || _staysCity != stayCityKey);

  Future<void> ensureStays(int legIndex) async {
    stayLeg.value = legIndex;
    if (_staysLeg != legIndex || _staysCity != stayCityKey || _staysWhere != _loadKey(legIndex)) {
      await loadStays();
    }
  }

  TripPoint? _near;

  void setNear(double? lat, double? lng) {
    final point = lat == null || lng == null ? null : (lat: lat, lng: lng);
    _near = point != null && TripGeo.valid(point) ? point : null;
  }

  TripPoint? _centre(int legIndex) => _near ?? TripSupplyArea.centreOf(_plan.plan.value?.legAt(legIndex));

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
    final cityKey = stayCityKey;
    if (p == null || cityKey == null || _plan.stayTabOff.value) {
      _staySeq++;
      _staysLeg = k;
      _staysCity = null;
      _staysWhere = null;
      _stayFits.clear();
      stays.clear();
      stayFailed.value = false;
      stayLoading.value = false;
      return;
    }
    final seq = ++_staySeq;
    _staysLeg = k;
    _staysCity = cityKey;
    stays.clear();
    _stayFits.clear();
    hostelAvailable.value = false;
    stayFailed.value = false;
    final centre = _centre(k);
    _staysWhere = _loadKey(k);
    if (centre == null) {
      stayLoading.value = false;
      return;
    }
    final night = TripStayNight(spots: [centre]);
    stayLoading.value = true;
    try {
      final res = await withRetry(() => ApiService.get('/stays/nearby', params: {
            'latitude': centre.lat,
            'longitude': centre.lng,
            'cityKey': cityKey,
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
      citiesUnavailable.value = false;
    } catch (e) {
      if (seq != _staySeq) return;
      if (_isCitiesUnavailable(e)) citiesUnavailable.value = true;
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
