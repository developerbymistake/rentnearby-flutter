import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/city_model.dart';
import '../services/api_service.dart';

class _LocationContext {
  final DistrictModel district;
  final CityModel? nearestCity;
  const _LocationContext({required this.district, this.nearestCity});
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

  Future<_LocationContext?> _loadContext(double lat, double lng) async {
    try {
      final res = await ApiService.get(
        '/listings/context',
        params: {'lat': lat, 'lng': lng},
      );
      final data = res['data'];
      final district =
          DistrictModel.fromJson(data['district'] as Map<String, dynamic>);
      nearbyCities.value = (data['cities'] as List)
          .map((e) => CityModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final nearestCityId = data['nearestCityId'] as String?;
      final nearestCity = nearestCityId != null
          ? nearbyCities.firstWhereOrNull((c) => c.id == nearestCityId)
          : nearbyCities.firstOrNull;
      districtUnavailable.value = false;
      return _LocationContext(district: district, nearestCity: nearestCity);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        districtUnavailable.value = true;
      }
      return null;
    }
  }

  // ── Resume handler (called by both explore screens on app foreground) ───────

  Future<void> refreshOnResume() async {
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
