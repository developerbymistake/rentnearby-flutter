import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_constants.dart';
import '../../../widgets/empty_state_view.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_plan_result_model.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../widgets/trip_day_chips.dart';
import '../widgets/trip_map_day_card.dart';
import '../widgets/trip_not_found_view.dart';

class TripMapScreen extends StatefulWidget {
  const TripMapScreen({super.key});

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  late final TripPlanController _plan;
  final _workers = <Worker>[];
  MapLibreMapController? _map;
  bool _styleLoaded = false;
  bool _busy = false;
  bool _again = false;
  String? _drawnSignature;
  final _drawnDays = <int>[];
  final _circles = <int, List<Circle>>{};
  final _symbols = <int, List<Symbol>>{};
  final _hasRoute = <int, bool>{};
  final _stayPins = <int, Symbol>{};
  final _topKey = GlobalKey();
  final _cardKey = GlobalKey();
  String? _drawnStaySignature;
  bool _stayPinReady = false;
  bool _dayPicked = false;
  bool _awaitingDefaultDay = false;
  String? _waitingTripId;

  bool get _waitingForTrip {
    final id = _waitingTripId;
    if (id == null) return false;
    if (_plan.openFailed.value || _plan.tripGone.value || _plan.plannerOff.value) return false;
    return _plan.trip.value?.id != id || _plan.plan.value == null;
  }

  static const String _stayPinImage = 'trip_stay_pin';
  static final String _white = AppColors.hexOf(AppColors.textWhite);
  static final String _stayText = AppColors.hexOf(StayColors.accentDark);

