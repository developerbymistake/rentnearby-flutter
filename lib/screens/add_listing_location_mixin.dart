import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../config/app_colors.dart';
import '../controllers/location_controller.dart';
import '../models/city_model.dart';
import '../models/location_context.dart';
import '../utils/app_toast.dart';
import '../utils/input_formatters.dart';

/// Room/Plot-specific styling for the shared location/address subsystem —
/// everything that differs between Add Room and Add Plot's otherwise
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

  const LocationStepStyle({
    required this.circleColorHex,
    required this.userDotColorHex,
    required this.accentColor,
    required this.addressSpinnerColor,
    required this.addressPrefixIcon,
    required this.pinStepTitle,
    required this.pinHintNoun,
  });
}

/// Shared map/GPS/district/address subsystem for Add Room's and Add Plot's
/// Location + Address steps — identical mechanism in both flows (pin
/// placement, the 500m live-position safety check, resume-only pin
/// unstick, district/address reverse-geocode), previously duplicated
/// byte-for-byte across both screens. Room-type/plot-type, price/area,
/// furnished-status, photos, step navigation, and `_submit()`'s payload
/// assembly stay in each host screen — this mixin owns only what's inside
/// the map/location/address steps themselves.
mixin AddListingLocationMixin<T extends StatefulWidget> on State<T> {
  MapLibreMapController? _mapController;
  Symbol? _nativePin;
  double _currentZoom = 14.0;
  Size _mapSize = Size.zero;
  double _minZoom = 13.0;
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
  LatLng? _userLocation;
  Line? _circleGlowLine;
  Line? _circleBorderLine;
  Circle? _userDot;
  final _locationCtrl = Get.find<LocationController>();
  bool _mapReady = false;
  bool _cameraInitialized = false;
  late LocationStepStyle _style;

  // ── Public surface for the host screen ──────────────────────────────────

  LatLng? get userLocation => _userLocation;
  LatLng? get selectedLocation => _selectedLocation;
  LatLng? get pinnedOrLiveLocation => _selectedLocation ?? _userLocation;
  String? get selectedDistrictId => _resolvedDistrict?.id;
  String? get resolvedCityId => _resolvedCity?.id;
  bool get isResolvingDistrict => _isResolvingDistrict;
  bool get showAddressResolveOverlay => _showAddressResolveOverlay;
  String get trimmedAddress => _addressCtrl.text.trim();
  bool get hasAddressText => _addressCtrl.text.trim().isNotEmpty;
  bool get hasLocationOrAddressChanges =>
      _selectedLocation != null || _addressCtrl.text.isNotEmpty;

  void focusAddressField() => _addressFocusNode.requestFocus();

  void snapLocationToUserIfUnset() {
    if (_selectedLocation == null) setState(() => _selectedLocation = _userLocation);
  }

  // Sole resolve trigger left in this subsystem — always fresh, immediately,
  // for wherever the pin currently is.
  void resolveAddressIfNeeded() {
    final loc = _selectedLocation;
    if (loc != null) _resolveDistrictForPin(loc);
  }

  void initLocationTracking({required LocationStepStyle style, VoidCallback? onLocationStale}) {
    _style = style;
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
      _pinManuallyPlaced = false;
      final newLoc = _locationCtrl.userLocation.value;
      _onUserLocationChanged(newLoc);
      if (newLoc != null) _resolveDistrictForPin(newLoc);
      onLocationStale?.call();
    });
  }

  void disposeLocationTracking() {
    _userLocationWorker?.dispose();
    _resumeRefreshWorker?.dispose();
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
    _circleGlowLine = null;
    _circleBorderLine = null;
    _userDot = null;
  }

  // ── Internal mechanism (verbatim from the pre-extraction Add screens) ───

  // Keeps _userLocation tied to the CURRENT GPS fix always (read live by the
  // 500m pin-distance check) — but the visual pin/camera only follow it until
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
    if (_mapSize.width > 0) {
      _minZoom = _calcMinZoom(0.5, newLoc.latitude, _mapSize.width);
    }
    setState(() => _selectedLocation = newLoc);
    _setNativePin(newLoc);
    _updateNativeCircle(newLoc);
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
    if (_userLocation != null && _mapSize.width > 0) {
      _minZoom = _calcMinZoom(0.5, _userLocation!.latitude, _mapSize.width);
    }
    final pinBytes = await _buildPinImage();
    await ctrl.addImage('location_pin', pinBytes);
    _initNativeCircle();
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
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    final body = Paint()..color = const Color(0xFFE53935);
    final path = Path()
      ..addOval(Rect.fromCircle(center: const Offset(cx, cy), radius: r))
      ..moveTo(cx - 8, cy + r - 4)
      ..quadraticBezierTo(cx - 5, h - 6, cx, h)
      ..quadraticBezierTo(cx + 5, h - 6, cx + 8, cy + r - 4)
      ..close();
    canvas.drawPath(path, body);

    canvas.drawCircle(const Offset(cx, cy), 6.5, Paint()..color = Colors.white);

    final img = await recorder.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
    return bytes.buffer.asUint8List();
  }

  Future<void> _initNativeCircle() async {
    final ctrl = _mapController;
    final loc = _userLocation;
    if (ctrl == null || loc == null || !mounted) return;
    final points = _circlePolygonPoints(loc, 0.5);
    _circleGlowLine = await ctrl.addLine(LineOptions(
      geometry: points,
      lineColor: _style.circleColorHex,
      lineWidth: 10.0,
      lineOpacity: 0.20,
      lineBlur: 4.0,
    ));
    _circleBorderLine = await ctrl.addLine(LineOptions(
      geometry: points,
      lineColor: _style.circleColorHex,
      lineWidth: 2.5,
      lineOpacity: 0.90,
    ));
  }

  void _updateNativeCircle(LatLng loc) {
    final ctrl = _mapController;
    final glow = _circleGlowLine;
    final border = _circleBorderLine;
    if (ctrl == null || glow == null || border == null) return;
    final points = _circlePolygonPoints(loc, 0.5);
    ctrl.updateLine(glow, LineOptions(geometry: points));
    ctrl.updateLine(border, LineOptions(geometry: points));
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
      circleStrokeColor: '#FFFFFF',
      circleStrokeWidth: 2.5,
    ));
  }

  void _updateNativeUserDot(LatLng loc) {
    final ctrl = _mapController;
    final dot = _userDot;
    if (ctrl == null || dot == null) return;
    ctrl.updateCircle(dot, CircleOptions(geometry: loc));
  }

  double _calcMinZoom(double radiusKm, double lat, double screenWidthPx) {
    const earthCircumference = 2 * pi * 6378137.0;
    const tileSize = 512.0;
    final metersPerPxAtZ0 = earthCircumference * cos(lat * pi / 180) / tileSize;
    final targetMetersPerPx = (radiusKm * 1000 * 2) / (screenWidthPx * 0.85);
    final zoom = log(metersPerPxAtZ0 / targetMetersPerPx) / log(2);
    return zoom.clamp(11.0, 15.0);
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

  static List<LatLng> _circlePolygonPoints(LatLng center, double radiusKm) {
    const steps = 128;
    const earthRadius = 6378137.0;
    final latRad = center.latitude * pi / 180;
    return List.generate(steps + 1, (i) {
      final angle = 2 * pi * i / steps;
      final dLat = (radiusKm * 1000 * cos(angle)) / earthRadius * (180 / pi);
      final dLng = (radiusKm * 1000 * sin(angle)) / (earthRadius * cos(latRad)) * (180 / pi);
      return LatLng(center.latitude + dLat, center.longitude + dLng);
    });
  }

  static double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    const R = 6378137.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  // District/city/address resolve for the current pin; a newer call supersedes one still in flight.
  Future<void> _resolveDistrictForPin(LatLng pos) async {
    if (!mounted) return;
    final myGeneration = ++_districtResolveGeneration;
    setState(() {
      _isResolvingDistrict = true;
      _showAddressResolveOverlay = true;
      _resolvedDistrict = null;
      _resolvedCity = null;
    });
    try {
      final ctx = await _locationCtrl.resolveDistrictAt(pos.latitude, pos.longitude, includeAddress: true);
      if (!mounted || myGeneration != _districtResolveGeneration) return;
      setState(() {
        _resolvedDistrict = ctx.district;
        _resolvedCity = ctx.nearestCity;
        _isResolvingDistrict = false;
        _showAddressResolveOverlay = false;
      });
      final displayName = ctx.address;
      if (displayName != null && displayName.isNotEmpty) {
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

  InputDecoration _addressInputDecoration(String hint, {required Widget prefixIcon, Widget? suffixIcon}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _style.accentColor, width: 1.5)),
  );

  Widget _sectionCard({required String title, required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      const SizedBox(height: 10),
      child,
    ]),
  );

  Widget _readOnlyField(IconData icon, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.divider),
    ),
    child: Row(children: [
      Icon(icon, color: AppColors.primaryLight, size: 18),
      const SizedBox(width: 10),
      Text(value, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark)),
      const Spacer(),
      const Icon(Icons.gps_fixed_rounded, color: AppColors.success, size: 14),
    ]),
  );

  // ── Step widgets ─────────────────────────────────────────────────────────

  Widget locationStepWidget() => Padding(
    key: const ValueKey(1),
    padding: const EdgeInsets.all(16),
    child: _sectionCard(
      title: _style.pinStepTitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 15),
          const SizedBox(width: 6),
          Expanded(child: Text(
            _userLocation != null
                ? (_selectedLocation != null
                    ? 'Pinned — tap inside the circle to adjust'
                    : 'Tap inside the 500 m circle to pin your ${_style.pinHintNoun}')
                : 'Waiting for your GPS location...',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
          )),
        ]),
        const SizedBox(height: 12),
        if (_userLocation == null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 340,
              color: AppColors.surface,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _style.accentColor, strokeWidth: 2),
                    const SizedBox(height: 14),
                    const Text('Getting your location...', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
                  ],
                ),
              ),
            ),
          ),
        ] else
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              _mapSize = Size(constraints.maxWidth, 340);
              return SizedBox(
                height: 340,
                child: Stack(children: [
                  MapLibreMap(
                    styleString: 'assets/map_style.json',
                    initialCameraPosition: CameraPosition(
                      target: _userLocation ?? const LatLng(30.3165, 78.0322),
                      zoom: 14.0,
                    ),
                    compassEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    myLocationEnabled: false,
                    trackCameraPosition: true,
                    attributionButtonMargins: const Point(-200.0, 0.0),
                    onMapCreated: (ctrl) {
                      _mapController = ctrl;
                      _nativePin = null;
                      _circleGlowLine = null;
                      _circleBorderLine = null;
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
                      if (_userLocation != null) {
                        final distM = _distanceBetween(
                          _userLocation!.latitude, _userLocation!.longitude,
                          latLng.latitude, latLng.longitude,
                        );
                        if (distM > 500) {
                          AppToast.warning('You can only pin within 500 m of your current location');
                          return;
                        }
                      }
                      _pinManuallyPlaced = true;
                      setState(() => _selectedLocation = latLng);
                      _setNativePin(latLng);
                    },
                  ),
                  Positioned(
                    bottom: 10, right: 10,
                    child: GestureDetector(
                      onTap: () { if (_userLocation != null) _animateTo(_userLocation!, 15.0); },
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Icon(Iconsax.location, color: _style.accentColor, size: 18),
                      ),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
        if (_selectedLocation != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
              const SizedBox(width: 6),
              Text(
                '${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              const Text('© OpenStreetMap contributors', style: TextStyle(fontFamily: 'Poppins', fontSize: 9, color: AppColors.textLight)),
            ]),
          ),
      ]),
    ),
  );

  Widget addressStepWidget() => SingleChildScrollView(
    key: const ValueKey(2),
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionCard(
        title: 'District & City',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('District *', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
          const SizedBox(height: 6),
          _readOnlyField(Iconsax.location, _resolvedDistrict?.name ?? (_isResolvingDistrict ? 'Detecting…' : '—')),
          const SizedBox(height: 16),
          const Text('City / Area (Optional)', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
          const SizedBox(height: 6),
          _readOnlyField(Iconsax.map, _resolvedCity?.name ?? (_isResolvingDistrict ? 'Detecting…' : '—')),
        ]),
      ),
      _sectionCard(
        title: 'Address *',
        child: TextFormField(
          controller: _addressCtrl,
          focusNode: _addressFocusNode,
          inputFormatters: noEmojiInputFormatters,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: _addressInputDecoration(
            'Street, landmark, nearby place...',
            prefixIcon: Icon(_style.addressPrefixIcon, color: AppColors.primaryLight, size: 18),
            suffixIcon: _isResolvingDistrict
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _style.addressSpinnerColor),
                    ),
                  )
                : null,
          ),
        ),
      ),
    ]),
  );
}
