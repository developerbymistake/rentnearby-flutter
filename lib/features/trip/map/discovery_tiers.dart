import 'package:bakhli/design/design.dart';

import '../../map_discovery/pack/map_pack_index.dart';
import '../../map_discovery/pack/map_pack_models.dart';
import '../models/trip_spot_category.dart';

class DiscArea {
  final double lat;
  final double lon;
  final double km;

  const DiscArea(this.lat, this.lon, this.km);

  bool get valid => lat.isFinite && lon.isFinite && km.isFinite && km > 0;

  bool contains(MapPackSpot s) => valid && MapPackGeo.km(lat, lon, s.lat, s.lon) <= km;
}

class DiscTiers {
  static const int photo = 1;
  static const int badge = 2;
  static const int dot = 3;

  static const int grpWater = 0;
  static const int grpNature = 1;
  static const int grpHeritage = 2;
  static const int grpOther = 3;

  static int compare(MapPackSpot a, MapPackSpot b) {
    final r = a.rank.compareTo(b.rank);
    return r != 0 ? r : a.id.compareTo(b.id);
  }

  static List<MapPackSpot> sorted(Iterable<MapPackSpot> spots) {
    final seen = <String>{};
    return [for (final s in spots) if (seen.add(s.id)) s]..sort(compare);
  }

  static List<MapPackSpot> topPhotos(Iterable<MapPackSpot> spots, int photoMax, {DiscArea? area}) {
    if (photoMax <= 0) return const [];
    final out = <MapPackSpot>[];
    for (final s in sorted(spots)) {
      if (out.length >= photoMax) break;
      if (!s.hasThumb) continue;
      if (area != null && !area.contains(s)) continue;
      out.add(s);
    }
    return out;
  }

  static Map<String, int> assign(Iterable<MapPackSpot> spots, {required int photoMax, int badgeMax = 120, DiscArea? area}) {
    final all = sorted(spots);
    final tiers = <String, int>{};
    for (final s in topPhotos(all, photoMax, area: area)) {
      tiers[s.id] = photo;
    }
    var badges = 0;
    for (final s in all) {
      if (tiers.containsKey(s.id)) continue;
      if (badges < badgeMax) {
        tiers[s.id] = badge;
        badges++;
      } else {
        tiers[s.id] = dot;
      }
    }
    return tiers;
  }

  static int groupOf(String category) {
    final c = TripSpotCategory.colorOf(category);
    if (c == TripTokens.spotWater) return grpWater;
    if (c == TripTokens.spotNature) return grpNature;
    if (c == TripTokens.spotHeritage) return grpHeritage;
    return grpOther;
  }
}