  @override
  void initState() {
    super.initState();
    _plan = TripPlanController.to;
    _plan.openPages++;
    final args = Get.arguments;
    final day = args is Map ? args['day'] as int? : null;
    final tripId = args is Map ? args['tripId'] as String? : null;
    final needsOpen = tripId != null && (_plan.trip.value?.id != tripId || _plan.plan.value == null);
    _dayPicked = day != null;
    _awaitingDefaultDay = day == null && (needsOpen || _plan.plan.value == null);
    _plan.selectedMapDay.value = day ?? (needsOpen || _plan.plan.value == null ? 1 : _plan.defaultMapDay);
    if (needsOpen) {
      _waitingTripId = tripId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _plan.open(tripId);
      });
    }
    _workers.add(ever(_plan.plan, (_) {
      _applyDefaultDay();
      _sync();
    }));
    _workers.add(ever(_plan.result, (_) => _sync()));
    _workers.add(ever(_plan.isPlanning, (_) => _sync()));
    _workers.add(ever(_plan.planFailed, (failed) {
      if (!failed) _recalculateIfRouteMissing();
    }));
  }

  void _applyDefaultDay() {
    if (!_awaitingDefaultDay || _plan.plan.value == null) return;
    _awaitingDefaultDay = false;
    if (!_dayPicked) _plan.selectedMapDay.value = _plan.defaultMapDay;
  }

  @override
  void dispose() {
    _map?.onSymbolTapped.remove(_onSymbolTapped);
    for (final w in _workers) {
      w.dispose();
    }
    if (Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), _plan)) {
      _plan.openPages--;
      _plan.releaseIfIdle();
    }
    super.dispose();
  }

  int get _selected => _plan.selectedMapDay.value;

  bool _isSelected(int day) => _selected == TripDayChips.all || _selected == day;

  List<TripSpotRef> _spotsOf(int day) => _plan.plan.value?.dayAt(day)?.spots ?? const [];

  bool _dayRouteMissing(int day) {
    if (_plan.isPlanning.value || _spotsOf(day).length < 2) return false;
    if (_plan.planFailed.value && _plan.routeFor(day) == null) return true;
    if (_plan.hasWarning(day, TripWarningCodes.routeMissing) || _plan.hasWarning(day, TripWarningCodes.osrmUnavailable)) {
      return true;
    }
    final r = _plan.resultDay(day);
    return r != null && r.routeGeoJson == null;
  }

  String _signature(TripPlan p) => p.days.map((d) => '${d.day}:${d.spots.map((s) => s.id).join(',')}').join('|');

  LatLng _initialTarget() {
    final p = _plan.plan.value;
    final spots = p == null ? const <TripSpotRef>[] : (_spotsOf(_selected).isEmpty ? p.allSpots : _spotsOf(_selected));
    if (spots.isNotEmpty) return LatLng(spots.first.latitude, spots.first.longitude);
    final lat = p?.centreLatitude;
    final lng = p?.centreLongitude;
    if (lat != null && lng != null) return LatLng(lat, lng);
    return const LatLng(AppConstants.fallbackLat, AppConstants.fallbackLng);
  }

  Future<void> _onStyleLoaded() async {
    final map = _map;
    if (map == null || _styleLoaded) return;
    await map.setSymbolTextAllowOverlap(true);
    await map.setSymbolTextIgnorePlacement(true);
    await map.setSymbolIconAllowOverlap(true);
    await map.setSymbolIconIgnorePlacement(true);
    try {
      await map.addImage(_stayPinImage, await _buildStayPinImage());
      _stayPinReady = true;
    } catch (_) {
      _stayPinReady = false;
    }
    if (!mounted) return;
    setState(() => _styleLoaded = true);
    await _sync();
    _recalculateIfRouteMissing();
  }

  void _recalculateIfRouteMissing() {
    final p = _plan.plan.value;
    if (p == null || _plan.isPlanning.value || _plan.isOpening.value || _plan.plannerOff.value) return;
    if (p.days.any((d) => d.spots.length >= 2 && _plan.routeFor(d.day) == null)) _plan.recalculate().ignore();
  }

  Future<void> _sync() async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        await _syncOnce();
      } while (_again && mounted);
    } finally {
      _busy = false;
    }
  }

  Future<void> _syncOnce() async {
    final map = _map;
    final p = _plan.plan.value;
    if (!mounted || map == null || !_styleLoaded || p == null || _waitingForTrip) return;
    if (_selected != TripDayChips.all && p.dayAt(_selected) == null) _plan.selectedMapDay.value = 1;
    if (_selected == TripDayChips.all && p.days.length <= 1) _plan.selectedMapDay.value = 1;
    final signature = _signature(p);
    final staySignature = _staySignature(p);
    if (signature != _drawnSignature) {
      final edited = _drawnSignature != null;
      await _redraw(map, p);
      _drawnSignature = signature;
      _drawnStaySignature = staySignature;
      await _fitCamera();
      if (edited) _recalculateIfRouteMissing();
    } else {
      for (final d in _drawnDays) {
        _hasRoute[d] = _plan.routeFor(d) != null;
        await map.setGeoJsonSource(_sourceId(d), _source(d));
      }
      if (staySignature != _drawnStaySignature) {
        await _drawStayPins(map, p);
        _drawnStaySignature = staySignature;
        await _applySelection();
        await _fitCamera();
      } else {
        await _applySelection();
      }
    }
  }

  String _staySignature(TripPlan p) => [
        p.days.length,
        for (final d in p.days)
          '${d.day}:${d.stay?.stayId}:${d.stay?.sameAsDay}:${d.stay?.latitude}:${d.stay?.longitude}',
      ].join('|');

  TripStayChoice? _pinnedStay(TripDay day) {
    final s = day.stay;
    if (s == null || s.isSameStay || !s.hasCoordinates) return null;
    return s;
  }

  int? _pinDayFor(int day) {
    final s = _plan.plan.value?.dayAt(day)?.stay;
    if (s == null) return null;
    return s.sameAsDay ?? day;
  }

  bool _isStayPinSelected(int pinDay) => _selected == TripDayChips.all || _pinDayFor(_selected) == pinDay;

  Future<void> _drawStayPins(MapLibreMapController map, TripPlan p) async {
    if (_stayPins.isNotEmpty) {
      final old = _stayPins.values.toList();
      _stayPins.clear();
      await map.removeSymbols(old);
    }
    if (!_stayPinReady) return;
    for (final day in p.days) {
      final s = _pinnedStay(day);
      if (s == null) continue;
      final on = _isStayPinSelected(day.day);
      _stayPins[day.day] = await map.addSymbol(SymbolOptions(
        geometry: LatLng(s.latitude!, s.longitude!),
        iconImage: _stayPinImage,
        iconSize: 1,
        iconOpacity: on ? 1 : 0.35,
        textField: p.days.length > 1 ? TripStrings.night(day.day) : TripStrings.stay,
        fontNames: const ['Noto Sans Medium'],
        textSize: 11,
        textAnchor: 'top',
        textOffset: const Offset(0, 1.9),
        textColor: _stayText,
        textHaloColor: _white,
        textHaloWidth: 1,
        textOpacity: on ? 1 : 0.35,
        zIndex: 10,
      ));
    }
  }

  void _onSymbolTapped(Symbol symbol) {
    for (final e in _stayPins.entries) {
      if (e.value == symbol || e.value.id == symbol.id) {
        _select(e.key);
        return;
      }
    }
  }

  static Future<Uint8List> _buildStayPinImage() async {
    const double size = 48, c = size / 2, r = 19;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    canvas.drawCircle(
      const Offset(c, c + 1.5),
      r + 1,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(const Offset(c, c), r, Paint()..color = StayColors.accent);
    canvas.drawCircle(
      const Offset(c, c),
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    const icon = Iconsax.building_4;
    final glyph = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    glyph.paint(canvas, Offset(c - glyph.width / 2, c - glyph.height / 2));
    final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
    return bytes.buffer.asUint8List();
  }

  String _sourceId(int day) => 'trip-route-$day';

  Map<String, dynamic> _source(int day) {
    final route = _plan.routeFor(day);
    final geometry = route ??
        <String, dynamic>{
          'type': 'LineString',
          'coordinates': [
            for (final s in _spotsOf(day)) [s.longitude, s.latitude],
          ],
        };
    final coords = geometry['coordinates'];
    final valid = coords is List && coords.length >= 2;
    return {
      'type': 'FeatureCollection',
      'features': [
        if (valid) {'type': 'Feature', 'properties': <String, dynamic>{}, 'geometry': geometry},
      ],
    };
  }

  LineLayerProperties _lineProps(int day, bool selected, {required bool glow}) {
    final color = AppColors.hexOf(TripColors.dayColor(day));
    if (glow) {
      return LineLayerProperties(lineColor: color, lineWidth: 8, lineOpacity: selected ? 0.18 : 0.05, lineBlur: 3);
    }
    return LineLayerProperties(
      lineColor: color,
      lineWidth: 4,
      lineOpacity: selected ? 0.9 : 0.25,
      lineDasharray: _hasRoute[day] == true ? null : [2, 2],
    );
  }

  Future<void> _redraw(MapLibreMapController map, TripPlan p) async {
    for (final d in _drawnDays) {
      await map.removeLayer('${_sourceId(d)}-line');
      await map.removeLayer('${_sourceId(d)}-glow');
      await map.removeSource(_sourceId(d));
    }
    _drawnDays.clear();
    _circles.clear();
    _symbols.clear();
    _hasRoute.clear();
    _stayPins.clear();
    await map.clearCircles();
    await map.clearSymbols();
    final below = map.circleManager?.layerIds.first;
    for (final day in p.days) {
      final d = day.day;
      final selected = _isSelected(d);
      final color = AppColors.hexOf(TripColors.dayColor(d));
      _hasRoute[d] = _plan.routeFor(d) != null;
      await map.addGeoJsonSource(_sourceId(d), _source(d));
      await map.addLineLayer(_sourceId(d), '${_sourceId(d)}-glow', _lineProps(d, selected, glow: true),
          belowLayerId: below);
      await map.addLineLayer(_sourceId(d), '${_sourceId(d)}-line', _lineProps(d, selected, glow: false),
          belowLayerId: below);
      final circles = <Circle>[];
      final symbols = <Symbol>[];
      for (var i = 0; i < day.spots.length; i++) {
        final s = day.spots[i];
        final at = LatLng(s.latitude, s.longitude);
        circles.add(await map.addCircle(CircleOptions(
          geometry: at,
          circleRadius: 12,
          circleColor: color,
          circleOpacity: selected ? 1 : 0.35,
          circleStrokeColor: _white,
          circleStrokeWidth: 2,
        )));
        symbols.add(await map.addSymbol(SymbolOptions(
          geometry: at,
          textField: '${i + 1}',
          fontNames: const ['Noto Sans Medium'],
          textSize: 11,
          textColor: _white,
          textOpacity: selected ? 1 : 0.35,
        )));
      }
      _circles[d] = circles;
      _symbols[d] = symbols;
      _drawnDays.add(d);
    }
    await _drawStayPins(map, p);
  }

  Future<void> _applySelection() async {
    final map = _map;
    if (map == null) return;
    for (final d in _drawnDays) {
      final selected = _isSelected(d);
      await map.setLayerProperties('${_sourceId(d)}-glow', _lineProps(d, selected, glow: true));
      await map.setLayerProperties('${_sourceId(d)}-line', _lineProps(d, selected, glow: false));
      for (final c in _circles[d] ?? const <Circle>[]) {
        await map.updateCircle(c, CircleOptions(circleOpacity: selected ? 1 : 0.35));
      }
      for (final s in _symbols[d] ?? const <Symbol>[]) {
        await map.updateSymbol(s, SymbolOptions(textOpacity: selected ? 1 : 0.35));
      }
    }
    for (final e in _stayPins.entries) {
      final on = _isStayPinSelected(e.key);
      await map.updateSymbol(e.value, SymbolOptions(iconOpacity: on ? 1 : 0.35, textOpacity: on ? 1 : 0.35));
    }
  }

  double _overlayHeight(GlobalKey key, double fallback) {
    final box = key.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize && box.size.height > 0) return box.size.height;
    return fallback;
  }

  List<LatLng> _focusPoints(TripPlan p) {
    final all = _selected == TripDayChips.all;
    final points = <LatLng>[
      for (final s in all ? p.allSpots : _spotsOf(_selected)) LatLng(s.latitude, s.longitude),
    ];
    final pinDay = all ? null : _pinDayFor(_selected);
    for (final day in p.days) {
      if (!all && day.day != pinDay) continue;
      final s = _pinnedStay(day);
      if (s != null) points.add(LatLng(s.latitude!, s.longitude!));
    }
    return points;
  }

  Future<void> _fitCamera() async {
    final map = _map;
    final p = _plan.plan.value;
    if (map == null || p == null || !mounted) return;
    final points = _focusPoints(p);
    if (points.isEmpty) return;
    var minLat = points.first.latitude, maxLat = minLat;
    var minLng = points.first.longitude, maxLng = minLng;
    for (final s in points) {
      minLat = min(minLat, s.latitude);
      maxLat = max(maxLat, s.latitude);
      minLng = min(minLng, s.longitude);
      maxLng = max(maxLng, s.longitude);
    }
    if (maxLat - minLat < 0.0005 && maxLng - minLng < 0.0005) {
      await map.animateCamera(CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 14));
      return;
    }
    final size = MediaQuery.sizeOf(context);
    var top = _overlayHeight(_topKey, 120) + 24;
    var bottom = _overlayHeight(_cardKey, 220) + 24;
    final room = size.height - 120;
    if (top + bottom > room && room > 0) {
      final scale = room / (top + bottom);
      top *= scale;
      bottom *= scale;
    }
    final side = min(48.0, size.width * 0.12);
    await map.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
      left: side,
      top: top,
      right: side,
      bottom: bottom,
    ));
  }

  Future<void> _select(int day) async {
    if (day == _selected) return;
    _dayPicked = true;
    _plan.selectedMapDay.value = day;
    if (_busy) {
      _again = true;
    } else {
      await _applySelection();
    }
    await _fitCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: MapLibreMap(
                styleString: "assets/map_style.json",
                initialCameraPosition: CameraPosition(target: _initialTarget(), zoom: 13.0),
                minMaxZoomPreference: const MinMaxZoomPreference(8, 18),
                compassEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                myLocationEnabled: false,
                trackCameraPosition: true,
                attributionButtonMargins: const Point(-200.0, 0.0),
                annotationOrder: const [AnnotationType.circle, AnnotationType.symbol],
                onMapCreated: (MapLibreMapController ctrl) {
                  _map = ctrl;
                  ctrl.onSymbolTapped.add(_onSymbolTapped);
                },
                onStyleLoadedCallback: _onStyleLoaded,
              ),
            ),
          ),
          Positioned.fill(
            child: Obx(() {
              _plan.trip.value;
              final opening = (_plan.isOpening.value && _plan.plan.value == null) || _waitingForTrip;
              return !_styleLoaded || opening ? _buildMapShimmer() : const IgnorePointer(child: SizedBox.shrink());
            }),
          ),
          Positioned.fill(child: _buildState()),
          Positioned(left: 0, right: 0, top: 0, child: KeyedSubtree(key: _topKey, child: _buildTop(context))),
          Positioned(left: 0, right: 0, bottom: 0, child: KeyedSubtree(key: _cardKey, child: _buildBottomCard(context))),
        ],
      ),
    );
  }

  Widget _buildMapShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(color: AppColors.shimmerBase),
    );
  }

  Widget _buildTop(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: TripColors.gradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(12, top + 8, 20, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      TripStrings.tripMap,
                      maxLines: 1,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Obx(() => Text(
                          TripStrings.tripMapSubtitle(_plan.cityName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
        Obx(() {
          _plan.result.value;
          final p = _plan.plan.value;
          final count = _plan.dayCount;
          final selected = _selected;
          final missing = p != null &&
              !_plan.plannerOff.value &&
              (selected != TripDayChips.all
                  ? _dayRouteMissing(selected)
                  : p.days.any((d) => _dayRouteMissing(d.day)));
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (count > 1)
                  TripDayChips(
                    dayCount: count,
                    selected: selected,
                    onChanged: _select,
                    includeAll: true,
                    compact: true,
                    allFirst: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                if (missing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: _routeMissingChip(),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _routeMissingChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: TripColors.accent.withValues(alpha: 0.22), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.warning_2, size: 14, color: AppColors.warning),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              TripStrings.routeMissing,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMedium),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCard(BuildContext context) {
    return Obx(() {
      final p = _plan.plan.value;
      _plan.trip.value;
      if (p == null || p.days.isEmpty || _plan.plannerOff.value || _plan.openFailed.value || _plan.tripGone.value) {
        return const SizedBox.shrink();
      }
      if (_waitingForTrip) return const SizedBox.shrink();
      return TripMapDayCard(
        dayCount: p.days.length,
        selected: _selected,
        onDaySelected: _select,
      );
    });
  }

  Widget _buildState() {
    return Obx(() {
      final off = _plan.plannerOff.value;
      final failed = _plan.openFailed.value;
      final gone = _plan.tripGone.value;
      if (!off && !failed && !gone) return const IgnorePointer(child: SizedBox.shrink());
      return Container(
        color: AppColors.scaffoldBg,
        alignment: Alignment.topCenter,
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 80),
        child: gone
            ? const TripNotFoundView()
            : off
            ? const EmptyStateView(
                icon: Iconsax.routing_2,
                title: TripStrings.plannerOff,
                subtitle: TripStrings.plannerOffSubtitle,
              )
            : EmptyStateView(
                icon: Iconsax.cloud_cross,
                title: TripStrings.tripFailed,
                subtitle: TripStrings.checkConnection,
                onRetry: _plan.retryOpen,
                palette: TripColors.palette,
              ),
      );
    });
  }
}
