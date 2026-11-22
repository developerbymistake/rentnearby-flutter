import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bakhli/design/design.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../config/app_constants.dart';
import '../../map_discovery/data/map_pack_service.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_plan_result_model.dart';
import '../trip_strings.dart';
import '../utils/trip_easy_rules.dart';
import '../trip_strings_city.dart';
import '../trip_strings_steps_a3.dart';
import '../utils/trip_map_geo.dart';
import '../utils/trip_map_rules.dart';
import '../widgets/trip_day_chips.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../trip_strings_dayplan.dart';
import '../trip_strings_v2_plan.dart';
import '../widgets/trip_plan_header.dart';
import '../widgets/trip_not_found_view.dart';
import '../map/discovery_api.dart';
import '../map/trip_discovery_layer.dart';
import '../map/discovery_overlay.dart';
import '../map/trip_map_spot_actions.dart';

class TripMapScreen extends StatefulWidget {
  const TripMapScreen({super.key});

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
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
  final _drawnRoutes = <int, Map<String, dynamic>?>{};
  final _lineKeys = <String, String>{};
  final _stayPins = <int, Symbol>{};
  final _drawnSegs = <int>[];
  final _cityDots = <int, Circle>{};
  final _cityLabels = <int, Symbol>{};
  final _badges = <int, Symbol>{};
  final _changeDots = <int, List<Circle>>{};
  final _changeLabels = <int, List<Symbol>>{};
  bool _wideZoom = false;
  final _topKey = GlobalKey();
  static const List<Color> _routeColors = [TripLook.headerGlow, TripLook.mapRouteDay2, TripLook.dayCyan];
  static Color _routeColor(int day) => _routeColors[(day - 1) % _routeColors.length];
  String? _drawnStaySignature;
  bool _stayPinReady = false;
  bool _carPinReady = false;
  bool _dayPicked = false;
  bool _awaitingDefaultDay = false;
  String? _waitingTripId;
  TripDiscoveryLayer? _disc;
  bool _discBusy = false;
  bool _forceRedraw = false;
  String? _discKeys;
  static const double _discCardBand = 150;
  late final TripMapSpotActions _spotActions = TripMapSpotActions.of(_plan, context: () => context);

  bool get _waitingForTrip {
    final id = _waitingTripId;
    if (id == null) return false;
    if (_plan.openFailed.value || _plan.tripGone.value || _plan.plannerOff.value) return false;
    return _plan.trip.value?.id != id || _plan.plan.value == null;
  }

  static const String _stayPinImage = 'trip_stay_pin';
  static const String _carPinImage = 'trip_car_badge';
  static final String _white = TripKit.hexOf(FitnessAppTheme.white);
  static final String _stayText = TripKit.hexOf(TravelPalette.sunriseStart);
  static final String _cityText = TripKit.hexOf(FitnessAppTheme.darkerText);
  static final String _travelText = TripKit.hexOf(TravelPalette.roseEnd);
  static final String _changeStroke = TripKit.hexOf(TravelPalette.sunriseStart);
  static final String _changeText = TripKit.hexOf(FitnessAppTheme.darkText);
  static const _multiCityZoom = MinMaxZoomPreference(4, 18);

  MinMaxZoomPreference _oneCityZoom(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final lat = _plan.plan.value?.centreLatitude ?? AppConstants.fallbackLat;
    final px = max(100.0, min(size.width, size.height) - 96);
    return MinMaxZoomPreference(TripMapGeo.oneCityMinZoom(lat, px), 18);
  }

