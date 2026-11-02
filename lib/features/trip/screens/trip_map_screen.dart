import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_constants.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_shadows.dart';
import '../../../widgets/empty_state_view.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_plan_result_model.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../utils/trip_format.dart';
import '../widgets/trip_day_actions.dart';
import '../widgets/trip_day_chips.dart';
import '../widgets/trip_route_strip.dart';

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

  static final String _white = AppColors.hexOf(AppColors.textWhite);

  @override
  void initState() {
    super.initState();
    _plan = TripPlanController.to;
    _plan.openPages++;
    final args = Get.arguments;
    final day = args is Map ? args['day'] as int? : null;
    _plan.selectedMapDay.value = day ?? 1;
    _workers.add(ever(_plan.plan, (_) => _sync()));
    _workers.add(ever(_plan.result, (_) => _sync()));
    _workers.add(ever(_plan.isPlanning, (_) => _sync()));
  }

  @override
  void dispose() {
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
    if (!mounted) return;
    setState(() => _styleLoaded = true);
    await _sync();
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
    if (!mounted || map == null || !_styleLoaded || p == null) return;
    if (_selected != TripDayChips.all && p.dayAt(_selected) == null) _plan.selectedMapDay.value = 1;
    final signature = _signature(p);
    if (signature != _drawnSignature) {
      await _redraw(map, p);
      _drawnSignature = signature;
      await _fitCamera();
    } else {
      for (final d in _drawnDays) {
        _hasRoute[d] = _plan.routeFor(d) != null;
        await map.setGeoJsonSource(_sourceId(d), _source(d));
      }
      await _applySelection();
    }
  }

  String _sourceId(int day) => 'trip-route-$day';

  Map<String, dynamic> _source(int day) {
    final route = _plan.routeFor(day);
    if (route == null && _plan.isPlanning.value) {
      return {'type': 'FeatureCollection', 'features': <Map<String, dynamic>>[]};
    }
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
  }

  Future<void> _fitCamera() async {
    final map = _map;
    final p = _plan.plan.value;
    if (map == null || p == null) return;
    final spots = _selected == TripDayChips.all ? p.allSpots : _spotsOf(_selected);
    if (spots.isEmpty) return;
    var minLat = spots.first.latitude, maxLat = minLat;
    var minLng = spots.first.longitude, maxLng = minLng;
    for (final s in spots) {
      minLat = min(minLat, s.latitude);
      maxLat = max(maxLat, s.latitude);
      minLng = min(minLng, s.longitude);
      maxLng = max(maxLng, s.longitude);
    }
    if (maxLat - minLat < 0.0005 && maxLng - minLng < 0.0005) {
      await map.animateCamera(CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 14));
      return;
    }
    await map.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
      left: 48,
      top: 120,
      right: 48,
      bottom: 220,
    ));
  }

  Future<void> _select(int day) async {
    if (day == _selected) return;
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
                onMapCreated: (MapLibreMapController ctrl) => _map = ctrl,
                onStyleLoadedCallback: _onStyleLoaded,
              ),
            ),
          ),
          if (!_styleLoaded) Positioned.fill(child: _buildMapShimmer()),
          Positioned.fill(child: _buildState()),
          Positioned(left: 0, right: 0, top: 0, child: _buildTop(context)),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomCard(context)),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (count > 1) TripDayChips(dayCount: count, selected: selected, onChanged: _select, includeAll: true),
                if (missing) ...[
                  const SizedBox(height: 10),
                  _routeMissingChip(),
                ],
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
          Text(
            TripStrings.routeMissing,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCard(BuildContext context) {
    return Obx(() {
      _plan.result.value;
      final p = _plan.plan.value;
      if (p == null || p.days.isEmpty || _plan.plannerOff.value) return const SizedBox.shrink();
      final selected = _selected;
      final all = selected == TripDayChips.all;
      final title = all ? '${p.days.length} ${p.days.length == 1 ? 'day' : 'days'}' : 'Day $selected';
      final km = p.days.fold<double>(0, (sum, d) => sum + _plan.dayKm(d.day));
      final line = all ? TripFormat.km(km) : TripRouteStrip.routeLine(_plan, selected);
      return Container(
        margin: EdgeInsets.fromLTRB(16, 0, 16, AppInsets.bottomViewPadding(context) + 16),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.premium(TripColors.accent, alpha: 0.16, blur: 18, offset: const Offset(0, 6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: all ? AppColors.textDark : TripColors.dayColor(selected),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                  ),
                ),
              ],
            ),
            if (!all) ...[
              const SizedBox(height: 12),
              TripDayActions(selected),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildState() {
    return Obx(() {
      final off = _plan.plannerOff.value;
      final failed = _plan.openFailed.value;
      if (!off && !failed) return const IgnorePointer(child: SizedBox.shrink());
      return Container(
        color: AppColors.scaffoldBg,
        alignment: Alignment.topCenter,
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 80),
        child: off
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
