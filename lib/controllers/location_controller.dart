import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/city_model.dart';
import '../models/location_context.dart';
import '../repositories/locations_repository.dart';
import '../services/api_service.dart';

/// Result shape for the GPS-flow resolver ([LocationController._loadContext])
/// — deliberately distinct from the public [LocationContext] (which also
/// carries the full district's city list, irrelevant to GPS callers).
class _LoadContextResult {
  final DistrictModel district;
  final CityModel? nearestCity;
  const _LoadContextResult({required this.district, this.nearestCity});
}

class LocationController extends GetxController {
  // Public reactive state observed by explore screens and MainScreen
  final userLocation        = Rxn<LatLng>();
  final locationLoading     = true.obs;
  final selectedDistrict    = Rxn<DistrictModel>();
  final autoCity            = Rxn<CityModel>();
  final nearbyCities        = <CityModel>[].obs;
  final districtUnavailable = false.obs;
  final gpsEnabled               = true.obs;
  final isOffline                = false.obs;
  // Incremented each time a fresh GPS position is obtained — explore screens
  // watch this to fit camera and reload data without depending on locationLoading.
  final locationRefreshedTrigger = 0.obs;

  // ── Manual district/city browsing (district-switch feature) ────────────────
  // A user-initiated, TEMPORARY override for exploring a district other than
  // their real one. Deliberately kept separate from `selectedDistrict`/
  // `autoCity` above — it must never be read by listing creation or by the
  // district-banner/notification-topic logic, both of which must always stay
  // tied to the user's real, GPS-resolved district. It is in-memory only and
  // is never persisted to disk: it resets to null on every app resume/cold
  // start (see `resetBrowsing()` and its call in `refreshOnResume()`).
  final browsingDistrict = Rxn<DistrictModel>();
  final browsingCity     = Rxn<CityModel>();

  /// The district whose listings should currently be shown: the browsed one
  /// if the user is temporarily exploring elsewhere, otherwise the real one.
  DistrictModel? get effectiveDistrict => browsingDistrict.value ?? selectedDistrict.value;

  /// The city paired with [effectiveDistrict] — browsed city if the user is
  /// exploring elsewhere, otherwise the GPS-nearest city in the real district.
  /// Callers should treat this as a soft ranking hint, never a hard filter —
  /// District is the only real visibility boundary (see the district-gating
  /// comments on GetNearbyAsync).
  CityModel? get effectiveCity => browsingCity.value ?? autoCity.value;

  final _locationsRepo = LocationsRepository();
  List<DistrictModel> _allDistricts = [];

  /// Sets both the browsed district and the specific city within it the user
  /// picked. Both are required together — there is no "current position"
  /// concept for a district the user isn't physically in.
  ///
  /// Uses `.trigger()`, not `.value =`, so `ever(browsingCity, ...)` listeners
  /// (both explore screens' `_browsingWorker`, and location-search's own
  /// stale-override worker) always fire on every call — including when the
  /// newly-resolved district/city is logically the same as the one already
  /// being browsed (e.g. two searches inside the same city in a row). Relying
  /// on `DistrictModel`/`CityModel`'s default identity `==` to guarantee that
  /// two calls with "the same" data always produced distinct instances was
  /// fragile; `trigger()` makes the always-notify behavior explicit.
  void setBrowsing(DistrictModel district, CityModel city) {
    browsingDistrict.trigger(district);
    browsingCity.trigger(city);
  }

  /// Discards any in-progress manual browsing and returns to the real district.
  void resetBrowsing() {
    browsingDistrict.trigger(null);
    browsingCity.trigger(null);
  }

  /// All districts (active + inactive), for the "change district" list.
  /// Cached by [LocationsRepository] — cheap to call repeatedly.
  Future<List<DistrictModel>> loadAllDistricts({bool forceRefresh = false}) async {
    _allDistricts = await _locationsRepo.getAllDistricts(forceRefresh: forceRefresh);
    return _allDistricts;
  }

  /// Unique state names derived from the last-loaded district list.
  /// Call [loadAllDistricts] first.
  List<String> get browsableStates => _locationsRepo.statesFrom(_allDistricts);

  Future<List<CityModel>> loadCitiesForDistrict(String districtId, {bool forceRefresh = false}) =>
      _locationsRepo.getCitiesForDistrict(districtId, forceRefresh: forceRefresh);

  // Private guards
  int  _loadContextVersion = 0;
  bool _autoLoading        = false;
  bool _refreshing         = false;
  bool _initRunning        = false;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void onInit() {
    super.onInit();
    _setupServiceStream();
    _setupConnectivity();
    _initLocation();
  }

  @override
  void onClose() {
    _serviceStatusSub?.cancel();
    _connectivitySub?.cancel();
    super.onClose();
  }

