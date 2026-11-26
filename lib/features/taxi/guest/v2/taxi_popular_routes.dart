import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../../design/design.dart';
import '../../../../models/browse_item.dart';
import '../../../../models/place_result_model.dart';
import 'taxi_search_strings.dart';

class TaxiCityPair {
  final int fromKey;
  final int toKey;

  const TaxiCityPair(this.fromKey, this.toKey);

  TaxiCityPair get reversed => TaxiCityPair(toKey, fromKey);

  Map<String, dynamic> toParams() => {'fromCityKey': fromKey, 'toCityKey': toKey};

  static int? _key(Object? v) {
    final n = v is int ? v : (v is String ? int.tryParse(v.trim()) : null);
    return n != null && n > 0 ? n : null;
  }

  static TaxiCityPair? tryParse(Object? from, Object? to) {
    final f = _key(from);
    final t = _key(to);
    return f == null || t == null || f == t ? null : TaxiCityPair(f, t);
  }

  @override
  bool operator ==(Object other) => other is TaxiCityPair && other.fromKey == fromKey && other.toKey == toKey;

  @override
  int get hashCode => Object.hash(fromKey, toKey);

  @override
  String toString() => '$fromKey-$toKey';
}

class TaxiPopularRoute {
  final String id;
  final TaxiCityPair? cities;
  final String fromName;
  final double fromLat;
  final double fromLng;
  final String toName;
  final double toLat;
  final double toLng;
  final int? minFare;
  final int taxiCount;

  const TaxiPopularRoute({
    required this.id,
    required this.fromName,
    required this.fromLat,
    required this.fromLng,
    required this.toName,
    required this.toLat,
    required this.toLng,
    required this.taxiCount,
    this.minFare,
    this.cities,
  });

  PlaceResult get from => PlaceResult(name: fromName, subtitle: '', latLng: LatLng(fromLat, fromLng));
  PlaceResult get to => PlaceResult(name: toName, subtitle: '', latLng: LatLng(toLat, toLng));

  static double? _num(Object? v) => v is num && v.isFinite ? v.toDouble() : null;

  static int? _int(Object? v) => v is num && v.isFinite ? v.toInt() : null;

  static String _text(Object? v) => v is String ? v.trim() : '';

  static TaxiPopularRoute? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString() ?? '';
    final fromName = _text(raw['fromName']);
    final toName = _text(raw['toName']);
    final fLat = _num(raw['fromLat']);
    final fLng = _num(raw['fromLng']);
    final tLat = _num(raw['toLat']);
    final tLng = _num(raw['toLng']);
    final count = _int(raw['taxiCount']) ?? 0;
    if (id.isEmpty || fromName.isEmpty || toName.isEmpty || fLat == null || fLng == null || tLat == null || tLng == null) return null;
    if (fLat.abs() > 90 || tLat.abs() > 90 || fLng.abs() > 180 || tLng.abs() > 180 || count <= 0) return null;
    final fare = _int(raw['minFare']);
    return TaxiPopularRoute(
      id: id,
      fromName: fromName,
      fromLat: fLat,
      fromLng: fLng,
      toName: toName,
      toLat: tLat,
      toLng: tLng,
      taxiCount: count,
      minFare: fare != null && fare > 0 ? fare : null,
      cities: TaxiCityPair.tryParse(raw['fromCityKey'], raw['toCityKey']),
    );
  }

  static List<TaxiPopularRoute> listFrom(Object? raw) {
    if (raw is! List) return const [];
    final out = <TaxiPopularRoute>[];
    final seen = <String>{};
    for (final e in raw) {
      final r = tryParse(e);
      if (r != null && seen.add(r.id)) out.add(r);
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromCityKey': cities?.fromKey,
        'toCityKey': cities?.toKey,
        'fromName': fromName,
        'fromLat': fromLat,
        'fromLng': fromLng,
        'toName': toName,
        'toLat': toLat,
        'toLng': toLng,
        'minFare': minFare,
        'taxiCount': taxiCount,
      };
}

class TaxiPopularRoutesRail extends StatelessWidget {
  const TaxiPopularRoutesRail({super.key, required this.routes, required this.onTap});

  final List<TaxiPopularRoute> routes;
  final ValueChanged<TaxiPopularRoute> onTap;

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TitleRow3D(title: TaxiSearchStrings.popularRoutes, tone: ListingTone.coral),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(2), DS.s(18), DS.gv(8)),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < routes.length; i++) ...[
                  if (i > 0) SizedBox(width: DS.gh(12)),
                  _PopularCard(key: ValueKey('popular-${routes[i].id}'), route: routes[i], index: i, onTap: () => onTap(routes[i])),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PopularCard extends StatelessWidget {
  const _PopularCard({super.key, required this.route, required this.index, required this.onTap});

  final TaxiPopularRoute route;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fare = route.minFare;
    final fareText = fare == null ? null : TaxiSearchStrings.fromFare(BrowseItem.inr(fare));
    final count = TaxiSearchStrings.taxis(route.taxiCount);
    final label = [TaxiSearchStrings.routeSemantics(route.fromName, route.toName), ?fareText, count].join(', ');
    final tone = ListingTone.list(ListingTone.coral, index);
    final radius = DS.br(CardRadius.hero);
    return Tap3D(
      onTap: onTap,
      label: label,
      exclude: true,
      child: Container(
        width: DS.s(168),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: radius, boxShadow: DS.shadows(Ink3D.softShadow)),
        child: ClipRRect(
          borderRadius: radius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(gradient: tone.gradient),
                child: SizedBox(
                  height: DS.s(72),
                  child: Center(child: Art3D(asset: index.isEven ? ListingArt.sunriseMountains : ListingArt.mountain, size: 52)),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(DS.s(12), DS.gv(10), DS.s(12), DS.gv(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      TaxiSearchStrings.routeTitle(route.fromName, route.toName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Ink3D.text(14, FontWeight.w600, Ink3D.body),
                    ),
                    if (fareText != null) ...[
                      SizedBox(height: DS.gv(4)),
                      Text(fareText, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, ListingPalette.coral.text)),
                    ],
                    SizedBox(height: DS.gv(2)),
                    Text(count, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Ink3D.sub, height: 1.45)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
