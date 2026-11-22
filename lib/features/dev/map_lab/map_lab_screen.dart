import 'dart:async';

import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'map_lab_port.dart';
import 'map_lab_spikes.dart';

class MapLabScreen extends StatefulWidget {
  const MapLabScreen({super.key});

  @override
  State<MapLabScreen> createState() => _MapLabScreenState();
}

class _MapLabScreenState extends State<MapLabScreen> {
  final GlobalKey _mapKey = GlobalKey();
  MapLibreMapController? _map;
  MapLabSpikes? _spikes;
  bool _styleReady = false;
  bool _busy = false;
  final List<String> _results = [];
  final List<String> _logs = [];

  Size _viewport() => (_mapKey.currentContext?.size) ?? Size.zero;

  void _log(String line) {
    if (!mounted) return;
    setState(() => _logs.insert(0, line));
  }

  Future<FrameStats> _record(Future<void> Function() action) async {
    final micros = <int>[];
    void cb(List<FrameTiming> t) => micros.addAll(t.map((e) => e.totalSpan.inMicroseconds));
    SchedulerBinding.instance.addTimingsCallback(cb);
    try {
      await action();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(cb);
    }
    return FrameStats.fromMicros(micros);
  }

  void _onCreated(MapLibreMapController c) {
    _map = c;
    c.onFeatureTapped.add((point, latLng, id, layerId, annotation) {
      _spikes?.noteTap(id, layerId, point.x, point.y);
    });
  }

  void _onStyle() {
    final c = _map;
    if (c == null || !mounted) return;
    final spikes = MapLabSpikes(
      MapLibreLabPort(c, _viewport, () => MediaQuery.devicePixelRatioOf(context)),
      _record,
      _log,
    );
    setState(() {
      _spikes = spikes;
      _styleReady = true;
    });
  }

  Future<void> _run(Future<List<LabResult>> Function(MapLabSpikes s) job) async {
    final s = _spikes;
    if (s == null || _busy) return;
    setState(() => _busy = true);
    try {
      final out = await job(s);
      if (!mounted) return;
      setState(() => _results.insertAll(0, out.reversed.map((e) => e.toText())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _one(Future<LabResult> Function(MapLabSpikes s) run) =>
      _run((s) async => [await s.guarded(() => run(s))]);

  @override
  void dispose() {
    unawaited(_spikes?.port.clear());
    super.dispose();
  }

  Widget _btn(String label, Future<void> Function() onTap) => FilledButton.tonal(
        onPressed: _styleReady && !_busy ? onTap : null,
        child: Text(label),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Map lab (debug)')),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                MapLibreMap(
                  key: _mapKey,
                  styleString: 'assets/map_style.json',
                  initialCameraPosition: const CameraPosition(target: LatLng(LabCentre.lat, LabCentre.lon), zoom: LabCentre.zoom),
                  compassEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  myLocationEnabled: false,
                  onMapCreated: _onCreated,
                  onStyleLoadedCallback: _onStyle,
                ),
                Center(
                  child: IgnorePointer(
                    child: Container(
                      width: DS.s(100),
                      height: DS.s(100),
                      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 6,
            child: ListView(
              padding: EdgeInsets.all(DS.s(8)),
              children: [
                Wrap(
                  spacing: DS.s(6),
                  runSpacing: DS.s(2),
                  children: [
                    _btn('1 Feature id', () => _one((s) => s.featureIdRoundTrip())),
                    _btn('2 Declutter', () => _one((s) => s.declutter())),
                    _btn('3 Pixel density', () => _one((s) => s.pixelDensity())),
                    _btn('4 addImage x40', () => _one((s) => s.addImageTiming())),
                    _btn('5 1,500 pts pan', () => _one((s) => s.frameTime())),
                    _btn('6 Tap box', () => _one((s) => s.tapBox())),
                    _btn('7 File source', () => _one((s) => s.fileSource())),
                    _btn('Run all', () => _run((s) => s.runAll())),
                    _btn('Clear map', () async => _spikes?.port.clear()),
                    OutlinedButton(
                      onPressed: _results.isEmpty && _logs.isEmpty
                          ? null
                          : () => Clipboard.setData(ClipboardData(text: [..._results.reversed, ..._logs.reversed].join('\n\n'))),
                      child: const Text('Copy results'),
                    ),
                  ],
                ),
                if (!_styleReady) Text('Waiting for the map style...', style: text.bodySmall),
                if (_busy) const LinearProgressIndicator(),
                for (final r in _results)
                  Padding(
                    padding: EdgeInsets.only(top: DS.s(8)),
                    child: SelectableText(r, style: text.bodySmall),
                  ),
                if (_logs.isNotEmpty) ...[
                  Padding(padding: EdgeInsets.only(top: DS.s(12)), child: Text('Log', style: text.titleSmall)),
                  for (final l in _logs) Text(l, style: text.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
