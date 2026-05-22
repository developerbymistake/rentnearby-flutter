import 'dart:async';
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
  // Public reactive state observed by explore screens
  final userLocation     = Rxn<LatLng>();
  final locationLoading  = true.obs;
  final selectedDistrict = Rxn<DistrictModel>();
  final autoCity         = Rxn<CityModel>();
  final nearbyCities     = <CityModel>[].obs;

  // Private guards
  int  _loadContextVersion = 0;
  bool _autoLoading        = false;
  bool _refreshing         = false;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;

  @override
  void onInit() {
    super.onInit();
    _setupServiceStream();
    _initLocation();
  }

  @override
  void onClose() {
    _serviceStatusSub?.cancel();
    super.onClose();
  }

  // ── GPS service stream (one subscription for the entire app) ───────────────

  void _setupServiceStream() {
    _serviceStatusSub = Geolocator.getServiceStatusStream().listen((status) {
      if (status == ServiceStatus.enabled) {
        if (userLocation.value == null && !locationLoading.value) {
          locationLoading.value = true;
          _initLocation();
        }
      } else {
        userLocation.value = null;
        locationLoading.value = false;
      }
    });
  }

  // ── Location initialization ────────────────────────────────────────────────

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
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
      if (lastKnown != null) {
        userLocation.value = LatLng(lastKnown.latitude, lastKnown.longitude);
      }
      locationLoading.value = false;
      _tryAutoLoad();

      // High-accuracy fix resolves in <1 s via network + GPS coarse fix.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      userLocation.value = LatLng(pos.latitude, pos.longitude);

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
      return _LocationContext(district: district, nearestCity: nearestCity);
    } catch (_) {
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
        if (userLocation.value != null) userLocation.value = null;
        return;
      }

      if (userLocation.value == null) {
        locationLoading.value = true;
        await _initLocation();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      userLocation.value = LatLng(pos.latitude, pos.longitude);

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