  // ── GPS service stream (one subscription for the entire app) ───────────────

  void _setupServiceStream() {
    _serviceStatusSub = Geolocator.getServiceStatusStream().listen((status) {
      gpsEnabled.value = (status == ServiceStatus.enabled);
      if (status == ServiceStatus.enabled) {
        if (userLocation.value != null) {
          // Already have a location from before GPS was off.
          // Fire the trigger immediately so screens reposition at once,
          // then quietly fetch a fresh fix in the background.
          locationRefreshedTrigger.value++;
          _refreshLocation();
        } else if (!locationLoading.value && !_initRunning) {
          // No location at all (fresh install or permission just granted).
          locationLoading.value = true;
          _initLocation();
        }
      } else {
        // Keep userLocation at its last-known value — never clear it on GPS off.
        locationLoading.value = false;
      }
    });
  }

  // ── Background location refresh (GPS came back, we already had a position) ──

  Future<void> _refreshLocation() async {
    if (_refreshing || _initRunning) return;
    _refreshing = true;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      userLocation.value = LatLng(pos.latitude, pos.longitude);
      // Do NOT fire locationRefreshedTrigger here — it already fired immediately
      // when GPS turned on (_setupServiceStream). A second trigger would cause a
      // second API call and a visible pin-flash on screen.
      // _userLocationWorker handles the dot + circle update automatically.
      // If the user moved to a new district, _locationWorker fires the data reload.
      final myVersion = ++_loadContextVersion;
      final ctx = await _loadContext(pos.latitude, pos.longitude);
      if (ctx == null) return;
      if (myVersion != _loadContextVersion) return;
      if (selectedDistrict.value == null ||
          selectedDistrict.value!.id != ctx.district.id) {
        autoCity.value = ctx.nearestCity;
        selectedDistrict.value = ctx.district;
      }
    } catch (_) {
    } finally {
      _refreshing = false;
    }
  }

  // ── Connectivity stream (one subscription for the entire app) ──────────────

  void _setupConnectivity() {
    Connectivity().checkConnectivity().then((results) {
      isOffline.value = results.every((r) => r == ConnectivityResult.none);
    });
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      isOffline.value = results.every((r) => r == ConnectivityResult.none);
    });
  }

  // ── GPS recheck (called by GPS gate "Check Again" button) ──────────────────

  Future<void> recheckGps() async {
    gpsEnabled.value = await Geolocator.isLocationServiceEnabled();
  }

  // ── Location initialization ────────────────────────────────────────────────

  Future<void> _initLocation() async {
    if (_initRunning) return;
    _initRunning = true;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      gpsEnabled.value = serviceEnabled;
      if (!serviceEnabled) {
        locationLoading.value = false;
        _tryAutoLoad();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          locationLoading.value = false;
          _tryAutoLoad();
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        locationLoading.value = false;
        _tryAutoLoad();
        return;
      }

      // Last-known fix renders the map immediately without waiting for GPS.
      final lastKnown = await Geolocator.getLastKnownPosition();
      final firedTriggerForLastKnown = lastKnown != null;
      if (lastKnown != null) {
        userLocation.value = LatLng(lastKnown.latitude, lastKnown.longitude);
        // Fire trigger immediately — shimmer hides and camera fits at once.
        locationRefreshedTrigger.value++;
      }
      locationLoading.value = false;
      _tryAutoLoad();

      // High-accuracy fix — refines position after last-known render.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      userLocation.value = LatLng(pos.latitude, pos.longitude);
      // Only fire the trigger here if the last-known fix never fired it —
      // otherwise this is a silent refinement of a position the UI already
      // reacted to: userLocation.value still updates the user's dot (via
      // _userLocationWorker), but re-firing the trigger would fit the camera
      // and hide/reshow the pin overlay a second time for no visible reason
      // (same reasoning as _refreshLocation() below, which never double-fires).
      if (!firedTriggerForLastKnown) {
        locationRefreshedTrigger.value++;
      }

      // Version-controlled context update cancels any stale response.
      final myVersion = ++_loadContextVersion;
      final ctx = await _loadContext(pos.latitude, pos.longitude);
      if (ctx == null) return;
      if (myVersion != _loadContextVersion) return;
      if (selectedDistrict.value == null ||
          selectedDistrict.value!.id != ctx.district.id) {
        autoCity.value = ctx.nearestCity;
        selectedDistrict.value = ctx.district;  // fires screen worker after autoCity is set
      }
    } catch (_) {
      locationLoading.value = false;
      _tryAutoLoad();
    } finally {
      _initRunning = false;
    }
  }

  void _tryAutoLoad() {
    if (selectedDistrict.value != null) return;
    if (locationLoading.value) return;
    if (_autoLoading) return;
    _autoLoad();
  }

  Future<void> _autoLoad() async {
    final loc = userLocation.value;
    if (loc == null) return;
    _autoLoading = true;
    try {
      final myVersion = ++_loadContextVersion;
      final ctx = await _loadContext(loc.latitude, loc.longitude);
      if (ctx == null) return;
      if (myVersion != _loadContextVersion) return;
      autoCity.value = ctx.nearestCity;
      selectedDistrict.value = ctx.district;  // fires screen worker after autoCity is set
    } finally {
      _autoLoading = false;
    }
  }

  // ── Context API ────────────────────────────────────────────────────────────

  /// Pure coordinate → district/city resolver: one network call, no side
  /// effects on any controller state. Throws [DistrictNotFoundException] on a
  /// confirmed 404 (point outside every active district's boundary);
  /// rethrows anything else (network/parse failures) as-is.
  Future<LocationContext> _fetchLocationContext(double lat, double lng) async {
    try {
      final res = await ApiService.get(
        '/listings/context',
        params: {'lat': lat, 'lng': lng},
      );
      final data = res['data'];
      final district =
          DistrictModel.fromJson(data['district'] as Map<String, dynamic>);
      final cities = (data['cities'] as List)
          .map((e) => CityModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final nearestCityId = data['nearestCityId'] as String?;
      final nearestCity = nearestCityId != null
          ? cities.firstWhereOrNull((c) => c.id == nearestCityId)
          : cities.firstOrNull;
      return LocationContext(
          district: district, nearestCity: nearestCity, citiesInDistrict: cities);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) throw const DistrictNotFoundException();
      rethrow;
    }
  }

  /// GPS-flow resolver: wraps [_fetchLocationContext] and additionally
  /// updates [nearbyCities]/[districtUnavailable] — state that is
  /// semantically tied to the user's REAL, GPS-resolved position (used by the
  /// "nearby cities" rail and the district-unavailable banner). Used only by
  /// the GPS-driven flows below (`_initLocation`, `_autoLoad`,
  /// `_refreshLocation`, `refreshOnResume`).
  Future<_LoadContextResult?> _loadContext(double lat, double lng) async {
    try {
      final ctx = await _fetchLocationContext(lat, lng);
      nearbyCities.value = ctx.citiesInDistrict;
      districtUnavailable.value = false;
      return _LoadContextResult(district: ctx.district, nearestCity: ctx.nearestCity);
    } on DistrictNotFoundException {
      districtUnavailable.value = true;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Side-effect-free coordinate → district/city resolver, for one-off point
  /// lookups (currently: location search). Unlike [_loadContext] (GPS flows),
  /// this deliberately does NOT touch [nearbyCities] or [districtUnavailable]:
  /// those two are semantically tied to the user's REAL, GPS-resolved
  /// position and district-service-area banner — they must never be
  /// overwritten by a resolve for an arbitrary searched point that may be in
  /// a completely different (and possibly unserviceable) district than the
  /// user's real one.
  ///
  /// Throws [DistrictNotFoundException] on a confirmed 404 (point outside
  /// every active district). Any other failure (network/timeout/parse)
  /// propagates as-is — callers should catch broadly for a generic error and
  /// catch [DistrictNotFoundException] specifically for a precise
  /// "not serviceable here" message.
  Future<LocationContext> resolveDistrictAt(double lat, double lng) =>
      _fetchLocationContext(lat, lng);

  // ── Resume handler (called by both explore screens on app foreground) ───────

  Future<void> refreshOnResume() async {
    // Manual browsing is temporary — always discard it on resume/cold start,
    // regardless of what happens with the GPS refresh below. Unconditional
    // and placed before the guard so it fires on every resume call.
    resetBrowsing();

    // Guard: one refresh at a time, skip if location init is in progress.
    if (locationLoading.value || _refreshing) return;
    _refreshing = true;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // GPS is off — keep userLocation at last-known, just return.
        return;
      }

      if (userLocation.value == null) {
        // No fix ever obtained (fresh install) — run full init.
        if (_initRunning) return;
        locationLoading.value = true;
        await _initLocation();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      userLocation.value = LatLng(pos.latitude, pos.longitude);
      locationRefreshedTrigger.value++;

      final ctx = await _loadContext(pos.latitude, pos.longitude);
      if (ctx == null) return;
      // Only update if user moved to a different district.
      if (selectedDistrict.value == null ||
          selectedDistrict.value!.id != ctx.district.id) {
        autoCity.value = ctx.nearestCity;
        selectedDistrict.value = ctx.district;  // fires screen worker after autoCity is set
      }
    } catch (_) {
    } finally {
      _refreshing = false;
    }
  }
}