  @override
  void initState() {
    super.initState();
    _plan = TripPlanController.to;
    _enter.forward();
    _plan.openPages++;
    _wideZoom = _plan.isMultiCity;
    final args = Get.arguments;
    final day = args is Map ? args['day'] as int? : null;
    final tripId = args is Map ? args['tripId'] as String? : null;
    final needsOpen = tripId != null && (_plan.trip.value?.id != tripId || _plan.plan.value == null);
    _dayPicked = day != null;
    _awaitingDefaultDay = day == null && (needsOpen || _plan.plan.value == null);
    _plan.selectedMapLeg.value = 0;
    _plan.selectedMapDay.value = day ?? (needsOpen || _plan.plan.value == null ? 1 : _plan.defaultMapDay);
    if (needsOpen) {
      _waitingTripId = tripId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _plan.open(tripId);
      });
    }
    _workers.add(ever(_plan.plan, (_) {
      _applyDefaultDay();
      _ensureDiscData();
      _sync();
    }));
    _workers.add(ever(_discSource.state, (_) => _onDiscChanged()));
    _workers.add(ever(MapPackService.to.revision, (_) => _onDiscChanged()));
    _ensureDiscData();
    _workers.add(ever(_plan.result, (_) => _sync()));
    _workers.add(ever(_plan.enquiryList, (_) => _sync()));
    _workers.add(ever(_plan.isPlanning, (_) => _sync()));
    _workers.add(ever(_plan.planFailed, (failed) {
      if (!failed) _recalculateIfRouteMissing();
    }));
  }

  void _applyDefaultDay() {
    if (!_awaitingDefaultDay || _plan.plan.value == null) return;
    _awaitingDefaultDay = false;
    if (!_dayPicked) {
      _plan.selectedMapLeg.value = 0;
      _plan.selectedMapDay.value = _plan.defaultMapDay;
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _map?.onSymbolTapped.remove(_onSymbolTapped);
    _map?.onCircleTapped.remove(_onCircleTapped);
    _disc?.dispose();
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

  bool _isSelected(int day) => _plan.mapShowsDay(day);

  bool get _citiesOn => _plan.mapFocus != TripMapFocus.day;

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

  String _signature(TripPlan p) {
    final days = p.days.map((d) => '${d.day}:${d.spots.map((s) => s.id).join(',')}').join('|');
    if (!p.isMultiCity) return days;
    final legs = [
      for (final l in p.legs)
        '${l.cityKey}:${l.latitude}:${l.longitude}:${l.arrival?.journeyId}:${l.arrival?.cars}:'
            '${l.arrival?.planKey}:${l.index >= 2 ? _plan.segmentLine(l.index)?.length : null}',
    ].join('|');
    return '$days#$legs';
  }

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
    try {
      await map.addImage(_carPinImage, await _buildCarPinImage());
      _carPinReady = true;
    } catch (_) {
      _carPinReady = false;
    }
    if (!mounted) return;
    setState(() => _styleLoaded = true);
    await _attachDisc();
    await _sync();
    _recalculateIfRouteMissing();
  }

  DiscoveryDataSource get _discSource => MapPackService.to.source;

  Set<int> _legKeys() => {
        for (final l in _plan.plan.value?.legs ?? const <TripCityLeg>[])
          if (l.cityKey > 0) l.cityKey,
      };

  DiscoveryHost _discHost() => DiscoveryHost(
        anchorLayerId: () => _map?.circleManager?.layerIds.first,
        plannedDayOf: (id) => _plan.plan.value?.dayOfSpot(id),
        topInset: () => _overlayHeight(_topKey, DS.s(120)),
        bottomInset: () => MediaQuery.paddingOf(context).bottom,
        targetDayFor: _spotActions.targetDayFor,
        onAdd: _spotActions.add,
        onRemove: _spotActions.remove,
        onDetails: _spotActions.details,
        lineFor: _spotActions.lineFor,
      );

  void _ensureDiscData() {
    final keys = _legKeys();
    final sig = (keys.toList()..sort()).join(',');
    if (keys.isEmpty || sig == _discKeys) return;
    _discKeys = sig;
    _discSource.ensureForCities(keys).ignore();
    _disc?.refreshData().ignore();
  }

  Future<void> _attachDisc({bool late = false}) async {
    final map = _map;
    if (_discBusy || _disc != null || map == null || !_styleLoaded) return;
    _discBusy = true;
    try {
      final layer = await DiscoveryAttach.maybe(
        map,
        mode: DiscoveryMode.full,
        host: _discHost(),
        source: _discSource,
        tuning: DiscTuning.trip,
        dataOf: (s) => s.forCities(_legKeys()),
        viewSize: () => MediaQuery.sizeOf(context),
        unitsPerDp: () => DiscoveryAttach.unitsPerDp(context),
        cardHeight: () => DS.s(_discCardBand),
      );
      if (layer == null) return;
      if (!mounted) {
        layer.dispose();
        return;
      }
      setState(() => _disc = layer);
      if (late) {
        _forceRedraw = true;
        await _sync();
      }
    } finally {
      _discBusy = false;
    }
  }

  Future<void> _onDiscChanged() async {
    if (!mounted || !_styleLoaded) return;
    final d = _disc;
    if (d == null) {
      await _attachDisc(late: true);
      return;
    }
    if (DiscoveryAttach.wanted(_discSource)) return;
    setState(() => _disc = null);
    await d.detach();
    d.dispose();
    if (!mounted) return;
    _forceRedraw = true;
    await _sync();
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
    await _applyZoomFloor(p);
    if (!mounted) return;
    final leg = _plan.selectedMapLeg.value;
    if (leg > 0 && p.isMultiCity && p.isSingleDayLeg(leg)) {
      _plan.selectMapDay(p.legStart(leg));
    } else if (leg > 0 && (!p.isMultiCity || p.legAt(leg) == null || p.legStart(leg) < 1)) {
      _plan.selectedMapLeg.value = 0;
    }
    if (_selected != TripDayChips.all && p.dayAt(_selected) == null) _plan.selectedMapDay.value = 1;
    if (_selected == TripDayChips.all && _plan.selectedMapLeg.value == 0 && p.days.length <= 1) {
      _plan.selectedMapDay.value = 1;
    }
    final signature = _signature(p);
    final staySignature = _staySignature(p);
    final forced = _forceRedraw;
    _forceRedraw = false;
    if (signature != _drawnSignature || forced) {
      final edited = _drawnSignature != null;
      final moved = signature != _drawnSignature;
      await _redraw(map, p);
      _drawnSignature = signature;
      _drawnStaySignature = staySignature;
      if (moved) {
        await _fitCamera();
      } else {
        await _applySelection();
      }
      if (edited && moved) _recalculateIfRouteMissing();
    } else {
      for (final d in _drawnDays) {
        final route = _plan.routeFor(d);
        if (identical(route, _drawnRoutes[d])) continue;
        _drawnRoutes[d] = route;
        _hasRoute[d] = route != null;
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

  Future<void> _applyZoomFloor(TripPlan p) async {
    if (p.isMultiCity == _wideZoom) return;
    setState(() => _wideZoom = p.isMultiCity);
    await WidgetsBinding.instance.endOfFrame;
  }

  List<({int pinDay, Set<int> days, double lat, double lon})> _stayPinData(TripPlan p) {
    final out = <({int pinDay, Set<int> days, double lat, double lon})>[];
    for (final e in _plan.enquiryList) {
      final lat = e.listingLatitude;
      final lon = e.listingLongitude;
      if (e.isTaxi || !e.isConfirmedByBoth || lat == null || lon == null) continue;
      final days = TripEasyRules.nightsOf(e, p);
      if (days.isEmpty) continue;
      final first = days.reduce((a, b) => a < b ? a : b);
      if (out.any((x) => x.pinDay == first)) continue;
      out.add((pinDay: first, days: days, lat: lat, lon: lon));
    }
    return out;
  }

  String _staySignature(TripPlan p) =>
      [for (final x in _stayPinData(p)) '${x.pinDay}:${x.days.length}:${x.lat}:${x.lon}'].join('|');

  int? _pinDayFor(int day) {
    final p = _plan.plan.value;
    if (p == null) return null;
    for (final x in _stayPinData(p)) {
      if (x.days.contains(day)) return x.pinDay;
    }
    return null;
  }

  bool _isStayPinSelected(int pinDay) => switch (_plan.mapFocus) {
        TripMapFocus.all => true,
        TripMapFocus.city => _plan.legIndexOf(pinDay) == _plan.selectedMapLeg.value,
        TripMapFocus.day => _pinDayFor(_selected) == pinDay || _startPinDay == pinDay,
      };

  int? get _startPinDay {
    final d = _selected;
    if (_plan.mapFocus != TripMapFocus.day || d <= 1 || _plan.legIndexOf(d - 1) != _plan.legIndexOf(d)) return null;
    return _pinDayFor(d - 1);
  }

  String _stayPinText(TripPlan p, int pinDay) {
    if (_startPinDay == pinDay && _pinDayFor(_selected) != pinDay) return TripStrings.startsHere(_selected);
    return p.days.length > 1 ? TripStrings.night(pinDay) : TripStrings.stay;
  }

  bool get _hidesOtherLegs => _plan.isMultiCity && _plan.mapFocus == TripMapFocus.city;

  bool get _lighterDays => _plan.isMultiCity && _plan.mapFocus == TripMapFocus.all;

  double _dimOrHide(bool on) => on ? 1 : (_hidesOtherLegs ? 0 : 0.35);

  double _stayPinOpacity(int pinDay) => _dimOrHide(_isStayPinSelected(pinDay));

  double _dayOpacity(int day) => _dimOrHide(_isSelected(day));

  double _segOpacity(int legIndex) => _dimOrHide(_plan.mapShowsSegment(legIndex));

  double? _ringOpacity(double opacity) => _plan.isMultiCity ? (opacity == 0 ? 0 : 1) : null;

  Future<void> _drawStayPins(MapLibreMapController map, TripPlan p) async {
    if (_stayPins.isNotEmpty) {
      final old = _stayPins.values.toList();
      _stayPins.clear();
      await map.removeSymbols(old);
    }
    if (!_stayPinReady) return;
    final days = <int>[];
    final options = <SymbolOptions>[];
    for (final x in _stayPinData(p)) {
      final opacity = _stayPinOpacity(x.pinDay);
      days.add(x.pinDay);
      options.add(SymbolOptions(
        geometry: LatLng(x.lat, x.lon),
        iconImage: _stayPinImage,
        iconSize: 1,
        iconOpacity: opacity,
        textField: _stayPinText(p, x.pinDay),
        fontNames: const ['Noto Sans Medium'],
        textSize: 11,
        textAnchor: 'top',
        textOffset: const Offset(0, 1.9),
        textColor: _stayText,
        textHaloColor: _white,
        textHaloWidth: 1,
        textOpacity: opacity,
        zIndex: 10,
      ));
    }
    if (options.isEmpty) return;
    final added = await map.addSymbols(options);
    for (var i = 0; i < added.length; i++) {
      _stayPins[days[i]] = added[i];
    }
  }

  bool _same(Symbol a, Symbol b) => a == b || a.id == b.id;

  void _onSymbolTapped(Symbol symbol) {
    for (final e in _stayPins.entries) {
      if (_same(e.value, symbol)) {
        if (_stayPinOpacity(e.key) > 0) _select(e.key);
        return;
      }
    }
    for (final e in _badges.entries) {
      if (_same(e.value, symbol)) {
        final day = _plan.plan.value?.legStart(e.key) ?? 0;
        if (day >= 1 && _segOpacity(e.key) > 0) _select(day);
        return;
      }
    }
    for (final e in _cityLabels.entries) {
      if (_same(e.value, symbol)) {
        _selectLeg(e.key);
        return;
      }
    }
    for (final e in _symbols.entries) {
      final i = e.value.indexWhere((x) => _same(x, symbol));
      if (i >= 0) {
        _openPlanned(e.key, i);
        return;
      }
    }
  }

  void _onCircleTapped(Circle circle) {
    for (final e in _cityDots.entries) {
      if (e.value == circle || e.value.id == circle.id) {
        _selectLeg(e.key);
        return;
      }
    }
    for (final e in _circles.entries) {
      final i = e.value.indexWhere((x) => x == circle || x.id == circle.id);
      if (i >= 0) {
        _openPlanned(e.key, i);
        return;
      }
    }
  }

  void _openPlanned(int day, int index) {
    final disc = _disc;
    final spots = _spotsOf(day);
    if (disc == null || !disc.isAttached || index >= spots.length || _dayOpacity(day) <= 0) return;
    final s = spots[index];
    disc
        .select(
          s.id,
          planned: true,
          spot: DiscoverySpot(
            id: s.id,
            lat: s.latitude,
            lon: s.longitude,
            category: s.category,
            rank: 0,
            name: s.name,
            cityKey: _plan.plan.value?.legAt(_plan.legIndexOf(day))?.cityKey,
            thumbUrl: s.imageUrl,
          ),
        )
        .ignore();
  }

  static Future<Uint8List> _buildStayPinImage() =>
      _buildPinImage(TravelPalette.sunriseStart, 'camping', size: 48, radius: 19, glyphSize: 22);

  static Future<Uint8List> _buildCarPinImage() =>
      _buildPinImage(TravelPalette.roseEnd, 'taxi', size: 40, radius: 16, glyphSize: 19);

  static Future<Uint8List> _buildPinImage(
    Color fill,
    String asset, {
    required double size,
    required double radius,
    required double glyphSize,
  }) async {
    final c = size / 2, r = radius;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
    canvas.drawCircle(
      Offset(c, c + 1.5),
      r + 1,
      Paint()
        ..color = FitnessAppTheme.grey.withValues(alpha: Alpha.scrim)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(Offset(c, c), r, Paint()..color = fill);
    canvas.drawCircle(
      Offset(c, c),
      r,
      Paint()
        ..color = FitnessAppTheme.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final data = await rootBundle.load('assets/images/design/travel3d/$asset.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final glyph = (await codec.getNextFrame()).image;
    canvas.drawImageRect(
      glyph,
      Rect.fromLTWH(0, 0, glyph.width.toDouble(), glyph.height.toDouble()),
      Rect.fromCenter(center: Offset(c, c), width: glyphSize, height: glyphSize),
      Paint()..filterQuality = FilterQuality.high,
    );
    final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
    return bytes.buffer.asUint8List();
  }

  String _sourceId(int day) => 'trip-route-$day';

  TripSpotRef? _nextDayStart(int day) {
    final own = _spotsOf(day);
    final next = _spotsOf(day + 1);
    if (own.isEmpty || next.isEmpty || _plan.legIndexOf(day + 1) != _plan.legIndexOf(day)) return null;
    return next.first;
  }

  Map<String, dynamic> _source(int day) {
    final route = _plan.routeFor(day);
    final link = _nextDayStart(day);
    final own = _spotsOf(day);
    final geometry = route ??
        <String, dynamic>{
          'type': 'LineString',
          'coordinates': [
            for (final s in own) [s.longitude, s.latitude],
            if (link != null) [link.longitude, link.latitude],
          ],
        };
    final coords = geometry['coordinates'];
    final valid = coords is List && coords.length >= 2;
    return {
      'type': 'FeatureCollection',
      'features': [
        if (valid) {'type': 'Feature', 'properties': <String, dynamic>{}, 'geometry': geometry},
        if (route != null && link != null)
          {
            'type': 'Feature',
            'properties': <String, dynamic>{},
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [own.last.longitude, own.last.latitude],
                [link.longitude, link.latitude],
              ],
            },
          },
      ],
    };
  }

  LineLayerProperties _lineProps(int day, {required bool glow}) {
    final selected = _isSelected(day);
    final hidden = !selected && _hidesOtherLegs;
    final color = TripKit.hexOf(_routeColor(day));
    if (glow) {
      return LineLayerProperties(
          lineColor: color, lineWidth: 8, lineOpacity: hidden ? 0 : (selected ? 0.18 : 0.05), lineBlur: 3);
    }
    return LineLayerProperties(
      lineColor: color,
      lineWidth: DS.s(8),
      lineCap: 'round',
      lineJoin: 'round',
      lineOpacity: hidden ? 0 : (selected ? (_lighterDays ? 0.6 : 1) : 0.25),
      lineDasharray: _hasRoute[day] == true ? null : [2, 2],
    );
  }

  String _segId(int legIndex) => 'trip-seg-$legIndex';

  Map<String, dynamic> _segSource(List<LatLng>? line) => {
        'type': 'FeatureCollection',
        'features': [
          if (line != null && line.length >= 2)
            {
              'type': 'Feature',
              'properties': <String, dynamic>{},
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  for (final pt in line) [pt.longitude, pt.latitude],
                ],
              },
            },
        ],
      };

  LineLayerProperties _segProps(int legIndex, {required bool glow}) {
    final on = _plan.mapShowsSegment(legIndex);
    final hidden = !on && _hidesOtherLegs;
    final color = TripKit.hexOf(TravelPalette.roseEnd);
    if (glow) {
      return LineLayerProperties(
          lineColor: color, lineWidth: 8, lineOpacity: hidden ? 0 : (on ? 0.18 : 0.05), lineBlur: 3);
    }
    return LineLayerProperties(
        lineColor: color,
        lineWidth: 4,
        lineOpacity: hidden ? 0 : (on ? 0.9 : 0.25),
        lineDasharray: _plan.segmentHasRoad(legIndex) ? null : [2, 2]);
  }

  String _badgeText(TripCityLeg leg) {
    final a = leg.arrival!;
    final cars = a.cars ?? _plan.segmentJourney(leg.index)?.legs.length ?? 1;
    final via = [for (final v in _plan.segmentViaCities(leg.index)) v.name];
    return [
      TripStringsStepsA3.carsLine(cars < 1 ? 1 : cars),
      if (via.isNotEmpty) TripStringsCity.viaLine(via),
      if (!_plan.segmentHasRoad(leg.index)) TripStringsCity.roadLineMissing,
    ].join('\n');
  }

  Future<void> _drawLegs(MapLibreMapController map, TripPlan p, String? below) async {
    final citiesOn = _citiesOn;
    final circleOpts = <CircleOptions>[];
    final circleSlots = <void Function(Circle)>[];
    final symbolOpts = <SymbolOptions>[];
    final symbolSlots = <void Function(Symbol)>[];
    for (final leg in p.legs) {
      final k = leg.index;
      if (k >= 2) {
        final line = _plan.segmentLine(k);
        final opacity = _segOpacity(k);
        final id = _segId(k);
        await map.addGeoJsonSource(id, _segSource(line));
        await _addLine(map, id, '$id-glow', _segProps(k, glow: true), below);
        await _addLine(map, id, '$id-line', _segProps(k, glow: false), below);
        _drawnSegs.add(k);
        if (leg.arrival != null && line != null && line.length >= 2 && _carPinReady) {
          symbolSlots.add((s) => _badges[k] = s);
          symbolOpts.add(SymbolOptions(
            geometry: TripMapGeo.midpointByLength(line),
            iconImage: _carPinImage,
            iconSize: 1,
            iconOpacity: opacity,
            textField: _badgeText(leg),
            fontNames: const ['Noto Sans Medium'],
            textSize: 11,
            textAnchor: 'top',
            textOffset: const Offset(0, 1.6),
            textColor: _travelText,
            textHaloColor: _white,
            textHaloWidth: 1,
            textOpacity: opacity,
            zIndex: 9,
          ));
        }
        for (final v in _plan.segmentViaCities(k)) {
          circleSlots.add((x) => _changeDots.putIfAbsent(k, () => <Circle>[]).add(x));
          circleOpts.add(CircleOptions(
            geometry: v.at,
            circleRadius: 4,
            circleColor: _white,
            circleOpacity: opacity,
            circleStrokeColor: _changeStroke,
            circleStrokeWidth: 2,
            circleStrokeOpacity: opacity,
          ));
          symbolSlots.add((x) => _changeLabels.putIfAbsent(k, () => <Symbol>[]).add(x));
          symbolOpts.add(SymbolOptions(
            geometry: v.at,
            textField: v.name,
            fontNames: const ['Noto Sans Medium'],
            textSize: 9,
            textAnchor: 'left',
            textOffset: const Offset(0.9, 0),
            textColor: _changeText,
            textHaloColor: _white,
            textHaloWidth: 1.5,
            textOpacity: opacity,
            zIndex: 7,
          ));
        }
        for (final c in _plan.segmentChangePlaces(k)) {
          circleSlots.add((x) => _changeDots.putIfAbsent(k, () => <Circle>[]).add(x));
          circleOpts.add(CircleOptions(
            geometry: c.at,
            circleRadius: 7,
            circleColor: _white,
            circleOpacity: opacity,
            circleStrokeColor: _changeStroke,
            circleStrokeWidth: 3,
            circleStrokeOpacity: opacity,
          ));
          symbolSlots.add((x) => _changeLabels.putIfAbsent(k, () => <Symbol>[]).add(x));
          symbolOpts.add(SymbolOptions(
            geometry: c.at,
            textField: c.name,
            fontNames: const ['Noto Sans Medium'],
            textSize: 10,
            textAnchor: 'left',
            textOffset: const Offset(1.1, 0),
            textColor: _changeText,
            textHaloColor: _white,
            textHaloWidth: 1.5,
            textOpacity: opacity,
            zIndex: 8,
          ));
        }
      }
      if (!leg.hasPoint || leg.cityName.isEmpty) continue;
      final at = LatLng(leg.latitude, leg.longitude);
      circleSlots.add((x) => _cityDots[k] = x);
      circleOpts.add(CircleOptions(
        geometry: at,
        circleRadius: 7,
        circleColor: TripKit.hexOf(FitnessAppTheme.nearlyDarkBlue),
        circleOpacity: citiesOn ? 1 : 0.35,
        circleStrokeColor: _white,
        circleStrokeWidth: 2,
      ));
      symbolSlots.add((x) => _cityLabels[k] = x);
      symbolOpts.add(SymbolOptions(
        geometry: at,
        textField: leg.cityName,
        fontNames: const ['Noto Sans Medium'],
        textSize: 11,
        textAnchor: 'top',
        textOffset: const Offset(0, 0.9),
        textColor: _cityText,
        textHaloColor: _white,
        textHaloWidth: 1,
        textOpacity: citiesOn ? 1 : 0.35,
        zIndex: 8,
      ));
    }
    if (circleOpts.isNotEmpty) {
      final added = await map.addCircles(circleOpts);
      for (var i = 0; i < added.length; i++) {
        circleSlots[i](added[i]);
      }
    }
    if (symbolOpts.isNotEmpty) {
      final added = await map.addSymbols(symbolOpts);
      for (var i = 0; i < added.length; i++) {
        symbolSlots[i](added[i]);
      }
    }
  }

  Future<void> _addLine(MapLibreMapController map, String source, String id, LineLayerProperties props, String? below) async {
    await map.addLineLayer(source, id, props, belowLayerId: below, enableInteraction: false);
    _lineKeys[id] = _lineKey(props);
  }

  static String _lineKey(LineLayerProperties p) => '${p.lineOpacity}|${p.lineDasharray}';

  Future<void> _setLine(MapLibreMapController map, String id, LineLayerProperties props) async {
    final key = _lineKey(props);
    if (_lineKeys[id] == key) return;
    _lineKeys[id] = key;
    await map.setLayerProperties(id, props);
  }

  Future<void> _setCircles(MapLibreMapController map, List<(Circle, CircleOptions)> changes) async {
    final changed = <Circle>[];
    for (final (c, o) in changes) {
      final next = c.options.copyWith(o);
      if (next.circleOpacity == c.options.circleOpacity && next.circleStrokeOpacity == c.options.circleStrokeOpacity) {
        continue;
      }
      c.options = next;
      changed.add(c);
    }
    if (changed.isNotEmpty) await map.circleManager?.addAll(changed);
  }

  Future<void> _setSymbols(MapLibreMapController map, List<(Symbol, SymbolOptions)> changes) async {
    final changed = <Symbol>[];
    for (final (s, o) in changes) {
      final next = s.options.copyWith(o);
      if (next.iconOpacity == s.options.iconOpacity &&
          next.textOpacity == s.options.textOpacity &&
          next.textField == s.options.textField) {
        continue;
      }
      s.options = next;
      changed.add(s);
    }
    if (changed.isNotEmpty) await map.symbolManager?.addAll(changed);
  }

  Future<void> _redraw(MapLibreMapController map, TripPlan p) async {
    for (final d in _drawnDays) {
      await map.removeLayer('${_sourceId(d)}-line');
      await map.removeLayer('${_sourceId(d)}-glow');
      await map.removeSource(_sourceId(d));
    }
    for (final k in _drawnSegs) {
      await map.removeLayer('${_segId(k)}-line');
      await map.removeLayer('${_segId(k)}-glow');
      await map.removeSource(_segId(k));
    }
    _drawnDays.clear();
    _drawnSegs.clear();
    _cityDots.clear();
    _cityLabels.clear();
    _badges.clear();
    _changeDots.clear();
    _changeLabels.clear();
    _circles.clear();
    _symbols.clear();
    _hasRoute.clear();
    _drawnRoutes.clear();
    _lineKeys.clear();
    _stayPins.clear();
    await map.clearCircles();
    await map.clearSymbols();
    final below = _disc?.isAttached == true ? DiscIds.layerPhoto : map.circleManager?.layerIds.first;
    final circleOpts = <CircleOptions>[];
    final symbolOpts = <SymbolOptions>[];
    final spotDays = <int>[];
    var stopNo = 0;
    for (final day in p.days) {
      final d = day.day;
      final opacity = _dayOpacity(d);
      final color = TripKit.hexOf(_routeColor(d));
      final route = _plan.routeFor(d);
      _hasRoute[d] = route != null;
      _drawnRoutes[d] = route;
      await map.addGeoJsonSource(_sourceId(d), _source(d));
      await _addLine(map, _sourceId(d), '${_sourceId(d)}-glow', _lineProps(d, glow: true), below);
      await _addLine(map, _sourceId(d), '${_sourceId(d)}-line', _lineProps(d, glow: false), below);
      for (var i = 0; i < day.spots.length; i++) {
        final s = day.spots[i];
        final at = LatLng(s.latitude, s.longitude);
        spotDays.add(d);
        circleOpts.add(CircleOptions(
          geometry: at,
          circleRadius: DS.s(22.5),
          circleColor: color,
          circleOpacity: opacity,
          circleStrokeWidth: 0,
        ));
        stopNo++;
        symbolOpts.add(SymbolOptions(
          geometry: at,
          textField: '$stopNo',
          fontNames: const ['Noto Sans Medium'],
          textSize: DS.f(21),
          textColor: _white,
          textOpacity: opacity,
        ));
      }
      _circles[d] = <Circle>[];
      _symbols[d] = <Symbol>[];
      _drawnDays.add(d);
    }
    if (circleOpts.isNotEmpty) {
      final circles = await map.addCircles(circleOpts);
      final symbols = await map.addSymbols(symbolOpts);
      for (var i = 0; i < spotDays.length; i++) {
        _circles[spotDays[i]]!.add(circles[i]);
        _symbols[spotDays[i]]!.add(symbols[i]);
      }
    }
    if (p.isMultiCity) await _drawLegs(map, p, below);
    await _drawStayPins(map, p);
    await _disc?.setPlannedIds({for (final s in p.allSpots) s.id});
  }

  Future<void> _applySelection() async {
    final map = _map;
    if (map == null) return;
    final circles = <(Circle, CircleOptions)>[];
    final symbols = <(Symbol, SymbolOptions)>[];
    for (final d in _drawnDays) {
      final opacity = _dayOpacity(d);
      await _setLine(map, '${_sourceId(d)}-glow', _lineProps(d, glow: true));
      await _setLine(map, '${_sourceId(d)}-line', _lineProps(d, glow: false));
      for (final c in _circles[d] ?? const <Circle>[]) {
        circles.add((c, CircleOptions(circleOpacity: opacity, circleStrokeOpacity: _ringOpacity(opacity))));
      }
      for (final s in _symbols[d] ?? const <Symbol>[]) {
        symbols.add((s, SymbolOptions(textOpacity: opacity)));
      }
    }
    final p = _plan.plan.value;
    for (final e in _stayPins.entries) {
      final opacity = _stayPinOpacity(e.key);
      symbols.add((
        e.value,
        SymbolOptions(iconOpacity: opacity, textOpacity: opacity, textField: p == null ? null : _stayPinText(p, e.key)),
      ));
    }
    for (final k in _drawnSegs) {
      final opacity = _segOpacity(k);
      await _setLine(map, '${_segId(k)}-glow', _segProps(k, glow: true));
      await _setLine(map, '${_segId(k)}-line', _segProps(k, glow: false));
      final badge = _badges[k];
      if (badge != null) symbols.add((badge, SymbolOptions(iconOpacity: opacity, textOpacity: opacity)));
      for (final c in _changeDots[k] ?? const <Circle>[]) {
        circles.add((c, CircleOptions(circleOpacity: opacity, circleStrokeOpacity: opacity)));
      }
      for (final s in _changeLabels[k] ?? const <Symbol>[]) {
        symbols.add((s, SymbolOptions(textOpacity: opacity)));
      }
    }
    final cityOpacity = _citiesOn ? 1.0 : 0.35;
    for (final c in _cityDots.values) {
      circles.add((c, CircleOptions(circleOpacity: cityOpacity)));
    }
    for (final s in _cityLabels.values) {
      symbols.add((s, SymbolOptions(textOpacity: cityOpacity)));
    }
    await _setCircles(map, circles);
    await _setSymbols(map, symbols);
  }

  double _overlayHeight(GlobalKey key, double fallback) {
    final box = key.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize && box.size.height > 0) return box.size.height;
    return fallback;
  }

  Future<void> _fitCamera() async {
    final map = _map;
    final p = _plan.plan.value;
    if (map == null || p == null || !mounted) return;
    final box = TripMapGeo.bounds([
      ..._plan.mapFocusPoints(),
      for (final d in p.days)
        if (_plan.mapShowsDay(d.day)) ...TripMapGeo.geometryPoints(_plan.routeFor(d.day)),
    ]);
    if (box == null) return;
    final minLat = box.southwest.latitude, maxLat = box.northeast.latitude;
    final minLng = box.southwest.longitude, maxLng = box.northeast.longitude;
    if (maxLat - minLat < 0.0005 && maxLng - minLng < 0.0005) {
      await map.animateCamera(CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 14));
      return;
    }
    final size = MediaQuery.sizeOf(context);
    var top = _overlayHeight(_topKey, DS.s(120)) + DS.s(24);
    var bottom = DS.s(24);
    final room = size.height - DS.s(120);
    if (top + bottom > room && room > 0) {
      final scale = room / (top + bottom);
      top *= scale;
      bottom *= scale;
    }
    final side = min(DS.s(48), size.width * 0.12);
    await map.animateCamera(CameraUpdate.newLatLngBounds(
      box,
      left: side,
      top: top,
      right: side,
      bottom: bottom,
    ));
  }

  Future<void> _select(int day) async {
    if (day == _selected && _plan.selectedMapLeg.value == 0) return;
    _dayPicked = true;
    if (day == TripDayChips.all) {
      _plan.selectMapAll();
    } else {
      _plan.selectMapDay(day);
    }
    await _refocus();
  }

  Future<void> _selectLeg(int legIndex) async {
    if (legIndex == _plan.selectedMapLeg.value) return;
    _dayPicked = true;
    _plan.selectMapLeg(legIndex);
    await _refocus();
  }

  Future<void> _refocus() async {
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
                minMaxZoomPreference: _wideZoom ? _multiCityZoom : _oneCityZoom(context),
                compassEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                myLocationEnabled: false,
                trackCameraPosition: false,
                dragEnabled: false,
                scaleControlEnabled: _disc != null,
                scaleControlPosition: ScaleControlPosition.bottomRight,
                scaleControlUnit: ScaleControlUnit.metric,
                onMapClick: (point, _) => _disc?.onMapTap(point.x, point.y),
                attributionButtonMargins: const Point(-200.0, 0.0),
                annotationOrder: const [AnnotationType.circle, AnnotationType.symbol],
                onMapCreated: (MapLibreMapController ctrl) {
                  _map = ctrl;
                  ctrl.onSymbolTapped.add(_onSymbolTapped);
                  ctrl.onCircleTapped.add(_onCircleTapped);
                },
                onStyleLoadedCallback: _onStyleLoaded,
              ),
            ),
          ),
          Positioned.fill(
            child: Obx(() {
              _plan.trip.value;
              final opening = (_plan.isOpening.value && _plan.plan.value == null) || _waitingForTrip;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.fastOutSlowIn,
                switchOutCurve: Curves.fastOutSlowIn,
                child: !_styleLoaded || opening
                    ? KeyedSubtree(key: const ValueKey('wait'), child: _buildMapPlaceholder())
                    : const IgnorePointer(key: ValueKey('ready'), child: SizedBox.shrink()),
              );
            }),
          ),
          Positioned.fill(child: _buildState()),
          if (_disc != null) DiscoveryOverlay(layer: _disc!, mode: DiscoveryMode.full, map: () => _map, onLocate: () => DiscoveryCamera.toUser(_map, limits: _wideZoom ? _multiCityZoom : _oneCityZoom(context)), notice: () => _plan.offline.value ? TripStringsV2Plan.offlineBanner : null, dayColorOf: _routeColor),
          Positioned(left: 0, right: 0, top: 0, child: KeyedSubtree(key: _topKey, child: _buildTop(context))),
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder() => const SizedBox.expand(child: TemplatePlaceholder(height: double.infinity, radius: 0));

  Widget _buildTop(BuildContext context) {
    return Obx(() {
      _plan.result.value;
      final p = _plan.plan.value;
      final selected = _selected;
      final leg = _plan.selectedMapLeg.value;
      final missing = p != null &&
          !_plan.plannerOff.value &&
          (selected != TripDayChips.all
              ? _dayRouteMissing(selected)
              : p.days.any((d) => (leg == 0 || p.legIndexOf(d.day) == leg) && _dayRouteMissing(d.day)));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: TripFlowHeader(
              title: TripStringsV2Plan.map,
              subtitle: TripStringsDayplan.mapRouteSub,
              onBack: () => Get.back(),
              trailing: [if (p != null && p.days.length > 1) ...[Gap.h(12), _dayMenu(p)]],
            ),
          ),
          if (missing)
            Padding(
              padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(8), DS.s(18), 0),
              child: Align(alignment: Alignment.centerLeft, child: _routeMissingChip()),
            ),
        ],
      );
    });
  }

  Widget _dayMenu(TripPlan p) {
    return PopupMenuButton<int>(
      padding: EdgeInsets.zero,
      color: DesignColors.surface,
      shape: RoundedRectangleBorder(borderRadius: DS.circular(20)),
      offset: Offset(0, DS.s(48)),
      onSelected: _select,
      itemBuilder: (_) => [
        PopupMenuItem(value: TripDayChips.all, child: Text(TripStringsV2Plan.allCities, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0))),
        for (final d in p.days)
          PopupMenuItem(
            value: d.day,
            child: Row(
              children: [
                Container(width: DS.s(12), height: DS.s(12), decoration: BoxDecoration(color: _routeColor(d.day), shape: BoxShape.circle)),
                Gap.h(10),
                Text(TripStringsDayplan.dayLabel(d.day), style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
              ],
            ),
          ),
      ],
      child: TripMenuDots.box(),
    );
  }

  Widget _routeMissingChip() {
    return Container(
      padding: DS.sym(h: 12, v: 7),
      decoration: BoxDecoration(
        color: ListingTone.indigo.tint,
        borderRadius: DS.br(CardRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: DS.s(14), color: DesignColors.amber),
          Gap.h(6),
          Flexible(
            child: Text(
              TripStrings.routeMissing,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: DS.f(11), fontWeight: FontWeight.w600, color: FitnessAppTheme.darkText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildState() {
    return Obx(() {
      final off = _plan.plannerOff.value;
      final failed = _plan.openFailed.value;
      final gone = _plan.tripGone.value;
      if (!off && !failed && !gone) return const IgnorePointer(child: SizedBox.shrink());
      return Container(
        color: DesignColors.scaffold,
        alignment: Alignment.topCenter,
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + DS.s(150)),
        child: gone
            ? const TripNotFoundView()
            : off
            ? StateCard3D(
                tone: ListingTone.indigo,
                art: ListingArt.compass,
                layout: StateLayout.plain,
                title: TripStrings.plannerOff,
                message: TripStrings.plannerOffSubtitle,
              )
            : StateCard3D(
                tone: ListingTone.indigo,
                art: ListingArt.worldMap,
                layout: StateLayout.plain,
                title: TripStrings.tripFailed,
                message: TripStrings.checkConnection,
                actionLabel: TripStrings.retry,
                onAction: _plan.retryOpen,
              ),
      );
    });
  }
}
