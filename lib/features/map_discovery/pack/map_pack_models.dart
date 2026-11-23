enum MapPackStatus { off, none, loading, ready }

class MapPackSpot {
  final String id;
  final double lat;
  final double lon;
  final String category;
  final int rank;
  final String name;
  final int? cityKey;
  final String? thumbUrl;
  final int nPhotos;
  final String stateId;
  final int? visitMinutes;

  const MapPackSpot({
    required this.id,
    required this.lat,
    required this.lon,
    required this.category,
    required this.rank,
    required this.name,
    this.cityKey,
    this.thumbUrl,
    this.nPhotos = 0,
    this.stateId = '',
    this.visitMinutes,
  });

  bool get hasThumb => thumbUrl != null && thumbUrl!.isNotEmpty;

  MapPackSpot withStateId(String value) => value == stateId
      ? this
      : MapPackSpot(
          id: id,
          lat: lat,
          lon: lon,
          category: category,
          rank: rank,
          name: name,
          cityKey: cityKey,
          thumbUrl: thumbUrl,
          nPhotos: nPhotos,
          stateId: value,
          visitMinutes: visitMinutes,
        );
}

class MapPack {
  final String version;
  final String stateId;
  final List<MapPackSpot> spots;

  const MapPack({required this.version, required this.stateId, required this.spots});

  bool get isEmpty => spots.isEmpty;

  MapPack withFallback({required String version, required String stateId}) {
    final v = this.version.isEmpty ? version : this.version;
    final s = this.stateId.isEmpty ? stateId : this.stateId;
    if (v == this.version && s == this.stateId) return this;
    return MapPack(
      version: v,
      stateId: s,
      spots: s == this.stateId ? spots : [for (final p in spots) p.withStateId(s)],
    );
  }
}

class MapPackRef {
  final String stateId;
  final String? stateName;
  final String version;
  final String path;
  final List<double>? bbox;
  final int? count;

  const MapPackRef({
    required this.stateId,
    required this.version,
    required this.path,
    this.stateName,
    this.bbox,
    this.count,
  });

  bool contains(double lat, double lon) {
    final b = bbox;
    if (b == null || b.length != 4) return false;
    return lon >= b[0] && lat >= b[1] && lon <= b[2] && lat <= b[3];
  }

  Map<String, dynamic> toJson() => {
        'stateId': stateId,
        if (stateName != null) 'stateName': stateName,
        'version': version,
        'path': path,
        if (bbox != null) 'bbox': bbox,
        if (count != null) 'count': count,
      };

  @override
  bool operator ==(Object other) =>
      other is MapPackRef &&
      other.stateId == stateId &&
      other.stateName == stateName &&
      other.version == version &&
      other.path == path &&
      other.count == count &&
      _sameBox(other.bbox, bbox);

  @override
  int get hashCode => Object.hash(stateId, stateName, version, path, count, bbox == null ? null : Object.hashAll(bbox!));

  static bool _sameBox(List<double>? a, List<double>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
