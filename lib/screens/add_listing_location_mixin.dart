import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../design/design.dart';
import '../design/extra/ext_stay_owner.dart';
import '../config/app_constants.dart';
import '../controllers/location_controller.dart';
import '../models/city_model.dart';
import '../models/location_context.dart';
import '../repositories/district_boundary_repository.dart';
import '../utils/app_toast.dart';
import '../utils/geo_point_in_polygon.dart';
import '../utils/input_formatters.dart';

/// Per-flow styling for the shared location/address subsystem, shared by
/// Stay and Taxi setup — everything that differs between their otherwise
/// identical map/pin/district/address mechanism, taken as one bundle instead
/// of scattering individual color/text parameters across every call site.
class LocationStepStyle {
  final String circleColorHex;
  final String userDotColorHex;
  final Color accentColor;
  final Color addressSpinnerColor;
  final IconData addressPrefixIcon;
  final String pinStepTitle;
  final String pinHintNoun;
  final ListingTone? tone;

  const LocationStepStyle({
    required this.circleColorHex,
    required this.userDotColorHex,
    required this.accentColor,
    required this.addressSpinnerColor,
    required this.addressPrefixIcon,
    required this.pinStepTitle,
    required this.pinHintNoun,
    this.tone,
  });
}

/// Shared map/GPS/district/address subsystem, shared by Stay and Taxi setup's
/// Location + Address steps — identical mechanism in both flows (pin
/// placement, the live-position safety check, resume-only pin
/// unstick, district/address reverse-geocode). Type, price, photos, step
/// navigation, and the save payload assembly stay in each host screen —
/// this mixin owns only what's inside
/// the map/location/address steps themselves.
mixin AddListingLocationMixin<T extends StatefulWidget> on State<T> {
  MapLibreMapController? _mapController;
  Symbol? _nativePin;
  double _currentZoom = 14.0;
  final double _minZoom = 10.0;
  final _addressCtrl = TextEditingController();
  final _addressFocusNode = FocusNode();

  DistrictModel? _resolvedDistrict;
  CityModel? _resolvedCity;
  bool _isResolvingDistrict = false;
  bool _showAddressResolveOverlay = false;
  bool _pinManuallyPlaced = false;
  int _districtResolveGeneration = 0;
  Worker? _userLocationWorker;
  Worker? _resumeRefreshWorker;
  LatLng? _selectedLocation;
  LatLng? _prefilledPin;
  LatLng? _userLocation;
  Circle? _userDot;
  final _locationCtrl = Get.find<LocationController>();
  bool _mapReady = false;
  bool _cameraInitialized = false;
  late LocationStepStyle _style;
  VoidCallback? _onOnboardingClosed;
  bool _lastResolveOnboardingClosed = false;
  bool Function(DistrictModel district)? _onboardingGrandfathered;

  final _boundaryRepo = DistrictBoundaryRepository();
  Map<String, dynamic>? _districtBoundaryGeoJson;
  String? _boundaryDistrictId;
  bool _boundarySourceAdded = false;
  Worker? _districtWorker;
  LatLngBounds? _districtCameraBounds;
  bool _isFetchingBoundary = false;

  // ── Public surface for the host screen ──────────────────────────────────

  LatLng? get userLocation => _userLocation;
  LatLng? get selectedLocation => _selectedLocation;
  LatLng? get pinnedOrLiveLocation => _selectedLocation ?? _userLocation;
  String? get selectedDistrictId => _resolvedDistrict?.id;
  String? get resolvedCityId => _resolvedCity?.id;
  String? get resolvedDistrictName => _resolvedDistrict?.name;
  String? get resolvedCityName => _resolvedCity?.name;
  bool get isResolvingDistrict => _isResolvingDistrict;
  bool get lastResolveOnboardingClosed => _lastResolveOnboardingClosed;
  bool get showAddressResolveOverlay => _showAddressResolveOverlay;
  String get trimmedAddress => _addressCtrl.text.trim();
  bool get hasAddressText => _addressCtrl.text.trim().isNotEmpty;
  bool get hasLocationOrAddressChanges =>
      _selectedLocation != null || _addressCtrl.text.isNotEmpty;

  void focusAddressField() => _addressFocusNode.requestFocus();

  // Edit flows: call after initLocationTracking to restore a saved pin and address.
  void prefillLocation(LatLng pin, String? address) {
    _pinManuallyPlaced = true;
    _prefilledPin = pin;
    _selectedLocation = pin;
    if (address != null && address.isNotEmpty) _addressCtrl.text = address;
  }

  void snapLocationToUserIfUnset() {
    if (_selectedLocation == null) setState(() => _selectedLocation = _userLocation);
  }

  // Sole resolve trigger left in this subsystem — always fresh, immediately,
  // for wherever the pin currently is.
  void resolveAddressIfNeeded() {
    final loc = _selectedLocation;
    if (loc != null) _resolveDistrictForPin(loc);
  }

  void initLocationTracking({
    required LocationStepStyle style,
    VoidCallback? onLocationStale,
    VoidCallback? onOnboardingClosed,
    bool Function(DistrictModel district)? onboardingGrandfathered,
  }) {
    _style = style;
    _onOnboardingClosed = onOnboardingClosed;
    _onboardingGrandfathered = onboardingGrandfathered;
    _addressCtrl.addListener(_onAddressChanged);
    _userLocation = _locationCtrl.userLocation.value;
    _selectedLocation = _locationCtrl.userLocation.value;
    _userLocationWorker = ever<LatLng?>(_locationCtrl.userLocation, _onUserLocationChanged);
    if (_userLocation != null) _onUserLocationChanged(_userLocation);
    // Only a genuine backgrounded-then-resumed refresh (not a cold-start GPS
    // refinement or a foreground GPS on/off toggle) is allowed to override a
    // manually-placed pin — see _onUserLocationChanged's doc comment.
    _resumeRefreshWorker = ever<int>(_locationCtrl.resumeLocationRefreshedTrigger, (_) {
      if (!mounted) return;
      if (_prefilledPin == null) _pinManuallyPlaced = false;
      final newLoc = _locationCtrl.userLocation.value;
      _onUserLocationChanged(newLoc);
      if (newLoc != null && _prefilledPin == null) _resolveDistrictForPin(newLoc);
      onLocationStale?.call();
    });
    // Covers district resolution completing (or changing) after the Location
    // step is already open — the initial fetch itself is triggered from
    // _onStyleLoaded, once the map exists to render into.
    _districtWorker = ever<DistrictModel?>(_locationCtrl.selectedDistrict, (_) {
      _fetchAndRenderBoundaryForCurrentDistrict();
    });
  }

  void disposeLocationTracking() {
    _userLocationWorker?.dispose();
    _resumeRefreshWorker?.dispose();
    _districtWorker?.dispose();
    _addressCtrl.removeListener(_onAddressChanged);
    _addressCtrl.dispose();
    _addressFocusNode.dispose();
  }

  // Host calls this with false on every Location-step exit (map widget gets
  // disposed by AnimatedSwitcher but these fields would otherwise stay stale).
  // No active: true call site exists — re-entering step 1 always rebuilds a
  // fresh MapLibreMap, which repopulates every field below via its own
  // onMapCreated/onStyleLoadedCallback regardless.
  void setLocationStepActive(bool active) {
    if (active) return;
    _mapController = null;
    _mapReady = false;
    _cameraInitialized = false;
    _nativePin = null;
    _boundarySourceAdded = false;
    _userDot = null;
  }

  // ── Internal mechanism (verbatim from the pre-extraction Add screens) ───

  // Keeps _userLocation tied to the CURRENT GPS fix always (read live by the
  // pin-distance check) — but the visual pin/camera only follow it until
  // the user manually places a pin. After that, the pin stays exactly where
  // placed (surviving step navigation and app resume) — only a fresh manual
  // tap moves it again; GPS updates keep _userLocation accurate in the
  // background so a later tap validates against where the user really is.
  // Purely local coordinate tracking — no network calls here; district/city/
  // address are resolved once, at the Next-click transition into the Address
  // step (see resolveAddressIfNeeded).
  void _onUserLocationChanged(LatLng? newLoc) {
    if (!mounted || newLoc == null) return;
    _userLocation = newLoc;
    if (_pinManuallyPlaced) return;
    setState(() => _selectedLocation = newLoc);
    _setNativePin(newLoc);
    _updateNativeUserDot(newLoc);
    _animateTo(newLoc, _currentZoom);
  }

  void _onAddressChanged() {
    if (mounted) setState(() {});
  }

  void _animateTo(LatLng target, double zoom) {
    if (!_mapReady || _mapController == null || !mounted) return;
    _mapController!.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
  }

  Future<void> _onStyleLoaded() async {
    _mapReady = true;
    if (!mounted) return;
    final ctrl = _mapController;
    if (ctrl == null) return;
    final pinBytes = await _buildPinImage();
    await ctrl.addImage('location_pin', pinBytes);
    _fetchAndRenderBoundaryForCurrentDistrict();
    _initNativeUserDot();
    if (_selectedLocation != null) await _setNativePin(_selectedLocation!);
    if (_userLocation != null && !_cameraInitialized) {
      _cameraInitialized = true;
      _animateTo(_userLocation!, 14.0);
    }
  }

  static Future<Uint8List> _buildPinImage() async {
    const double w = 40, h = 52, cx = w / 2, cy = 18, r = 16;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h - 2), width: 14, height: 5),
      Paint()
        ..color = UtilTokens.pinShadow.withValues(alpha: UtilTokens.pinShadowAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    final body = Paint()..color = UtilTokens.pinBody;
    final path = Path()
      ..addOval(Rect.fromCircle(center: const Offset(cx, cy), radius: r))
      ..moveTo(cx - 8, cy + r - 4)
      ..quadraticBezierTo(cx - 5, h - 6, cx, h)
      ..quadraticBezierTo(cx + 5, h - 6, cx + 8, cy + r - 4)
      ..close();
    canvas.drawPath(path, body);

    canvas.drawCircle(const Offset(cx, cy), 6.5, Paint()..color = UtilTokens.pinDot);

    final img = await recorder.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
    return bytes.buffer.asUint8List();
  }

  // Fetches (once per district, in-memory cached in the repo itself) and
  // renders the real polygon for whichever district the user is currently
  // in. Called from _onStyleLoaded and again whenever selectedDistrict
  // resolves/changes while the step is already open.
  Future<void> _fetchAndRenderBoundaryForCurrentDistrict() async {
    final district = _locationCtrl.effectiveDistrict;
    if (district == null) return;
    final myDistrictId = district.id;
    // Same district already fetched (e.g. re-entering this step on a fresh
    // MapLibreMap instance after AnimatedSwitcher rebuilt it) — re-render
    // onto the new map without hitting the network again.
    final cachedGeoJson = _districtBoundaryGeoJson;
    if (myDistrictId == _boundaryDistrictId && cachedGeoJson != null) {
      await _renderDistrictBoundary(cachedGeoJson);
      return;
    }
    setState(() => _isFetchingBoundary = true);
    final geojson = await _boundaryRepo.getBoundary(myDistrictId);
    if (!mounted || _locationCtrl.effectiveDistrict?.id != myDistrictId) return;
    setState(() => _isFetchingBoundary = false);
    if (geojson == null) {
      AppToast.info(
          "Couldn't load your district's boundary — you can still pin; we'll double-check before you continue.",
          compact: true);
      return;
    }
    _boundaryDistrictId = myDistrictId;
    _districtBoundaryGeoJson = geojson;
    await _renderDistrictBoundary(geojson);
  }

  Future<void> _renderDistrictBoundary(Map<String, dynamic> geojson) async {
    final ctrl = _mapController;
    if (ctrl == null || !mounted) return;
    if (!_boundarySourceAdded) {
      await ctrl.addGeoJsonSource('district-boundary-source', geojson);
      // enableInteraction: false on all three — otherwise MapLibre routes a tap
      // that lands on this overlay to a feature-tap instead of onMapClick, so
      // taps "inside" the shaded district would never reach the pin-placement
      // handler at all.
      await ctrl.addFillLayer('district-boundary-source', 'district-boundary-fill',
          FillLayerProperties(fillColor: _style.circleColorHex, fillOpacity: 0.06),
          enableInteraction: false);
      await ctrl.addLineLayer('district-boundary-source', 'district-boundary-glow',
          LineLayerProperties(lineColor: _style.circleColorHex, lineWidth: 6.0,
              lineOpacity: 0.15, lineBlur: 3.0),
          enableInteraction: false);
      await ctrl.addLineLayer('district-boundary-source', 'district-boundary-border',
          LineLayerProperties(lineColor: _style.circleColorHex, lineWidth: 1.8,
              lineOpacity: 0.65),
          enableInteraction: false);
      _boundarySourceAdded = true;
    } else {
      await ctrl.setGeoJsonSource('district-boundary-source', geojson);
    }

    // Pad the district's bbox by 20% on every side — enough room to see just
    // past the border for context, not so much that panning still reaches a
    // neighbouring district. The initial fit-to-bounds below can compute a
    // zoom below _minZoom for a large district; onCameraIdle's floor clamp
    // (see the MapLibreMap widget) catches that and snaps back up to 10, so
    // the district is framed nicely but never zoomed out further than that.
    final bounds = geoJsonFeatureCollectionBounds(geojson);
    if (bounds != null && mounted) {
      final south = bounds[0], west = bounds[1], north = bounds[2], east = bounds[3];
      final latPad = (north - south) * 0.2, lngPad = (east - west) * 0.2;
      setState(() {
        _districtCameraBounds = LatLngBounds(
          southwest: LatLng(south - latPad, west - lngPad),
          northeast: LatLng(north + latPad, east + lngPad),
        );
      });
      await ctrl.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east)),
        left: 24, top: 24, right: 24, bottom: 24,
      ));
    }
  }

  Future<void> _initNativeUserDot() async {
    final ctrl = _mapController;
    final loc = _userLocation;
    if (ctrl == null || loc == null || !mounted) return;
    _userDot = await ctrl.addCircle(CircleOptions(
      geometry: loc,
      circleRadius: 8.0,
      circleColor: _style.userDotColorHex,
      circleOpacity: 1.0,
      circleStrokeColor: DesignHex.of(FitnessAppTheme.white),
      circleStrokeWidth: 2.5,
    ));
  }

  void _updateNativeUserDot(LatLng loc) {
    final ctrl = _mapController;
    final dot = _userDot;
    if (ctrl == null || dot == null) return;
    ctrl.updateCircle(dot, CircleOptions(geometry: loc));
  }

  Future<void> _setNativePin(LatLng latLng) async {
    final ctrl = _mapController;
    if (ctrl == null || !mounted) return;
    if (_nativePin != null) {
      await ctrl.updateSymbol(_nativePin!, SymbolOptions(geometry: latLng));
    } else {
      _nativePin = await ctrl.addSymbol(SymbolOptions(
        geometry: latLng,
        iconImage: 'location_pin',
        iconSize: 1.5,
        iconAnchor: 'bottom',
      ));
    }
  }

  bool _isPrefilledPin(LatLng pos) {
    final p = _prefilledPin;
    return p != null && (pos.latitude - p.latitude).abs() <= 1e-6 && (pos.longitude - p.longitude).abs() <= 1e-6;
  }

  // District/city/address resolve for the current pin; a newer call supersedes one still in flight.
  Future<void> _resolveDistrictForPin(LatLng pos) async {
    if (!mounted) return;
    final myGeneration = ++_districtResolveGeneration;
    setState(() {
      _lastResolveOnboardingClosed = false;
      _isResolvingDistrict = true;
      _showAddressResolveOverlay = true;
      _resolvedDistrict = null;
      _resolvedCity = null;
    });
    try {
      final ctx = await _locationCtrl.resolveDistrictAt(pos.latitude, pos.longitude, includeAddress: true);
      if (!mounted || myGeneration != _districtResolveGeneration) return;
      // Double-check against the district the client-side boundary check already
      // validated this pin against — catches the rare case where the simplified
      // polygon accepted a tap that the real, full-fidelity boundary resolves to
      // a different district.
      final expectedDistrictId = _boundaryDistrictId;
      if (expectedDistrictId != null && ctx.district.id != expectedDistrictId) {
        setState(() { _isResolvingDistrict = false; _showAddressResolveOverlay = false; });
        AppToast.error(
            'This spot is actually in ${ctx.district.name} district. Please re-pin inside ${_locationCtrl.effectiveDistrict?.name ?? "your district"}.');
        return;
      }
      if (_onOnboardingClosed != null &&
          ctx.district.businessOnboardingEnabled == false &&
          !(_isPrefilledPin(pos) && (_onboardingGrandfathered?.call(ctx.district) ?? false))) {
        setState(() { _isResolvingDistrict = false; _showAddressResolveOverlay = false; _lastResolveOnboardingClosed = true; });
        _onOnboardingClosed!();
        return;
      }
      setState(() {
        _resolvedDistrict = ctx.district;
        _resolvedCity = ctx.nearestCity;
        _isResolvingDistrict = false;
        _showAddressResolveOverlay = false;
      });
      final displayName = ctx.address;
      final keepSavedAddress = pos.latitude == _prefilledPin?.latitude &&
          pos.longitude == _prefilledPin?.longitude &&
          _addressCtrl.text.trim().isNotEmpty;
      if (!keepSavedAddress && displayName != null && displayName.isNotEmpty) {
        final parts = displayName.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        _addressCtrl.text = parts.take(3).join(', ');
      }
      if (ctx.nearestCity != null) {
        _locationCtrl.loadCitiesForDistrict(ctx.district.id, forceRefresh: true);
      }
    } on DistrictNotFoundException {
      if (!mounted || myGeneration != _districtResolveGeneration) return;
      setState(() { _isResolvingDistrict = false; _showAddressResolveOverlay = false; });
      AppToast.error("This area isn't in a serviceable location yet.");
    } catch (_) {
      if (!mounted || myGeneration != _districtResolveGeneration) return;
      setState(() { _isResolvingDistrict = false; _showAddressResolveOverlay = false; });
      AppToast.error('Could not verify the district for this location. Please try again.');
    }
  }

  // ── Step widgets ─────────────────────────────────────────────────────────

  ListingTone get _tone => _style.tone ?? (_style.pinHintNoun == 'taxi' ? ListingTone.coral : ListingTone.forest);

  bool get _coral => identical(_tone, ListingTone.coral);

  String get _pinTitle {
    final t = _style.pinStepTitle.trim();
    return t.endsWith('*') ? t.substring(0, t.length - 1).trim() : t;
  }

  Widget _card({required String art, required String title, required Widget child}) => FormSectionCard(
        tone: _tone,
        art: art,
        title: title,
        tag: _coral ? null : 'Required',
        requiredMark: _coral,
        artSide: _coral ? FormArtSide.right : FormArtSide.left,
        child: child,
      );

  Widget locationStepWidget() {
    final pinned = _selectedLocation;
    return KeyedSubtree(
      key: const ValueKey(1),
      child: _card(
        art: ListingArt.roundPushpin,
        title: _pinTitle,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          HintLine3D(
            tone: _tone,
            busy: _isFetchingBoundary,
            text: _userLocation != null
                ? (pinned != null
                    ? 'Pinned — tap inside your district to adjust'
                    : 'Tap inside your district to pin your ${_style.pinHintNoun}')
                : 'Waiting for your GPS location...',
          ),
          if (_userLocation == null)
            MapWait3D(tone: _tone, text: 'Getting your location...')
          else
            MapFrame3D(
              onMyLocation: () { if (_userLocation != null) _animateTo(_userLocation!, 15.0); },
              child: MapLibreMap(
                styleString: 'assets/map_style.json',
                initialCameraPosition: CameraPosition(
                  target: _userLocation ?? const LatLng(AppConstants.fallbackLat, AppConstants.fallbackLng),
                  zoom: 14.0,
                ),
                compassEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                myLocationEnabled: false,
                trackCameraPosition: true,
                gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())},
                attributionButtonMargins: const Point(-200.0, 0.0),
                // Panning/zooming is capped to the current district's own padded bounds once its boundary loads.
                cameraTargetBounds: _districtCameraBounds != null
                    ? CameraTargetBounds(_districtCameraBounds!)
                    : CameraTargetBounds.unbounded,
                onMapCreated: (ctrl) {
                  _mapController = ctrl;
                  _nativePin = null;
                  _boundarySourceAdded = false;
                  _userDot = null;
                },
                onStyleLoadedCallback: _onStyleLoaded,
                onCameraMove: (pos) { _currentZoom = pos.zoom; },
                onCameraIdle: () {
                  if (_currentZoom < _minZoom && _mapController != null && mounted) {
                    _mapController!.animateCamera(CameraUpdate.zoomTo(_minZoom));
                  }
                },
                onMapClick: (_, latLng) {
                  final geojson = _districtBoundaryGeoJson;
                  if (geojson != null && !isPointInGeoJsonFeatureCollection(latLng.latitude, latLng.longitude, geojson)) {
                    final name = _locationCtrl.effectiveDistrict?.name;
                    AppToast.warning(name != null ? 'You can only pin within $name district' : 'You can only pin within your current district');
                    return;
                  }
                  _pinManuallyPlaced = true;
                  setState(() => _selectedLocation = latLng);
                  _setNativePin(latLng);
                },
              ),
            ),
          Visibility(
            visible: pinned != null,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: CoordsLine3D(
              tone: _tone,
              text: pinned == null ? '' : '${pinned.latitude.toStringAsFixed(5)}, ${pinned.longitude.toStringAsFixed(5)}',
              credit: '© OpenStreetMap contributors',
            ),
          ),
        ]),
      ),
    );
  }

  Widget _placeField(String label, String art, String? value, {bool first = true}) {
    final detecting = value == null && _isResolvingDistrict;
    return PillPickerField(
      tone: _tone,
      label: label,
      firstLabel: first,
      leadingArt: art,
      value: value ?? (detecting ? 'Detecting…' : '—'),
      trailing: value != null ? GpsDot3D(tone: _tone) : const SizedBox.shrink(),
      onTap: null,
    );
  }

  Widget addressStepWidget() => SingleChildScrollView(
    key: const ValueKey(2),
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _card(
        art: ListingArt.worldMap,
        title: 'District & City',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _placeField('District', ListingArt.roundPushpin, _resolvedDistrict?.name),
          _placeField('City / Area (optional)', ListingArt.worldMap, _resolvedCity?.name, first: false),
        ]),
      ),
      _card(
        art: _coral ? ListingArt.taxi : ListingArt.hotel,
        title: 'Address',
        child: PillField(
          tone: _tone,
          controller: _addressCtrl,
          focusNode: _addressFocusNode,
          inputFormatters: noEmojiInputFormatters,
          hint: 'Street, landmark, nearby place...',
          leadingArt: _coral ? ListingArt.taxi : ListingArt.hotel,
          suffix: _isResolvingDistrict
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _tone.g2))
              : null,
        ),
      ),
    ]),
  );
}
