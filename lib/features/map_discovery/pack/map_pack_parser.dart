import 'dart:convert';

import 'map_pack_constants.dart';
import 'map_pack_models.dart';

class MapPackParser {
  static MapPack? parse(String raw) {
    if (raw.isEmpty || raw.length > MapPackConstants.maxBodyChars) return null;
    final Object? json;
    try {
      json = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    return fromJson(json);
  }

  static MapPack? fromJson(Object? json) {
    if (json is! Map) return null;
    final fields = json['fields'];
    final rows = json['s'];
    if (fields is! List || rows is! List) return null;
    final col = <String, int>{};
    for (var i = 0; i < fields.length; i++) {
      final f = fields[i];
      if (f is String && !col.containsKey(f)) col[f] = i;
    }
    for (final c in MapPackConstants.requiredColumns) {
      if (!col.containsKey(c)) return null;
    }
    final catsRaw = json['cats'];
    final cats = <String>[
      if (catsRaw is List)
        for (final c in catsRaw) c is String ? c.trim() : '',
    ];
    final imgRaw = json['img'];
    final img = imgRaw is String && imgRaw.trim().isNotEmpty ? imgRaw.trim() : null;
    final version = _str(json['v']) ?? '';
    final stateId = _str(json['state']) ?? '';

    final iId = col[MapPackConstants.colId]!;
    final iLat = col[MapPackConstants.colLat]!;
    final iLon = col[MapPackConstants.colLon]!;
    final iName = col[MapPackConstants.colName]!;
    final iCat = col[MapPackConstants.colCat];
    final iRank = col[MapPackConstants.colRank];
    final iCity = col[MapPackConstants.colCityKey];
    final iThumb = col[MapPackConstants.colThumb];
    final iPhotos = col[MapPackConstants.colNPhotos];

    final seen = <String>{};
    final spots = <MapPackSpot>[];
    for (var r = 0; r < rows.length && spots.length < MapPackConstants.maxRows; r++) {
      final row = rows[r];
      if (row is! List) continue;
      Object? at(int? i) => i == null || i >= row.length ? null : row[i];
      final id = _str(at(iId));
      if (id == null || seen.contains(id)) continue;
      final lat = _num(at(iLat));
      final lon = _num(at(iLon));
      if (lat == null || lon == null || lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;
      final nameRaw = at(iName);
      final name = nameRaw is String ? nameRaw.trim() : '';
      if (name.isEmpty) continue;
      seen.add(id);
      final rank = _int(at(iRank));
      spots.add(MapPackSpot(
        id: id,
        lat: lat,
        lon: lon,
        category: _category(at(iCat), cats),
        rank: rank != null && rank >= 1 ? rank : MapPackConstants.unrankedBase + r,
        name: name,
        cityKey: _int(at(iCity)),
        thumbUrl: thumbUrl(img, at(iThumb)),
        nPhotos: (_int(at(iPhotos)) ?? 0).clamp(0, 1 << 30),
        stateId: stateId,
      ));
    }
    return MapPack(version: version, stateId: stateId, spots: List.unmodifiable(spots));
  }

  static String? thumbUrl(String? img, Object? thumb) {
    if (thumb is! String) return null;
    final t = thumb.trim();
    if (t.isEmpty) return null;
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    if (img == null || img.isEmpty) return null;
    final base = img.endsWith('/') ? img : '$img/';
    return base + (t.startsWith('/') ? t.substring(1) : t);
  }

  static List<MapPackRef> refs(Object? json) {
    final list = json is Map ? json['packs'] : json;
    if (list is! List) return const [];
    final out = <MapPackRef>[];
    final seen = <String>{};
    for (final e in list) {
      if (e is! Map) continue;
      final stateId = _str(e['stateId']);
      final version = _str(e['version']);
      final pathRaw = e['path'];
      final path = pathRaw is String ? pathRaw.trim() : '';
      if (stateId == null || version == null || path.isEmpty || seen.contains(stateId)) continue;
      seen.add(stateId);
      final nameRaw = e['stateName'];
      final name = nameRaw is String && nameRaw.trim().isNotEmpty ? nameRaw.trim() : null;
      out.add(MapPackRef(
        stateId: stateId,
        stateName: name,
        version: version,
        path: path,
        bbox: _bbox(e['bbox']),
        count: _int(e['count']),
      ));
    }
    return List.unmodifiable(out);
  }

  static bool flag(Object? json) => json is Map && json['mapDiscovery'] == true;

  static String _category(Object? v, List<String> cats) {
    if (v is String) return v.trim();
    final i = _int(v);
    if (i == null || i < 0 || i >= cats.length) return '';
    return cats[i];
  }

  static List<double>? _bbox(Object? v) {
    if (v is! List || v.length != 4) return null;
    final out = <double>[];
    for (final x in v) {
      final d = _num(x);
      if (d == null) return null;
      out.add(d);
    }
    if (out[0] > out[2] || out[1] > out[3]) return null;
    return List.unmodifiable(out);
  }

  static String? _str(Object? v) {
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    if (v is int) return '$v';
    if (v is double && v.isFinite && v == v.truncateToDouble()) return '${v.toInt()}';
    return null;
  }

  static double? _num(Object? v) {
    final d = v is num ? v.toDouble() : (v is String ? double.tryParse(v.trim()) : null);
    return d != null && d.isFinite ? d : null;
  }

  static int? _int(Object? v) {
    if (v is int) return v;
    if (v is double && v.isFinite && v == v.truncateToDouble()) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }
}
