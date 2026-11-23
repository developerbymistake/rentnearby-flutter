import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/sheet_close_button.dart';
import 'package:bakhli/design/extra/stay_grid_card.dart';
import 'package:bakhli/design/extra/tone_segment_control.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../config/app_constants.dart';
import '../../../config/app_insets.dart';
import '../../../config/module_palette.dart';
import '../../../config/app_map_state.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/location_controller.dart';
import '../../../models/browse_item.dart';
import '../../map_discovery/data/map_pack_service.dart';
import '../../map_discovery/data/pack_retry.dart';
import '../../nearby/controllers/nearby_centre_controller.dart';
import '../../nearby/widgets/place_search_bar.dart';
import '../../trip/data/trip_city_catalog.dart';
import '../../trip/map/discovery_api.dart';
import '../../trip/map/discovery_overlay.dart';
import '../../trip/map/trip_discovery_layer.dart';
import '../../trip/widgets/trip_map_controls.dart';
import '../../trip/models/trip_spot_model.dart';
import '../../trip/utils/trip_spots_cache.dart';
import '../../trip/widgets/trip_spot_detail_sheet.dart';
import '../../../utils/map_clustering.dart';
import '../../../utils/money_format.dart';
import '../../../widgets/empty_radius_hint.dart';
import '../../../widgets/nearest_confirm_sheet.dart';
import '../../../widgets/nearest_control_bar.dart';
import '../models/stay_nearby_model.dart';
import 'stay_bottom_sheet.dart';
import 'stay_guest_controller.dart';
import 'stay_landing_controller.dart';
import 'stay_map_load_logic.dart';

final KitTone _forest = KitTone(
  accent: ListingPalette.forest.g1,
  accentDark: ListingPalette.forest.g2,
  tint: ListingPalette.forest.tint,
  gradient: ListingPalette.forest.gradient,
  glow: ListingPalette.forest.g2,
);
final ModulePalette _forestPalette = ModulePalette(
  accent: ListingPalette.forest.g1,
  accentDark: ListingPalette.forest.g2,
  accentLight: ListingPalette.forest.button,
  surface: ListingPalette.forest.tint,
  gradient: ListingPalette.forest.gradient,
);
final String _forestHex = DesignHex.of(ListingPalette.forest.g2);

class StayMapScreen extends StatefulWidget {
  const StayMapScreen({super.key});
  @override
  State<StayMapScreen> createState() => _StayMapScreenState();
}

