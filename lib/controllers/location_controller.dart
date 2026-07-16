import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../config/app_constants.dart';
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

  // ── Location-search feature — precise pin, fully shared (like browsing
  // above) so Room and Plot always show the exact same searched spot, not
  // just the same district. See setBrowsing()/resetBrowsing() for why the
  // pin's lifecycle is tied to theirs, and beginSearchOverride()/
  // endSearchOverride() for the session API the search UI actually uses.
  final searchPinOverride = Rxn<LatLng>();
  final searchPinLabel    = Rxn<String>();
  final searchResolving   = false.obs;

  int _searchGeneration = 0;
  DistrictModel? _preSearchSnapshotDistrict;
  CityModel?     _preSearchSnapshotCity;
  bool           _hasPreSearchSnapshot = false;

  /// Fires once, AFTER every field above has settled to its final value, for
  /// every browsing/search transition (setBrowsing/resetBrowsing/
  /// beginSearchOverride/endSearchOverride). Listeners that need a fully
  /// consistent read of effectiveDistrict/effectiveCity/effectiveSearchCenter
  /// (e.g. moving a map camera) should watch this instead of any single field
  /// above — reacting to e.g. browsingCity alone can observe searchPinOverride
  /// still holding its PREVIOUS value mid-transition, since `.trigger()`
  /// notifies synchronously and related fields update one at a time.
  final locationSelectionChanged = 0.obs;

  /// The district whose listings should currently be shown: the browsed one
  /// if the user is temporarily exploring elsewhere, otherwise the real one.
  DistrictModel? get effectiveDistrict => browsingDistrict.value ?? selectedDistrict.value;

  /// The city paired with [effectiveDistrict] — browsed city if the user is
  /// exploring elsewhere, otherwise the GPS-nearest city in the real district.
  /// Callers should treat this as a soft ranking hint, never a hard filter —
  /// District is the only real visibility boundary (see the district-gating
  /// comments on GetNearbyAsync).
  CityModel? get effectiveCity => browsingCity.value ?? autoCity.value;

  /// Map/radius center for the explore screens: precise search pin (if any)
  /// > browsed city's stored coordinate > live GPS > GPS-nearest city >
  /// hardcoded last-resort fallback. Shared across Rooms and Plots — moved
  /// here (from being duplicated per-screen) so both screens always agree on
  /// exactly the same point, not just the same district.
  LatLng get effectiveSearchCenter {
    final pin = searchPinOverride.value;
    if (pin != null) return pin;
    final city = browsingCity.value;
    if (city?.latitude != null && city?.longitude != null) {
      return LatLng(city!.latitude!, city.longitude!);
    }
    final loc = userLocation.value;
    if (loc != null) return loc;
    final auto = autoCity.value;
    if (auto?.latitude != null && auto?.longitude != null) {
      return LatLng(auto!.latitude!, auto.longitude!);
    }
    return const LatLng(AppConstants.fallbackLat, AppConstants.fallbackLng);
  }

  final _locationsRepo = LocationsRepository();
  List<DistrictModel> _allDistricts = [];

  /// Applies browsingDistrict/browsingCity/searchPinOverride/searchPinLabel
  /// together — the single place these four fields are ever triggered, so
  /// every public method below produces the exact same field-by-field
  /// sequence. Uses `.trigger()`, not `.value =`, so `ever(...)` listeners on
  /// any individual field always fire on every call — including when the
  /// newly-resolved data is logically the same as what's already set (e.g.
  /// two searches inside the same city in a row). Relying on
  /// `DistrictModel`/`CityModel`'s default identity `==` to guarantee that
  /// two calls with "the same" data always produced distinct instances was
  /// fragile; `trigger()` makes the always-notify behavior explicit.
  void _applyBrowsingState({DistrictModel? district, CityModel? city, LatLng? pin, String? label}) {
    browsingDistrict.trigger(district);
    browsingCity.trigger(city);
    searchPinOverride.trigger(pin);
    searchPinLabel.trigger(label);
  }

  /// Sets both the browsed district and the specific city within it the user
  /// picked. Both are required together — there is no "current position"
  /// concept for a district the user isn't physically in.
  ///
  /// Also bumps the search generation and clears any precise search pin: a
  /// manual city-switch (the only caller of this method directly —
  /// `LocationSwitchSheet`) is a deliberate, coarse action that must
  /// supersede/discard any leftover precise search pin, and must invalidate
  /// any location-search resolve that might still be in flight (each bottom
  /// tab is its own nested Navigator kept mounted by an IndexedStack, so a
  /// city-switch on one tab can genuinely race a still-resolving search
  /// started on the other — see `beginSearchResolve`/`isCurrentSearchGeneration`).
  void setBrowsing(DistrictModel district, CityModel city) {
    _searchGeneration++;
    searchResolving.value = false;
    _applyBrowsingState(district: district, city: city);
    locationSelectionChanged.value++;
  }

  /// Discards any in-progress manual browsing and returns to the real district.
  /// Same generation-bump/pin-clearing reasoning as [setBrowsing] above.
  void resetBrowsing() {
    _searchGeneration++;
    searchResolving.value = false;
    _applyBrowsingState();
    _hasPreSearchSnapshot = false;
    _preSearchSnapshotDistrict = null;
    _preSearchSnapshotCity = null;
    locationSelectionChanged.value++;
  }

  // ── Location-search session API ─────────────────────────────────────────
  // Used by ExploreLocationSearchMixin (Rooms + Plots) — kept here so both
  // screens share one session, one snapshot, and one generation counter,
  // rather than each screen tracking its own (which would let cancelling
  // from one screen fail to restore a manual browse made from the other).

  /// Marks a search resolve in-flight and returns an opaque token. Callers
  /// should check [isCurrentSearchGeneration] after their `await` before
  /// applying anything — see [beginSearchOverride].
  int beginSearchResolve() {
    searchResolving.value = true;
    return ++_searchGeneration;
  }

  /// True if [token] (from [beginSearchResolve]) is still the most recent
  /// attempt — false if superseded by a newer search, a manual city-switch,
  /// a recenter, or an app resume while this one was in flight.
  bool isCurrentSearchGeneration(int token) => token == _searchGeneration;

  /// Applies a successfully-resolved search pick. Captures the pre-search
  /// snapshot only if one isn't already in progress — guards a rapid
  /// re-search from re-capturing a mid-search state as if it were original
  /// (structurally shouldn't happen given the toggle button gates a new
  /// search behind cancelling the active one first, but kept defensive).
  void beginSearchOverride(
      DistrictModel district, CityModel city, LatLng pin, String label) {
    if (!_hasPreSearchSnapshot) {
      _preSearchSnapshotDistrict = browsingDistrict.value;
      _preSearchSnapshotCity = browsingCity.value;
      _hasPreSearchSnapshot = true;
    }
    _searchGeneration++;
    searchResolving.value = false;
    // One call, straight to the final pin — searchPinOverride is never
    // observably null mid-transition the way it would be if this went
    // through setBrowsing() (which always clears the pin) and then set the
    // real pin as a separate, later step.
    _applyBrowsingState(district: district, city: city, pin: pin, label: label);
    locationSelectionChanged.value++;
  }

  /// Cancels the active search, restoring whatever was truly active before
  /// ANY tab's search began — controller-level, so cancelling from either
  /// screen is correct even if the OTHER screen initiated the search.
  void endSearchOverride() {
    if (_hasPreSearchSnapshot) {
      final d = _preSearchSnapshotDistrict;
      final c = _preSearchSnapshotCity;
      _hasPreSearchSnapshot = false;
      _preSearchSnapshotDistrict = null;
      _preSearchSnapshotCity = null;
      _searchGeneration++;
      searchResolving.value = false;
      if (d != null && c != null) {
        _applyBrowsingState(district: d, city: c);
      } else {
        _applyBrowsingState();
      }
    } else {
      // Defensive only — the UI only allows cancel while isSearchActive.
      _searchGeneration++;
      searchResolving.value = false;
      searchPinOverride.trigger(null);
      searchPinLabel.trigger(null);
    }
    locationSelectionChanged.value++;
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
