import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:get/get.dart';

import '../../../config/app_constants.dart';
import '../../trip/data/trip_city_catalog.dart';
import '../../trip/data/trip_repository.dart';
import '../../trip/models/trip_city_model.dart';
import '../pack/map_pack_constants.dart';
import '../pack/map_pack_index.dart';
import '../pack/map_pack_models.dart';
import '../pack/map_pack_parser.dart';
import 'map_pack_api.dart';
import 'map_pack_discovery_source.dart';
import 'map_pack_store.dart';

typedef MapPackVersionCall = Future<TripCityVersion> Function();
typedef MapPackCitiesOf = Iterable<TripCityModel> Function(Iterable<int> cityKeys);
typedef MapPackParse = Future<MapPack?> Function(String raw);

class MapPackService {
  static MapPackService get to =>
      Get.isRegistered<MapPackService>() ? Get.find<MapPackService>() : Get.put(MapPackService(), permanent: true);

  static Future<void> clearAll() async {
    if (Get.isRegistered<MapPackService>()) return Get.find<MapPackService>().wipe();
    await MapPackStore.init();
    MapPackStore.erase();
  }

  final MapPackApi _api;
  final MapPackVersionCall _versionCall;
  final MapPackCitiesOf _citiesOf;
  final DateTime Function() _now;
  final MapPackParse _parse;

  MapPackService({
    MapPackApi? api,
    MapPackVersionCall? versionCall,
    MapPackCitiesOf? citiesOf,
    DateTime Function()? now,
    MapPackParse? parse,
  })  : _api = api ?? MapPackApi(),
        _versionCall = versionCall ?? _defaultVersionCall,
        _citiesOf = citiesOf ?? _defaultCitiesOf,
        _now = now ?? DateTime.now,
        _parse = parse ?? parseOffFrame;

  static Future<TripCityVersion> _defaultVersionCall() => const TripRepository().citiesVersion(once: true);

  static Iterable<TripCityModel> _defaultCitiesOf(Iterable<int> cityKeys) {
    final keys = cityKeys.toSet();
    final catalog = TripCityCatalog.to..warmFromDisk();
    return catalog.search('').where((c) => keys.contains(c.cityKey));
  }

  static Future<MapPack?> parseOffFrame(String raw) async {
    try {
      if (raw.length >= MapPackConstants.isolateFromChars) return await compute(MapPackParser.parse, raw);
      return MapPackParser.parse(raw);
    } catch (_) {
      return null;
    }
  }

  final RxInt revision = 0.obs;
  final Rx<MapPackStatus> status = MapPackStatus.none.obs;
  late final MapPackDiscoverySource source = MapPackDiscoverySource(this);

  bool _flag = false;
  List<MapPackRef> _refs = const [];
  DateTime? _refsAt;
  bool _metaLoaded = false;
  bool _diskRead = false;
  bool _refsFromServer = false;
  String? _persistedKey;
  Future<void>? _readyF;
  Future<void>? _versionF;
  DateTime? _versionFailedAt;
  Future<void> _applied = Future.value();

  final Map<String, MapPack> _packs = {};
  final Map<String, String> _ver = {};
  final Map<String, Future<void>> _inflight = {};
  final Map<String, String> _inflightVer = {};
  final Map<String, DateTime> _failedAt = {};
  Set<String> _picked = const {};
  MapPackIndex? _index;
  int _gen = 0;

  bool get enabled => _flag;

  MapPackIndex? get index => _flag ? _index : null;

  List<MapPackRef> get refs => _refs;

  void onVersion(TripCityVersion v) {
    try {
      _metaLoaded = true;
      final flagChanged = v.mapDiscovery != _flag;
      _flag = v.mapDiscovery;
      if (v.packsKnown) {
        _refs = v.packs;
        _refsFromServer = true;
      }
      _refsAt = _now();
      if (!_flag) _dropMemory();
      if (flagChanged) revision.value++;
      _updateStatus();
      final gen = _gen;
      _applied = _applyVersion(gen).catchError((_) {});
    } catch (_) {}
  }

  Future<void> ensureForCities(Iterable<int> cityKeys) async {
    try {
      final keys = cityKeys.toSet();
      if (!await _prepare()) return;
      if (keys.isEmpty) return;
      await _loadPicked(_pickForCities(keys));
    } catch (_) {
      _updateStatus();
    }
  }

  Future<void> ensureForPoint(double lat, double lon) async {
    try {
      if (!lat.isFinite || !lon.isFinite) return;
      if (!await _prepare()) return;
      final hit = [for (final r in _refs) if (r.contains(lat, lon)) r];
      await _loadPicked(hit.isNotEmpty ? hit : [for (final r in _refs) if (r.bbox == null) r].take(MapPackConstants.fallbackRefs).toList());
    } catch (_) {
      _updateStatus();
    }
  }