class _StayMapScreenState extends State<StayMapScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  MapLibreMapController? _mapController;
  double _currentZoom = 13.0;
  Size _screenSize = Size.zero;
  Circle? _nativeUserDot;
  final _circleCache = <double, Map<String, dynamic>>{};
  bool _pinsVisible = true;
  bool _styleLoaded = false;
  LatLng? _cameraCenter;
  bool _mapActive = true;
  bool _isCameraMoving = false;
  Timer? _cameraIdleDebounce;
  Worker? _mapPauseWorker;

  final _guest = StayGuestController.to;
  final _locationCtrl = Get.find<LocationController>();
  final _auth = Get.find<AuthController>();
  final _centre = NearbyCentreController.to;
  final _workers = <Worker>[];
  PackRetry? _packRetry;
  bool get _stale => _loader.stale;
  set _stale(bool v) => _loader.stale = v;
  late final StayNearbyLoader _loader = StayNearbyLoader(
    centre: () => (_searchCenter.latitude, _searchCenter.longitude),
    radius: () => _radius,
    isPaused: () => mapShouldPause.value,
    isMounted: () => mounted,
    fetch: _guest.loadNearby,
    nearestActive: () => _guest.nearestActive.value,
    hasStays: () => _guest.nearbyStays.isNotEmpty,
    onStart: _onLoadStart,
    onSettled: _onLoadSettled,
  );

  List<_MapMarkerData> _markerData = [];
  double _radius = AppConstants.defaultRadiusKm;
  double? _preSearchRadius;
  double _lastClusterZoom = 0;
  bool _markersDirty = false;
  bool _mapReady = false;
  Timer? _loadNearbyDebounceTimer;
  final _audioPlayer = AudioPlayer();
  int _revealedCount = 0;
  Timer? _revealTimer;
  late AnimationController _radarController;
  late final AnimationController _chromeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  late final AnimationController _nearestCircleController;
  Animation<double>? _nearestCircleAnim;
  LatLng? _nearestCircleCenter;

  TripDiscoveryLayer? _disc;
  bool _discBusy = false;
  String? _discPoint;
  bool _sheetOpen = false;
  Map<int, String>? _cityNames;
  Object? _cityNamesKey;
  final _topKey = GlobalKey();
  static const double _discCardBand = 150;

  double get _discTopInset {
    final box = _topKey.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size.height : DS.s(220);
  }

  double get _discBottomInset =>
      BarMetrics.bodyBottomOf(context) - BarMetrics.bodyGap + DS.s(24) + DS.s(KitMetrics.touch + 2);

  bool get _onStaysTab => _auth.tabIndex.value == AppTabs.stays;

  @override
  void initState() {
    super.initState();

    _radarController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _chromeController.forward();

    _nearestCircleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))
      ..addListener(() {
        final anim = _nearestCircleAnim;
        final ctrl = _mapController;
        final center = _nearestCircleCenter;
        if (anim == null || ctrl == null || center == null) return;
        ctrl.setGeoJsonSource('radius-source', _buildCircleGeojson(center, anim.value));
      });

    WidgetsBinding.instance.addObserver(this);

    _workers.add(
      ever(_centre.centreVersion, (_) {
      if (!mounted) return;
      if (_hasPin && _preSearchRadius == null) {
        _preSearchRadius = _radius;
        if (_radius < AppConstants.defaultRadiusKm) setState(() => _radius = AppConstants.defaultRadiusKm);
      } else if (!_hasPin && _preSearchRadius != null) {
        setState(() => _radius = _preSearchRadius!);
        _preSearchRadius = null;
      }
      if (_onStaysTab && !mapShouldPause.value) {
        _precomputeCircleCache();
        _loadNearby();
        if (_mapReady) _fitToRadius();
      } else {
        _stale = true;
      }
      }),
    );

    _workers.add(
      ever(_locationCtrl.locationRefreshedTrigger, (_) {
      if (!mounted) return;
      if (_locationCtrl.browsingCity.value == null) {
        _precomputeCircleCache();
        if (_mapReady) {
          _updateNativeRadiusCircle();
          _fitToRadius();
        }
      }
      setState(() {});
      }),
    );

    _workers.add(
      ever(_locationCtrl.userLocation, (_) {
      if (!mounted) return;
      if (_mapReady) {
        final loc = _locationCtrl.userLocation.value;
        if (loc != null) {
          if (_nativeUserDot == null) {
            _initNativeUserDot();
          } else {
            _updateNativeUserDot();
          }
          if (_locationCtrl.browsingCity.value == null) {
            _precomputeCircleCache();
            _updateNativeRadiusCircle();
          }
          if (_markerData.isNotEmpty && _markerData.first.isUser) {
            final m = _buildUserMarkerData();
            if (m != null) _markerData[0] = m;
          }
        } else {
          if (_markerData.isNotEmpty && _markerData.first.isUser) {
            _markerData.removeAt(0);
          }
        }
      }
      if (_pinsVisible && !_isCameraMoving) {
        setState(() {});
      } else {
        _markersDirty = true;
      }
      }),
    );

    if (Get.isRegistered<StayLandingController>(tag: StayLandingController.tag)) {
      final landing = Get.find<StayLandingController>(tag: StayLandingController.tag);
      _workers.add(
        ever(landing.stayPostedTrigger, (_) {
        _stale = true;
        if (_onStaysTab && !mapShouldPause.value) _loadNearby();
        }),
      );
      _workers.add(
        ever(landing.exploreRefreshTrigger, (_) {
        _stale = true;
        if (_onStaysTab && !mapShouldPause.value) _loadNearby();
        }),
      );
      _workers.add(
        ever(landing.filterResetTrigger, (_) {
        if (!mounted || !_mapReady) return;
        _precomputeCircleCache();
        _updateNativeRadiusCircle();
        _fitToRadius();
        }),
      );
    }

    _workers.add(
      ever(_guest.isLoading, (loading) {
      if (!loading && _radarController.isAnimating) {
        _radarController.stop();
        _radarController.reset();
      }
      }),
    );

    _mapPauseWorker = ever(mapShouldPause, (bool paused) {
      if (!mounted) return;
      if (paused) {
        _dropDisc();
        setState(() {
          _mapActive = false;
          _styleLoaded = false;
          _mapReady = false;
          _mapController = null;
          _nativeUserDot = null;
        });
      } else {
        setState(() => _mapActive = true);
        if (_onStaysTab && _stale) _loadNearby();
      }
    });

    _workers.add(
      ever(_auth.tabIndex, (index) {
      if (index == AppTabs.stays) {
        if (_stale && !mapShouldPause.value) {
          _loadNearby();
          if (_mapReady && !_isCameraMoving) _fitToRadius();
        }
      } else {
        if (_radarController.isAnimating) {
          _radarController.stop();
          _radarController.reset();
        }
        if (_radius != AppConstants.defaultRadiusKm) {
          setState(() => _radius = AppConstants.defaultRadiusKm);
          _stale = true;
        }
      }
      }),
    );

    _workers.add(
      ever(_guest.nearestActive, (bool active) {
      if (!mounted) return;
      if (active) {
        _disc?.clearSelection().ignore();
        _updateNearestFocus();
        _playTing();
      } else {
        _nearestCircleAnim = null;
        _nearestCircleController.stop();
        _guest.clearNearest();
        if (_mapReady) {
          _updateNativeRadiusCircle();
          _fitToRadius();
        }
        _buildMarkers(animate: false);
      }
      }),
    );
    _workers.add(
      ever(_guest.nearestFocusIndex, (_) {
      if (!mounted) return;
      if (_guest.nearestActive.value) _updateNearestFocus();
      }),
    );

    _workers.add(ever(_discSource.state, (_) => _onDiscChanged()));
    _workers.add(ever(MapPackService.to.revision, (_) => _onDiscChanged()));
    _packRetry = PackRetry(
      source: _discSource,
      ensure: _retryDiscArea,
      retryPhotos: () => _disc?.retryPhotos(),
      offline: _locationCtrl.isOffline,
    );

    _mapActive = !mapShouldPause.value;
    if (_hasPin) {
      _preSearchRadius = _radius;
      if (_radius < AppConstants.defaultRadiusKm) _radius = AppConstants.defaultRadiusKm;
    }
    if (!mapShouldPause.value) {
      _precomputeCircleCache();
      _loadNearby(keepNearest: true);
    } else {
      _stale = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final w in _workers) {
      w.dispose();
    }
    _mapPauseWorker?.dispose();
    _packRetry?.dispose();
    _dropDisc();
    if (_guest.nearestActive.value) _guest.nearestActive.value = false;
    _guest.clearNearest();
    _audioPlayer.dispose();
    _radarController.dispose();
    _chromeController.dispose();
    _nearestCircleController.dispose();
    _revealTimer?.cancel();
    _loadNearbyDebounceTimer?.cancel();
    _cameraIdleDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_guest.isLoading.value && _radarController.isAnimating) {
        _radarController.stop();
        _radarController.reset();
      }
    }
  }

  bool get _hasPin => _centre.hasPin;

  LatLng get _searchCenter => _centre.centre;

  void _fitToRadius() {
    if (!_mapReady || !mounted) return;
    final center = _searchCenter;
    _cameraCenter = center;
    _precomputeCircleCache();
    _animateTo(center, _zoomForRadius(_radius, center.latitude));
    _updateNativeRadiusCircle();
    _syncDiscArea();
  }

  DiscoveryDataSource get _discSource => MapPackService.to.source;

  void _syncDiscArea() {
    final c = _searchCenter;
    final point = '${c.latitude},${c.longitude}';
    if (point != _discPoint || _discSource.state.value == DiscoveryDataState.none) {
      _discPoint = point;
      _discSource.ensureForPoint(c.latitude, c.longitude).ignore();
    }
    _disc?.setPhotoArea(c.latitude, c.longitude, _radius * 2).ignore();
  }

  void _retryDiscArea() {
    if (!mounted) return;
    final c = _searchCenter;
    _discSource.ensureForPoint(c.latitude, c.longitude).ignore();
  }

  DiscoveryHost _discHost() => DiscoveryHost.readOnly(
        anchorLayerId: () => _mapController?.circleManager?.layerIds.first,
        topInset: () => _discTopInset,
        bottomInset: () => _discBottomInset,
        onDetails: _openSpotDetails,
        lineFor: _spotLine,
      );

  Future<void> _attachDisc() async {
    final map = _mapController;
    if (_discBusy || _disc != null || map == null || !_mapReady) return;
    _discBusy = true;
    try {
      final layer = await DiscoveryAttach.maybe(
        map,
        mode: DiscoveryMode.readOnly,
        host: _discHost(),
        source: _discSource,
        tuning: DiscTuning.stay,
        viewSize: () => _screenSize,
        unitsPerDp: () => DiscoveryAttach.unitsPerDp(context),
        cardHeight: () => DS.s(_discCardBand),
        tapsBlocked: () => _sheetOpen || _guest.nearestActive.value,
      );
      if (layer == null) return;
      if (!mounted || !identical(map, _mapController)) {
        layer.dispose();
        return;
      }
      final c = _searchCenter;
      await layer.setPhotoArea(c.latitude, c.longitude, _radius * 2);
      if (!mounted || !identical(map, _mapController)) {
        layer.dispose();
        return;
      }
      setState(() => _disc = layer);
    } finally {
      _discBusy = false;
    }
  }

  Future<void> _onDiscChanged() async {
    if (!mounted || !_mapReady) return;
    final d = _disc;
    if (d == null) {
      await _attachDisc();
      return;
    }
    if (DiscoveryAttach.wanted(_discSource)) {
      d.refreshData().ignore();
      return;
    }
    setState(() => _disc = null);
    await d.detach();
    d.dispose();
  }

  void _dropDisc() {
    final d = _disc;
    _disc = null;
    d?.dispose();
  }

  String? _spotLine(DiscoverySpot s) {
    final key = s.cityKey;
    if (key == null) return null;
    final catalog = TripCityCatalog.to..warmFromDisk();
    if (_cityNames == null || !identical(_cityNamesKey, catalog.dataKey)) {
      _cityNamesKey = catalog.dataKey;
      _cityNames = {for (final c in catalog.search('')) c.cityKey: c.name};
    }
    final name = _cityNames?[key];
    return name == null || name.isEmpty ? null : name;
  }

  void _openSpotDetails(DiscoverySpot s) {
    final key = s.cityKey;
    TripSpotDetailSheet.show(
      context,
      spot: TripSpotModel.fromJson({
        'id': s.id,
        'name': s.name,
        'latitude': s.lat,
        'longitude': s.lon,
        'category': s.category,
        'rank': s.rank,
        'imageUrl': s.thumbUrl,
      }),
      selected: false,
      locked: false,
      cityKey: key,
      version: key == null ? null : TripSpotsCache.versionOf(key) ?? '',
      partial: true,
      showAction: false,
      revalidate: true,
    );
  }

  void _animateNearestCircle(double targetKm, LatLng center) {
    final begin = _nearestCircleAnim?.value ?? _radius;
    _nearestCircleCenter = center;
    _nearestCircleAnim = Tween<double>(begin: begin, end: targetKm).animate(CurvedAnimation(parent: _nearestCircleController, curve: Curves.easeOut));
    _nearestCircleController
      ..reset()
      ..forward();
  }

  void _updateNearestFocus() {
    final stays = _guest.nearestStays;
    final idx = _guest.nearestFocusIndex.value;
    if (idx < 0 || idx >= stays.length) return;
    final focused = stays[idx];
    final target = LatLng(focused.latitude, focused.longitude);
    _animateNearestCircle(AppConstants.nearestFocusRadiusKm, target);
    _animateTo(target, _zoomForRadius(AppConstants.nearestFocusRadiusKm, target.latitude));
    _buildMarkers(animate: false);
  }

  void _openNearestConfirm() {
    final center = _searchCenter;
    NearestConfirmSheet.show(
      context,
      itemLabel: 'stays',
      palette: _forestPalette,
      onConfirm: () => _guest.loadNearest(center.latitude, center.longitude),
    );
  }

  Future<void> _initNativeCircle() async {
    final ctrl = _mapController;
    if (ctrl == null || !mounted) return;
    _precomputeCircleCache();
    await ctrl.addGeoJsonSource('radius-source', _circleCache[_radius]!);
    // Non-interactive: an interactive feature under a tap swallows onMapClick (spot dot taps, tap-to-close).
    await ctrl.addFillLayer('radius-source', 'radius-fill', FillLayerProperties(fillColor: _forestHex, fillOpacity: 0.06), enableInteraction: false);
    await ctrl.addLineLayer('radius-source', 'radius-glow', LineLayerProperties(lineColor: _forestHex, lineWidth: 6.0, lineOpacity: 0.15, lineBlur: 3.0),
        enableInteraction: false);
    await ctrl.addLineLayer('radius-source', 'radius-border', LineLayerProperties(lineColor: _forestHex, lineWidth: 1.8, lineOpacity: 0.65),
        enableInteraction: false);
  }

  void _updateNativeRadiusCircle() {
    final ctrl = _mapController;
    if (ctrl == null) return;
    ctrl.setGeoJsonSource('radius-source', _circleCache[_radius] ?? _buildCircleGeojson(_searchCenter, _radius));
  }

  Future<void> _initNativeUserDot() async {
    final ctrl = _mapController;
    final loc = _locationCtrl.userLocation.value;
    if (ctrl == null || loc == null || !mounted) return;
    _nativeUserDot = await ctrl.addCircle(
      CircleOptions(
      geometry: loc,
      circleRadius: 8.0,
        circleColor: SetupKit.userDotHex,
      circleOpacity: 1.0,
        circleStrokeColor: TripKit.hexOf(DesignColors.surface),
      circleStrokeWidth: 2.5,
      ),
    );
  }

  void _updateNativeUserDot() {
    final ctrl = _mapController;
    final dot = _nativeUserDot;
    final loc = _locationCtrl.userLocation.value;
    if (ctrl == null || dot == null || loc == null) return;
    ctrl.updateCircle(dot, CircleOptions(geometry: loc));
  }

  double _zoomForRadius(double radiusKm, double lat) => StayMapRules.zoomForRadius(radiusKm, lat, _screenSize.width);

  void _animateTo(LatLng target, double zoom) {
    if (!_mapReady || _mapController == null || !mounted) return;
    _mapController!.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
  }

  void _onStyleLoaded() async {
    if (_styleLoaded) return;
    _styleLoaded = true;
    if (!mounted) return;
    await _initNativeCircle();
    await _initNativeUserDot();
    if (!mounted) return;
    _mapReady = true;
    setState(() {});
    _buildMarkers(animate: false);
    if (_guest.nearestActive.value) {
      _updateNearestFocus();
    } else {
      _fitToRadius();
    }
    _syncDiscArea();
    await _attachDisc();
  }

  void _onCameraIdle() {
    _cameraIdleDebounce?.cancel();
    _cameraIdleDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _isCameraMoving = false;
      if (StayMapRules.shouldRebuildMarkers(markersDirty: _markersDirty, lastBuildZoom: _lastClusterZoom, idleZoom: _currentZoom)) {
        _buildMarkers(animate: false);
      }
      if (!_pinsVisible) setState(() => _pinsVisible = true);
    });
  }

  void _loadNearby({bool keepNearest = false}) {
    if (!keepNearest && _guest.nearestActive.value) _guest.nearestActive.value = false;
    _loader.reloadPending = true;
    _loadNearbyDebounceTimer?.cancel();
    _loadNearbyDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      await _loader.run();
    });
  }

  void _onLoadStart() {
    _revealTimer?.cancel();
    _radarController.repeat();
    if (_guest.nearbyStays.isEmpty) {
      final userMarker = _buildUserMarkerData();
      _markerData = userMarker != null ? [userMarker] : [];
      _revealedCount = _markerData.length;
    }
    setState(() {});
  }

  void _onLoadSettled(NearbySettled result) {
    _radarController.stop();
    _radarController.reset();
    setState(() {});
    if (result.rebuildMarkers) _buildMarkers();
    if (result.playSound) _playTing();
  }

  Future<void> _playTing() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/tone.mp3'));
    } catch (_) {}
  }

  _MapMarkerData? _buildUserMarkerData() {
    final loc = _locationCtrl.userLocation.value;
    if (loc == null) return null;
    return _MapMarkerData(
      position: loc,
      width: DS.s(120),
      height: DS.s(120),
      isUser: true,
      widget: AnimatedBuilder(
        animation: _radarController,
        builder: (context2, child2) => CustomPaint(
          painter: _RadarPainter(progress: _radarController.value, color: DesignColors.primaryLight),
        ),
      ),
    );
  }

  void _buildMarkers({bool animate = true}) {
    _lastClusterZoom = _currentZoom;
    _markersDirty = false;
    final data = <_MapMarkerData>[];

    final userMarker = _buildUserMarkerData();
    if (userMarker != null) data.add(userMarker);

    final clusters = _computeClusters(_guest.nearbyStays.toList());

    for (final cluster in clusters) {
      final count = cluster.stays.length;
      final rep = cluster.representative;

      if (count == 1) {
        final priceText = rep.minPricePerNight != null ? _pinPrice(rep.minPricePerNight!) : 'Stay';
        data.add(
          _MapMarkerData(
          position: cluster.center,
          width: _chipWidth(priceText),
          height: DS.s(34),
          widget: GestureDetector(
            onTap: () => _showDetail(rep.id),
            child: _AnimatedPin(
              child: Container(
                decoration: BoxDecoration(
                    color: DesignColors.surface,
                  borderRadius: DS.circular(17),
                    border: Border.all(color: _forest.accentDark, width: DS.s(2)),
                    boxShadow: DS.shadows(ShadowTokens.elev2),
                ),
                child: Center(
                  child: Text(
                    priceText,
                      style: TextStyle(
                        fontFamily: TypeTokens.family,
                        fontSize: DS.f(12),
                        fontWeight: FontWeight.w700,
                        color: _forest.accentDark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        data.add(
          _MapMarkerData(
          position: cluster.center,
          width: DS.s(48),
          height: DS.s(48),
          widget: GestureDetector(
            onTap: () => _zoomToCluster(cluster),
            child: _AnimatedPin(
              child: Container(
                  decoration: BoxDecoration(gradient: _forest.gradient, shape: BoxShape.circle, boxShadow: DS.shadows(ShadowTokens.elev3)),
                child: Center(
                  child: Text(
                    '$count',
                      style: TextStyle(fontFamily: TypeTokens.family, fontSize: DS.f(14), fontWeight: FontWeight.w700, color: DesignColors.onPrimary),
                  ),
                ),
              ),
            ),
          ),
          ),
        );
      }
    }

    if (_guest.nearestActive.value) {
      final nearest = _guest.nearestStays;
      final idx = _guest.nearestFocusIndex.value;
      if (idx >= 0 && idx < nearest.length) {
        final focused = nearest[idx];
        final priceText = focused.minPricePerNight != null ? _pinPrice(focused.minPricePerNight!) : 'Stay';
        data.add(
          _MapMarkerData(
          position: LatLng(focused.latitude, focused.longitude),
          width: _chipWidth(priceText) + DS.s(10),
          height: DS.s(38),
          widget: GestureDetector(
            onTap: () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': focused.id, 'distanceKm': focused.distanceKm}),
            child: _AnimatedPin(
              child: Container(
                decoration: BoxDecoration(
                    gradient: _forest.gradient,
                  borderRadius: DS.circular(19),
                    border: Border.all(color: DesignColors.surface, width: DS.s(2.5)),
                    boxShadow: DS.shadows(ShadowTokens.elev3),
                ),
                child: Center(
                  child: Text(
                    priceText,
                      style: TextStyle(fontFamily: TypeTokens.family, fontSize: DS.f(12), fontWeight: FontWeight.w700, color: DesignColors.onPrimary),
                  ),
                ),
              ),
            ),
          ),
          ),
        );
      }
    }

    _revealTimer?.cancel();
    _markerData = data;

    if (!animate || data.isEmpty) {
      setState(() => _revealedCount = data.length);
      return;
    }

    final userCount = _locationCtrl.userLocation.value != null ? 1 : 0;
    setState(() => _revealedCount = userCount);

    if (data.length <= userCount) return;

    int i = userCount;
    _revealTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      i++;
      setState(() => _revealedCount = i);
      if (i >= data.length) timer.cancel();
    });
  }

  void _zoomToCluster(_Cluster cluster) {
    double minPx = double.infinity, maxPx = double.negativeInfinity;
    double minPy = double.infinity, maxPy = double.negativeInfinity;
    for (final l in cluster.stays) {
      final sinLat = sin(l.latitude * pi / 180);
      final py = 0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi);
      final px = (l.longitude + 180) / 360;
      if (px < minPx) minPx = px;
      if (px > maxPx) maxPx = px;
      if (py < minPy) minPy = py;
      if (py > maxPy) maxPy = py;
    }
    final span = max(maxPx - minPx, maxPy - minPy);
    final targetZoom = span < 1e-10 ? (_currentZoom + 2.5).clamp(10.0, 18.0) : (log(144.0 / (span * 512.0)) / log(2.0)).clamp(10.0, 18.0);
    _animateTo(cluster.center, targetZoom);
  }

  List<_Cluster> _computeClusters(List<StayNearbyModel> stays) => MapClustering.cluster<StayNearbyModel>(
        stays,
        lat: (s) => s.latitude,
        lon: (s) => s.longitude,
        zoom: _currentZoom,
        radiusPx: AppConstants.clusterCellPx,
        maxClusters: AppConstants.maxMapMarkers,
      ).map(_Cluster.new).toList();

  static List<LatLng> _circlePolygonPoints(LatLng center, double radiusKm) {
    const steps = 64;
    const earthRadius = 6378137.0;
    final latRad = center.latitude * pi / 180;
    final points = <LatLng>[];
    for (int i = 0; i <= steps; i++) {
      final angle = 2 * pi * i / steps;
      final dLat = (radiusKm * 1000 * cos(angle)) / earthRadius * (180 / pi);
      final dLng = (radiusKm * 1000 * sin(angle)) / (earthRadius * cos(latRad)) * (180 / pi);
      points.add(LatLng(center.latitude + dLat, center.longitude + dLng));
    }
    return points;
  }

  Map<String, dynamic> _buildCircleGeojson(LatLng center, double radiusKm) {
    final pts = _circlePolygonPoints(center, radiusKm);
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              pts.map((p) => [p.longitude, p.latitude]).toList(),
            ],
          },
          'properties': <String, dynamic>{},
        },
      ],
    };
  }

  void _precomputeCircleCache() {
    _circleCache.clear();
    final center = _searchCenter;
    for (final r in AppConstants.radiusOptions) {
      _circleCache[r] = _buildCircleGeojson(center, r);
    }
  }

  double _radiusPixelRadius(Size screenSize) {
    final cam = _cameraCenter ?? _searchCenter;
    final edge = _circlePolygonPoints(_searchCenter, _radius)[0];
    final centerPx = _projectToScreen(_searchCenter, cam, _currentZoom, screenSize);
    final edgePx = _projectToScreen(edge, cam, _currentZoom, screenSize);
    return (centerPx - edgePx).distance;
  }

  static Offset _radiusTopAnchor(Offset center, double radiusPx, Size screenSize) {
    final topMargin = DS.s(150);
    final insetRadius = radiusPx * 0.65;
    final maxUpward = (center.dy - topMargin).clamp(0.0, insetRadius);
    return Offset(center.dx, center.dy - maxUpward);
  }

  static Offset _projectToScreen(LatLng ll, LatLng center, double zoom, Size screenSize) {
    const tileSize = 512.0;
    final scale = tileSize * pow(2.0, zoom);
    double wx(double lng) => (lng + 180) / 360;
    double wy(double lat) {
      final s = sin(lat * pi / 180);
      return (1 - log((1 + s) / (1 - s)) / (2 * pi)) / 2;
    }

    final dx = (wx(ll.longitude) - wx(center.longitude)) * scale;
    final dy = (wy(ll.latitude) - wy(center.latitude)) * scale;
    return Offset(screenSize.width / 2 + dx, screenSize.height / 2 + dy);
  }

  double _chipWidth(String text) => DS.s((text.length * 9.0 + 26).clamp(52.0, 90.0));

  String _pinPrice(int price) => Money.short(price);

  void _showDetail(String id) {
    final stay = _guest.nearbyStays.firstWhereOrNull((l) => l.id == id);
    if (stay == null) return;
    _showStaySheet((_) => StayBottomSheet(stay: stay));
  }

  Future<void> _showStaySheet(WidgetBuilder builder) async {
    _disc?.clearSelection().ignore();
    _sheetOpen = true;
    try {
      await SheetFrame.show(context, builder: builder);
    } finally {
      _sheetOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          _screenSize = constraints.biggest;
          final lift = BarMetrics.bodyBottomOf(context) - BarMetrics.bodyGap;
          return Stack(
            children: [
              if (_mapActive)
                RepaintBoundary(
                  child: MapLibreMap(
                    styleString: "assets/map_style.json",
                    initialCameraPosition: CameraPosition(target: _searchCenter, zoom: 13.0),
                    minMaxZoomPreference: const MinMaxZoomPreference(8, 18),
                    compassEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    myLocationEnabled: false,
                    dragEnabled: false,
                    trackCameraPosition: true,
                    annotationConsumeTapEvents: const [AnnotationType.symbol],
                    onMapClick: (point, _) => _disc?.onMapTap(point.x, point.y),
                    attributionButtonMargins: const Point(-200.0, 0.0),
                    onMapCreated: (MapLibreMapController ctrl) {
                      _mapController = ctrl;
                    },
                    onStyleLoadedCallback: _onStyleLoaded,
                    onCameraMove: (CameraPosition pos) {
                      _currentZoom = pos.zoom;
                      _cameraCenter = pos.target;
                      _isCameraMoving = true;
                      _cameraIdleDebounce?.cancel();
                      if (mounted && _pinsVisible) setState(() => _pinsVisible = false);
                    },
                    onCameraIdle: _onCameraIdle,
                  ),
                ),
              Obx(() => !_mapActive || !_mapReady || _locationCtrl.userLocation.value == null ? _buildMapSkeleton() : const SizedBox.shrink()),
              if (_mapReady)
                IgnorePointer(
                  ignoring: !_pinsVisible,
                  child: AnimatedOpacity(
                    opacity: _pinsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 100),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ..._markerData.take(_revealedCount).map((d) {
                          final sp = _projectToScreen(d.position, _cameraCenter ?? _searchCenter, _currentZoom, constraints.biggest);
                          return Positioned(left: sp.dx - d.width / 2, top: sp.dy - d.height / 2, width: d.width, height: d.height, child: d.widget);
                        }),
                        if (_loader.loadFailed && !_loader.loading && !_loader.reloadPending)
                          Obx(() {
                            if (_guest.nearestActive.value) return const SizedBox.shrink();
                            final radiusPx = _radiusPixelRadius(constraints.biggest);
                            final sp = _projectToScreen(_searchCenter, _cameraCenter ?? _searchCenter, _currentZoom, constraints.biggest);
                            final anchor = _radiusTopAnchor(sp, radiusPx, constraints.biggest);
                            return Positioned(
                              left: anchor.dx,
                              top: anchor.dy,
                              child: FractionalTranslation(
                                translation: const Offset(-0.5, -1.0),
                                child: GestureDetector(
                                  onTap: _loadNearby,
                                  child: EmptyRadiusHint(
                                    label: 'Could not load stays. Tap to retry.',
                                    circleRadiusPx: radiusPx,
                                    palette: _forestPalette,
                                  ),
                                ),
                              ),
                            );
                          })
                        else if (_guest.nearbyStays.isEmpty && !_loader.loading && !_loader.reloadPending && _loader.hasLoadedOnce)
                          Obx(() {
                            if (_guest.nearestActive.value) return const SizedBox.shrink();
                            final radiusPx = _radiusPixelRadius(constraints.biggest);
                            final sp = _projectToScreen(_searchCenter, _cameraCenter ?? _searchCenter, _currentZoom, constraints.biggest);
                            final anchor = _radiusTopAnchor(sp, radiusPx, constraints.biggest);
                            return Positioned(
                              left: anchor.dx,
                              top: anchor.dy,
                              child: FractionalTranslation(
                                translation: const Offset(-0.5, -1.0),
                                child: EmptyRadiusHint(
                                  label: 'No stays in this radius — try Nearest',
                                  circleRadiusPx: radiusPx,
                                  palette: _forestPalette,
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Column(
                  key: _topKey,
                  children: [
                    TemplateEntrance(
                      animation: templateInterval(_chromeController, 0, 3),
                      animationController: _chromeController,
                      offset: DS.s(-30),
                      child: Container(
                        decoration: BoxDecoration(gradient: _forest.gradient, borderRadius: DS.br(CardRadius.header), boxShadow: DS.shadows(ShadowTokens.elev3)),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: DS.insets(l: 20, t: 12, r: 20, b: 16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _buildBackButton(),
                                    Gap.h(10),
                                    Expanded(child: PlaceSearchBar(controller: _centre, compact: true)),
                                  ],
                                ),
                                Gap.v(10),
                                _buildRadiusChips(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: DS.gv(12), left: DS.s(20), right: DS.s(20)),
                      child: StayMapTopControls(
                        layer: _disc,
                        entrance: CurvedAnimation(parent: _chromeController, curve: Curves.fastOutSlowIn),
                        map: () => _mapController,
                        onLocate: _onLocateTap,
                      ),
                    ),
                  ],
                ),
              ),
              if (_disc != null)
                DiscoveryOverlay(
                  layer: _disc!,
                  placement: DiscoveryPlacement.bottom,
                  map: () => _mapController,
                  palette: ListingPalette.forest,
                  side: StayMapTopControls.side,
                ),
              Obx(() {
                if (!_guest.nearestActive.value) {
                  return Positioned(
                    bottom: lift + DS.s(24),
                    left: DS.s(20),
                    right: DS.s(20),
                    child: TemplateEntrance(
                      animation: templateInterval(_chromeController, 2, 3),
                      animationController: _chromeController,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_guest.nearbyStays.isNotEmpty) _buildViewListButton() else const SizedBox.shrink(),
                          PressScale(child: StayFloatingPill(label: 'Find Nearest', iconAsset: TravelIcon.route, gradient: _forest.gradient, shadowColor: ListingPalette.forest.g1, onTap: _openNearestConfirm)),
                      ],
                    ),
                    ),
                  );
                }
                return Positioned(bottom: lift + DS.s(86), left: DS.s(20), right: DS.s(20), child: _buildNearestPreviewCard());
              }),
              Obx(() {
                if (!_guest.nearestActive.value) return const SizedBox.shrink();
                final total = _guest.nearestStays.length;
                final idx = _guest.nearestFocusIndex.value;
                return Positioned(
                  bottom: lift + DS.s(20),
                  left: DS.s(20),
                  right: DS.s(20),
                  child: NearestControlBar(
                    current: idx,
                    total: total,
                    onPrev: () {
                      if (idx > 0) _guest.nearestFocusIndex.value = idx - 1;
                    },
                    onNext: () {
                      if (idx < total - 1) _guest.nearestFocusIndex.value = idx + 1;
                    },
                    onCancel: () => _guest.nearestActive.value = false,
                    palette: _forestPalette,
                  ),
                );
              }),
              Positioned(
                bottom: lift + DS.s(4),
                left: DS.s(8),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontFamily: TypeTokens.family, fontSize: DS.f(11), color: DesignColors.textGrey),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackButton() {
    return PressScale(
      child: GestureDetector(
      onTap: () {
        if (_guest.isLoadingNearest.value) return;
        Navigator.of(context).maybePop();
      },
      child: Container(
        width: DS.s(KitMetrics.touch),
        height: DS.s(KitMetrics.touch),
          decoration: BoxDecoration(color: DesignColors.surface, shape: BoxShape.circle, boxShadow: DS.shadows(ShadowTokens.elev2)),
          child: Icon(Icons.chevron_left_rounded, color: _forest.accentDark, size: DS.s(26)),
        ),
      ),
    );
  }

  static const double _chipHeight = 54;

  Widget _buildRadiusChips() {
    final radii = AppConstants.radiusOptions;
    return ToneSegmentControl(
      key: const ValueKey('stay-radius-chips'),
      labels: [for (final r in radii) '${r.toInt()} km'],
      semanticLabels: [for (final r in radii) '${r.toInt()} kilometres'],
      selected: radii.indexOf(_radius),
      tone: ListingTone.forest,
      cellHeight: _chipHeight,
      onTap: (i) {
        setState(() => _radius = radii[i]);
        _loadNearby();
        if (_mapReady) _fitToRadius();
      },
    );
  }

  void _onLocateTap() {
    _locationCtrl.resetBrowsing();
    if (_hasPin) PlaceSearchBar.clear(_centre);
    _precomputeCircleCache();
    _loadNearby();
    if (_mapReady) _fitToRadius();
  }

  Widget _buildNearestPreviewCard() {
    final stays = _guest.nearestStays;
    final idx = _guest.nearestFocusIndex.value;
    if (idx < 0 || idx >= stays.length) return const SizedBox.shrink();
    return _nearbyRow(stays[idx], elevated: true);
  }

  Widget _nearbyRow(StayNearbyModel s, {bool elevated = false}) {
    return ListRow(
      thumbnailUrl: s.thumbnailUrl,
      tag: 'FOR STAY',
      title: s.title,
      subtitle: [if (s.stayTypeName != null && s.stayTypeName!.isNotEmpty) s.stayTypeName!, '${s.distanceKm.toStringAsFixed(1)} km'].join(' · '),
      priceCaption: 'FROM',
      priceValue: s.minPricePerNight != null ? BrowseItem.inr(s.minPricePerNight!) : 'On request',
      priceUnit: s.minPricePerNight != null ? '/night' : '',
      iconAsset: TravelIcon.stay,
      isFeatured: s.isFeatured,
      margin: elevated ? EdgeInsets.zero : EdgeInsets.symmetric(horizontal: DS.s(KitMetrics.gutter), vertical: DS.gv(6)),
      onTap: () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': s.id, 'distanceKm': s.distanceKm}),
    );
  }

  Widget _buildViewListButton() {
    final count = _guest.nearbyStays.length;
    return PressScale(
      child: GestureDetector(
      onTap: _showListSheet,
      child: Container(
        constraints: BoxConstraints(minHeight: DS.s(KitMetrics.touch)),
        padding: DS.sym(h: 14),
        decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: DS.circular(24),
            border: Border.all(color: _forest.accentDark, width: 1.5),
            boxShadow: DS.shadows(ShadowTokens.elev2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
              Icon(Icons.format_list_bulleted_rounded, color: _forest.accentDark, size: DS.s(18)),
            Gap.h(6),
              Text(
                'View List',
                style: TextStyle(fontFamily: TypeTokens.family, fontSize: DS.f(13), fontWeight: FontWeight.w700, color: _forest.accentDark),
              ),
            Gap.h(6),
            Container(
              padding: DS.sym(h: 6, v: 2),
                decoration: BoxDecoration(gradient: _forest.gradient, borderRadius: DS.circular(10)),
                child: Text(
                  '$count',
                  style: TypeTokens.style(11, FontWeight.w800, color: DesignColors.onPrimary),
                ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _showListSheet() {
    _showStaySheet(
      (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (sheetContext, scrollController) {
          return _ListSheetBody(guest: _guest, scrollController: scrollController, sheetContext: sheetContext, rowBuilder: _nearbyRow);
        },
                  ),
    );
  }

  Widget _buildMapSkeleton() {
    return TemplatePlaceholder(height: _screenSize.height, radius: 0);
  }
}

class StayMapTopControls extends StatelessWidget {
  final DiscoveryLayerApi? layer;
  final Animation<double> entrance;
  final MapLibreMapController? Function() map;
  final VoidCallback onLocate;

  static const double side = 20;

  const StayMapTopControls({
    super.key,
    required this.layer,
    required this.map,
    required this.onLocate,
    this.entrance = kAlwaysCompleteAnimation,
  });

  Widget _row({bool showEye = false, bool eyeOn = true, bool loading = false, bool eyeEnabled = true, ValueChanged<bool>? onEye}) => ScaleTransition(
        scale: entrance,
        child: TripMapControls.row(
          showEye: showEye,
          eyeOn: eyeOn,
          loading: loading,
          eyeEnabled: eyeEnabled,
          onEye: onEye,
          map: map,
          onLocate: onLocate,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = layer;
    if (l == null) return _row();
    return Obx(() {
      final attached = l.attached.value;
      final loading = !attached || l.dataState.value == DiscoveryDataState.loading;
      final here = l.hasSpotsHere.value;
      return _row(
        showEye: true,
        eyeOn: l.eyeOn.value,
        loading: loading,
        eyeEnabled: attached && here,
        onEye: (on) => l.setEye(on),
      );
    });
  }
}

class _ListSheetBody extends StatefulWidget {
  final StayGuestController guest;
  final ScrollController scrollController;
  final BuildContext sheetContext;
  final Widget Function(StayNearbyModel) rowBuilder;

  const _ListSheetBody({required this.guest, required this.scrollController, required this.sheetContext, required this.rowBuilder});

  @override
  State<_ListSheetBody> createState() => _ListSheetBodyState();
}

class _ListSheetBodyState extends State<_ListSheetBody> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: DesignColors.sheet, borderRadius: DS.br(CardRadius.sheet), boxShadow: DS.shadows(DesignShadows.top)),
                  child: Column(
                    children: [
                      Container(
            width: DS.s(36),
                        height: DS.s(4),
            margin: EdgeInsets.only(top: DS.s(10), bottom: DS.s(14)),
            decoration: BoxDecoration(color: DesignColors.tint(DesignColors.textGrey, Alpha.half), borderRadius: DS.circular(2)),
                      ),
                      Padding(
            padding: EdgeInsets.fromLTRB(DS.s(KitMetrics.gutter), 0, DS.s(KitMetrics.gutter), DS.s(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Obx(() {
                  final count = widget.guest.nearbyStays.length;
                  return Text(
                    '$count Stay${count == 1 ? '' : 's'} Nearby',
                    style: TypeTokens.style(18, FontWeight.w700, color: DesignColors.textStrong, letterSpacing: 0.27),
                  );
                            }),
                SheetCloseButton(onTap: () => Navigator.pop(widget.sheetContext)),
                    ],
                  ),
                ),
          const Divider(height: 1, color: DesignColors.dividerSoft),
                Gap.v(8),
                Expanded(
                  child: Obx(() {
              final items = widget.guest.nearbyStays.toList();
                    return ListView.builder(
                controller: widget.scrollController,
                physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(bottom: DS.gv(16) + AppInsets.bottomViewPadding(context)),
                      itemCount: items.length,
                itemBuilder: (_, i) {
                  final row = widget.rowBuilder(items[i]);
                  return i >= 10 ? row : KitCardEntrance(key: ValueKey(items[i].id), index: i, child: row);
                },
                    );
                  }),
                ),
              ],
            ),
          );
  }
}

class _MapMarkerData {
  final LatLng position;
  final Widget widget;
  final double width;
  final double height;
  final bool isUser;

  _MapMarkerData({required this.position, required this.widget, required this.width, required this.height, this.isUser = false});
}

class _Cluster {
  final MapCluster<StayNearbyModel> group;
  _Cluster(this.group);

  List<StayNearbyModel> get stays => group.items;
  LatLng get center => LatLng(group.latitude, group.longitude);
  StayNearbyModel get representative => group.first;
}

class _AnimatedPin extends StatefulWidget {
  final Widget child;
  const _AnimatedPin({required this.child});
  @override
  State<_AnimatedPin> createState() => _AnimatedPinState();
}

class _AnimatedPinState extends State<_AnimatedPin> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.fastOutSlowIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale, child: widget.child);
}

class _RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RadarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = DS.s(52.0);

    for (int i = 0; i < 3; i++) {
      final p = (progress + i / 3.0) % 1.0;
      final radius = maxRadius * p;
      final opacity = 1.0 - p;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity * 0.12)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.progress != progress;
}
