import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_constants.dart';
import '../../../config/app_shadows.dart';
import '../controllers/trip_spots_controller.dart';
import '../models/trip_spot_category.dart';
import '../models/trip_spot_model.dart';
import '../trip_colors.dart';
import '../trip_strings_x3.dart';
import '../utils/trip_spots_map_rules.dart';
import 'trip_spot_row.dart';

class TripSpotsMapView extends StatefulWidget {
  final TripSpotsController controller;
  final void Function(TripSpotModel) onOpen;

  const TripSpotsMapView({super.key, required this.controller, required this.onOpen});

  @override
  State<TripSpotsMapView> createState() => _TripSpotsMapViewState();
}

class _TripSpotsMapViewState extends State<TripSpotsMapView> {
  static const double _photoSize = 56;
  static const double _iconSize = 44;

  MapLibreMapController? _map;
  bool _styleLoaded = false;
  bool _busy = false;
  bool _again = false;
  final _workers = <Worker>[];
  final _symbols = <String, Symbol>{};
  final _registered = <String>{};
  final _photoFailed = <String>{};
  final _photoBytes = <String, Uint8List>{};
  String? _fitSignature;
  String? _cardId;
  int _shown = 0;

  TripSpotsController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _workers.addAll([
      ever(_c.selected, (_) => _sync()),
      ever(_c.items, (_) => _sync()),
      ever(_c.filter, (_) => _sync()),
    ]);
  }

  @override
  void dispose() {
    for (final w in _workers) {
      w.dispose();
    }
    _map?.onSymbolTapped.remove(_onSymbolTapped);
    super.dispose();
  }

  LatLng _initialTarget() {
    final first = _c.items.isEmpty ? null : _c.items.first;
    if (first != null) return LatLng(first.latitude, first.longitude);
    return const LatLng(AppConstants.fallbackLat, AppConstants.fallbackLng);
  }

  Future<void> _onStyleLoaded() async {
    final map = _map;
    if (map == null || _styleLoaded) return;
    await map.setSymbolIconAllowOverlap(true);
    await map.setSymbolIconIgnorePlacement(true);
    if (!mounted) return;
    _styleLoaded = true;
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
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  Future<void> _syncOnce() async {
    final map = _map;
    if (!mounted || map == null || !_styleLoaded) return;
    final order = _c.selected.toList();
    final pins = TripSpotsMapRules.pickPins(all: _c.items.toList(), visible: _c.visible, selectedOrder: order);
    final names = <String>[];
    for (final s in pins) {
      names.add(await _ensureImage(map, s, order));
    }
    if (!mounted || _map == null) return;
    if (_symbols.isNotEmpty) {
      final old = _symbols.values.toList();
      _symbols.clear();
      await map.removeSymbols(old);
    }
    if (pins.isEmpty) {
      if (mounted) setState(() => _shown = 0);
      return;
    }
    final added = await map.addSymbols([
      for (var i = 0; i < pins.length; i++)
        SymbolOptions(
          geometry: LatLng(pins[i].latitude, pins[i].longitude),
          iconImage: names[i],
          iconSize: 1,
          zIndex: order.contains(pins[i].id) ? 10 : 1,
        ),
    ]);
    for (var i = 0; i < added.length && i < pins.length; i++) {
      _symbols[pins[i].id] = added[i];
    }
    if (!mounted) return;
    setState(() => _shown = pins.length);
    await _fit(map, pins);
  }

  Future<void> _fit(MapLibreMapController map, List<TripSpotModel> pins) async {
    final sig = _c.filter.value ?? '';
    if (_fitSignature == sig) return;
    _fitSignature = sig;
    if (pins.length == 1) {
      await map.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pins.first.latitude, pins.first.longitude), 13));
      return;
    }
    var minLat = pins.first.latitude, maxLat = minLat, minLng = pins.first.longitude, maxLng = minLng;
    for (final s in pins) {
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
      left: 40,
      top: 40,
      right: 40,
      bottom: 140,
    ));
  }

  Future<String> _ensureImage(MapLibreMapController map, TripSpotModel s, List<String> order) async {
    final n = TripSpotsMapRules.numberOf(order, s.id);
    final String name;
    final Future<Uint8List> Function() build;
    if (n > 0) {
      name = 'tsel_$n';
      build = () => _numberPin(n);
    } else if (s.hasPhoto && !_photoFailed.contains(s.id)) {
      name = 'tph_${s.id}';
      build = () async {
        final cached = _photoBytes[s.id];
        if (cached != null) return cached;
        final img = await _loadPhoto(s.gallery.first);
        if (img == null) throw StateError('photo');
        final bytes = await _photoPin(img);
        _photoBytes[s.id] = bytes;
        return bytes;
      };
    } else {
      name = 'tcat_${s.category}';
      build = () => _iconPin(s.category);
    }
    if (_registered.contains(name)) return name;
    try {
      await map.addImage(name, await build());
      _registered.add(name);
      return name;
    } catch (_) {
      if (n > 0 || !s.hasPhoto) rethrow;
      _photoFailed.add(s.id);
      final fallback = 'tcat_${s.category}';
      if (!_registered.contains(fallback)) {
        await map.addImage(fallback, await _iconPin(s.category));
        _registered.add(fallback);
      }
      return fallback;
    }
  }

  static Future<ui.Image?> _loadPhoto(String url) {
    final done = Completer<ui.Image?>();
    final stream = CachedNetworkImageProvider(url, maxWidth: 160).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!done.isCompleted) done.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (_, _) {
        if (!done.isCompleted) done.complete(null);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return done.future.timeout(const Duration(seconds: 6), onTimeout: () {
      stream.removeListener(listener);
      return null;
    });
  }

  static Future<Uint8List> _finish(ui.PictureRecorder recorder, double size) async {
    final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
    return bytes.buffer.asUint8List();
  }

  static void _shadow(Canvas canvas, double size, double r, Color fill) {
    final c = size / 2;
    canvas.drawCircle(
      Offset(c, c + 1.5),
      r + 1,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(Offset(c, c), r, Paint()..color = fill);
  }

  static void _border(Canvas canvas, double size, double r) {
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  static Future<Uint8List> _photoPin(ui.Image img) async {
    const size = _photoSize;
    const r = size / 2 - 4;
    const center = Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    _shadow(canvas, size, r, Colors.white);
    final side = min(img.width, img.height).toDouble();
    final src = Rect.fromLTWH((img.width - side) / 2, (img.height - side) / 2, side, side);
    final dst = Rect.fromCircle(center: center, radius: r);
    canvas.save();
    canvas.clipPath(Path()..addOval(dst));
    canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.medium);
    canvas.restore();
    _border(canvas, size, r);
    return _finish(recorder, size);
  }

  static Future<Uint8List> _iconPin(String category) async {
    const size = _iconSize;
    const r = size / 2 - 5;
    final icon = TripSpotCategory.iconOf(category);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    _shadow(canvas, size, r, TripSpotCategory.colorOf(category));
    _border(canvas, size, r);
    final glyph = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: 19, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    glyph.paint(canvas, Offset((size - glyph.width) / 2, (size - glyph.height) / 2));
    return _finish(recorder, size);
  }

  static Future<Uint8List> _numberPin(int n) async {
    const size = _iconSize;
    const r = size / 2 - 5;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    _shadow(canvas, size, r, TripColors.accent);
    _border(canvas, size, r);
    final label = TextPainter(
      text: TextSpan(
        text: '$n',
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset((size - label.width) / 2, (size - label.height) / 2));
    return _finish(recorder, size);
  }

  void _onSymbolTapped(Symbol symbol) {
    for (final e in _symbols.entries) {
      if (e.value == symbol || e.value.id == symbol.id) {
        setState(() => _cardId = e.key);
        return;
      }
    }
  }

  TripSpotModel? _cardSpot() {
    final id = _cardId;
    if (id == null) return null;
    for (final s in _c.items) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: MapLibreMap(
              styleString: 'assets/map_style.json',
              initialCameraPosition: CameraPosition(target: _initialTarget(), zoom: 11),
              compassEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              myLocationEnabled: false,
              attributionButtonMargins: const Point(-200.0, 0.0),
              onMapCreated: (ctrl) {
                _map = ctrl;
                ctrl.onSymbolTapped.add(_onSymbolTapped);
              },
              onMapClick: (_, _) {
                if (_cardId != null) setState(() => _cardId = null);
              },
              onStyleLoadedCallback: _onStyleLoaded,
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: 10,
          child: Obx(() {
            final total = _c.filter.value == null ? _c.items.length : _c.visible.length;
            if (total <= TripSpotsMapRules.maxPins || _shown == 0) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration:
                  BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(999)),
              child: Text(
                TripStringsX3.pinsCapped(_shown, total),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Colors.white),
              ),
            );
          }),
        ),
        Positioned(left: 12, right: 12, bottom: 12, child: _buildCard()),
      ],
    );
  }

  Widget _buildCard() {
    final spot = _cardSpot();
    if (spot == null) return const SizedBox.shrink();
    final area = spot.area;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onOpen(spot),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.premium(TripColors.accent, alpha: 0.18, blur: 14, offset: const Offset(0, 4)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 64, height: 64, child: TripSpotMedia(spot: spot)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    spot.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  Text(
                    [TripSpotCategory.label(spot.category), if (area != null && area.isNotEmpty) area].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Obx(() {
              final selected = _c.selected.contains(spot.id);
              return TripSpotAddButton(
                selected: selected,
                locked: _c.atLimit,
                onTap: () => _c.toggle(spot.id),
              );
            }),
          ],
        ),
      ),
    );
  }
}