  Future<void> wipe() async {
    _gen++;
    _dropMemory();
    _inflight.clear();
    _inflightVer.clear();
    _failedAt.clear();
    _picked = const {};
    _flag = false;
    _refs = const [];
    _refsAt = null;
    _metaLoaded = false;
    _diskRead = false;
    _refsFromServer = false;
    _persistedKey = null;
    _readyF = null;
    _versionF = null;
    _versionFailedAt = null;
    status.value = MapPackStatus.none;
    source.sync(MapPackStatus.none);
    revision.value++;
    try {
      await MapPackStore.init();
      MapPackStore.erase();
    } catch (_) {}
  }

  @visibleForTesting
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await _applied;
      final f = [..._inflight.values];
      if (f.isEmpty && _versionF == null) return;
      await Future.wait(f);
      await (_versionF ?? Future.value());
    }
  }

  Future<bool> _prepare() async {
    final gen = _gen;
    await _ready();
    if (gen != _gen) return false;
    if (_needsVersion()) await _refreshRefs();
    if (gen != _gen) return false;
    await _applied;
    if (gen != _gen) return false;
    if (!_flag) {
      _updateStatus();
      return false;
    }
    return true;
  }

  bool _needsVersion() {
    final now = _now();
    final failed = _versionFailedAt;
    if (failed != null && now.difference(failed) < MapPackConstants.retryAfter) return false;
    final at = _refsAt;
    return at == null || now.difference(at) >= AppConstants.tripCitiesRevalidateAfter;
  }

  Future<void> _refreshRefs() {
    final pending = _versionF;
    if (pending != null) return pending;
    final gen = _gen;
    late final Future<void> f;
    f = () async {
      try {
        final v = await _versionCall();
        if (gen != _gen) return;
        _versionFailedAt = null;
        onVersion(v);
      } catch (_) {
        if (gen == _gen) _versionFailedAt = _now();
      }
    }()
        .whenComplete(() {
      if (identical(_versionF, f)) _versionF = null;
    });
    _versionF = f;
    return f;
  }

  Future<void> _ready() => _readyF ??= _initAndLoad();

  Future<void> _initAndLoad() async {
    await MapPackStore.init();
    if (_diskRead) return;
    _diskRead = true;
    final m = MapPackStore.readMeta();
    if (_metaLoaded) {
      // A version answer came first: it wins, but an unknown pack list keeps the stored refs.
      final storedRefs = m == null ? const <MapPackRef>[] : MapPackParser.refs(m['refs']);
      if (!_refsFromServer && _refs.isEmpty && storedRefs.isNotEmpty) {
        _refs = storedRefs;
        _updateStatus();
      }
      return;
    }
    _metaLoaded = true;
    if (m == null) return;
    final storedRefs = MapPackParser.refs(m['refs']);
    _flag = MapPackParser.flag({'mapDiscovery': m['flag']});
    _refs = storedRefs;
    final ms = m['refsAtMs'];
    _refsAt = ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
    _persistedKey = _metaKey();
    if (_flag) revision.value++;
    _updateStatus();
  }

  String _metaKey() => jsonEncode({'flag': _flag, 'refs': [for (final r in _refs) r.toJson()]});

  void _persistMeta() {
    final key = _metaKey();
    if (key == _persistedKey) return;
    MapPackStore.writeMeta({
      'schema': 1,
      'flag': _flag,
      'refs': [for (final r in _refs) r.toJson()],
      'refsAtMs': (_refsAt ?? _now()).millisecondsSinceEpoch,
    });
    _persistedKey = key;
  }

  Future<void> _applyVersion(int gen) async {
    await _ready();
    if (gen != _gen) return;
    _persistMeta();
    if (!_flag || (_refs.isEmpty && !_refsFromServer)) return;
    final byId = {for (final r in _refs) r.stateId: r};
    var removed = false;
    for (final s in {...MapPackStore.storedStates(), ..._packs.keys}) {
      if (byId.containsKey(s)) continue;
      MapPackStore.drop(s);
      _ver.remove(s);
      removed = _packs.remove(s) != null || removed;
    }
    if (removed) _swapped();
    final stored = MapPackStore.storedStates();
    await Future.wait([
      for (final s in stored)
        if (byId[s] != null) _loadState(byId[s]!),
    ]);
  }

  List<MapPackRef> _fallback() => _refs.take(MapPackConstants.fallbackRefs).toList();

  static String _fold(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  List<MapPackRef> _pickForCities(Set<int> keys) {
    final cities = _citiesOf(keys).toList();
    final out = <MapPackRef>[];
    void add(MapPackRef r) {
      if (!out.contains(r)) out.add(r);
    }

    for (final c in cities) {
      final name = _fold(c.stateName);
      final byName = name.isEmpty ? null : _refs.firstWhereOrNull((r) => r.stateName != null && _fold(r.stateName!) == name);
      final ref = byName ?? _refs.firstWhereOrNull((r) => r.contains(c.latitude, c.longitude));
      if (ref != null) add(ref);
    }
    return out.isNotEmpty ? out : _fallback();
  }

  Future<void> _loadPicked(List<MapPackRef> picked) async {
    _picked = {for (final r in picked) r.stateId};
    _updateStatus();
    await Future.wait(picked.map(_loadState));
    _updateStatus();
  }

  Future<void> _loadState(MapPackRef ref) {
    final id = ref.stateId;
    final pending = _inflight[id];
    if (pending != null) {
      if (_inflightVer[id] == ref.version) return pending;
      final gen = _gen;
      return pending.then((_) => gen == _gen ? _loadState(ref) : null);
    }
    if (_packs.containsKey(id) && _ver[id] == ref.version) return Future.value();
    final gen = _gen;
    late final Future<void> f;
    f = _doLoad(ref, gen).catchError((_) {}).whenComplete(() {
      if (identical(_inflight[id], f)) {
        _inflight.remove(id);
        _inflightVer.remove(id);
      }
      _updateStatus();
    });
    _inflight[id] = f;
    _inflightVer[id] = ref.version;
    _updateStatus();
    return f;
  }

  Future<void> _doLoad(MapPackRef ref, int gen) async {
    final id = ref.stateId;
    if (!_packs.containsKey(id)) {
      final body = MapPackStore.readBody(id);
      if (body != null) {
        final p = await _parse(body);
        if (gen != _gen) return;
        if (p == null) {
          MapPackStore.drop(id);
        } else {
          final ver = MapPackStore.readVersion(id) ?? p.version;
          _swap(id, ver, p);
        }
      }
    }
    if (_packs.containsKey(id) && _ver[id] == ref.version) return;
    final failKey = _failKey(ref);
    final failed = _failedAt[failKey];
    if (failed != null && _now().difference(failed) < MapPackConstants.retryAfter) return;

    final hasBody = MapPackStore.readBody(id) != null;
    try {
      final r = await _api.fetch(ref, etag: hasBody ? MapPackStore.readVersion(id) : null);
      if (gen != _gen) return;
      if (r.notModified) {
        if (!hasBody) return _fail(failKey);
        MapPackStore.stampVersion(id, ref.version);
        if (_packs.containsKey(id)) _ver[id] = ref.version;
        _failedAt.remove(failKey);
        return;
      }
      final body = r.body;
      if (body == null) return _fail(failKey);
      final p = await _parse(body);
      if (gen != _gen) return;
      if (p == null) return _fail(failKey);
      if ((p.version.isNotEmpty && p.version != ref.version) || (p.stateId.isNotEmpty && p.stateId != id)) return _fail(failKey);
      _failedAt.remove(failKey);
      _swap(id, ref.version, p);
      if (gen != _gen) return;
      MapPackStore.save(id, ref.version, body);
    } catch (_) {
      if (gen == _gen) _fail(failKey);
    }
  }

  // Back-off per (state, version): a failure of an old version never blocks the new one.
  static String _failKey(MapPackRef ref) => '${ref.stateId}@${ref.version}';

  void _fail(String key) => _failedAt[key] = _now();

  void _swap(String id, String version, MapPack p) {
    if (!_flag) return;
    _ver[id] = version;
    _packs[id] = p.withFallback(version: version, stateId: id);
    _swapped();
  }

  void _swapped() {
    _index = _packs.isEmpty ? null : MapPackIndex.of(_packs.values);
    revision.value++;
    _updateStatus();
  }

  void _dropMemory() {
    final had = _packs.isNotEmpty || _index != null;
    _packs.clear();
    _ver.clear();
    _index = null;
    if (had) revision.value++;
  }

  void _updateStatus() {
    final MapPackStatus s;
    if (!_flag) {
      s = _metaLoaded ? MapPackStatus.off : MapPackStatus.none;
    } else if (_picked.any(_inflight.containsKey)) {
      s = MapPackStatus.loading;
    } else if ((_index != null && !_index!.isEmpty) || (_picked.isNotEmpty && _picked.every(_packs.containsKey))) {
      s = MapPackStatus.ready;
    } else {
      s = MapPackStatus.none;
    }
    if (status.value != s) status.value = s;
    source.sync(s);
  }
}
