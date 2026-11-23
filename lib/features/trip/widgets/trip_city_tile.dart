import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../models/trip_city_model.dart';
import '../trip_strings_tab.dart';
import 'trip_city_art.dart';

class TripCityTile extends StatelessWidget {
  const TripCityTile({super.key, required this.city, required this.onTap, this.index = 0, this.width = 160, this.hub = false});

  final TripCityModel city;
  final VoidCallback onTap;
  final int index;
  final double width;
  final bool hub;

  static const double aspect = 0.86;

  static const List<String> _arts = [ListingArt.mountain, ListingArt.camping, ListingArt.tent, ListingArt.beach];
  static final List<ListingTone> _tones = [ListingTone.cA, ListingTone.cB, ListingTone.cC, ListingTone.cE];

  static const List<String> _hubArts = [ListingArt.mountain, ListingArt.camping, ListingArt.beach, ListingArt.sunrise];

  static String artOf(int index) => _arts[index % _arts.length];

  // Tallest hub card at the current text scale (name, state line and spot count), for fixed-height rails.
  static double hubHeightOf(BuildContext context) {
    final t = MediaQuery.textScalerOf(context);
    final text = t.scale(DS.f(20)) * 1.3 + DS.gv(3) + t.scale(DS.f(12)) * 1.5;
    final count = t.scale(DS.f(30)) + DS.gv(3) + t.scale(DS.f(11)) * 1.2;
    final content = [text, count, DS.s(38)].reduce((a, b) => a > b ? a : b);
    final card = DS.s(102) + DS.s(14) + content;
    return DS.s(40) + (card > DS.s(150) ? card : DS.s(150));
  }

  static List<String> placeLines(TripCityModel city) {
    final state = city.stateName;
    final district = city.districtName == city.name || city.districtName == state ? '' : city.districtName;
    return [district, state].where((e) => e.isNotEmpty).toList();
  }

  static String _fit(String text, double room, TextScaler scaler) {
    final style = Ink3D.text(12, FontWeight.w500, DesignColors.onPrimary, height: 1.55);
    bool fits(String t) {
      final tp = TextPainter(text: TextSpan(text: t, style: style), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)..layout();
      final ok = tp.width <= room;
      tp.dispose();
      return ok;
    }

    if (text.isEmpty || fits(text)) return text;
    var lo = 0, hi = text.length;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (fits('${text.substring(0, mid).trimRight()}…')) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return '${text.substring(0, lo).trimRight()}…';
  }

  @override
  Widget build(BuildContext context) {
    if (hub) return _HubCityCard(tile: this);
    final spots = city.spotCount;
    final scaler = MediaQuery.textScalerOf(context);
    final room = width - MealsCardV.cellPadding.horizontal - DS.s(32);
    final lines = placeLines(city).map((e) => _fit(e, room, scaler)).toList();
    final place = lines.join('\n');
    final cover = city.cover;
    return RepaintBoundary(
      child: MealsCardV(
        tone: _tones[index % _tones.length],
        title: city.name,
        description: place,
        art: cover == null ? artOf(index) : null,
        photo: cover == null
            ? null
            : KitPhoto(
                url: cover,
                width: DS.s(100),
                height: DS.s(100),
                tone: TripCityArt.toneOf(city.cityKey),
                asset: TravelIcon.map,
                iconSize: 40,
              ),
        number: spots > 0 ? '$spots' : null,
        unit: TripStringsTab.cityUnit(spots),
        onTap: onTap,
        width: width,
        semanticsLabel: city.name,
        titleLines: 2,
        minCardHeight: 194,
        cellBottom: 18,
        descriptionLines: lines.length < 2 ? 2 : lines.length,
      ),
    );
  }
}

class _HubCityCard extends StatelessWidget {
  const _HubCityCard({required this.tile});

  final TripCityTile tile;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final city = tile.city;
    final index = tile.index;
    final tone = TripCityTile._tones[index % TripCityTile._tones.length];
    final spots = city.spotCount;
    final placed = TripCityTile.placeLines(city);
    final state = placed.isEmpty ? '' : placed.last;
    final cover = city.cover;
    final shade = [
      Shadow(
        color: Colors.black.withValues(alpha: Alpha.soft),
        offset: DS.shadowOffset(const Offset(0, 1)),
        blurRadius: DS.shadowBlur(3),
      ),
    ];
    final room = tile.width - DS.s(30) - DS.s(8);
    final count = spots > 0
        ? ConstrainedBox(
            constraints: BoxConstraints(maxWidth: room / 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$spots', maxLines: 1, style: Ink3D.text(30, FontWeight.w600, white, height: 1, letterSpacing: 0).copyWith(shadows: shade)),
                  Gap.v(3),
                  Text(
                    TripStringsTab.cityUnit(spots),
                    maxLines: 1,
                    style: Ink3D.text(11, FontWeight.w500, white, height: 1.2, letterSpacing: 0).copyWith(shadows: shade),
                  ),
                ],
              ),
            ),
          )
        : RoundGoButton(color: tone.button);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: DS.br(kMealsRadius),
        gradient: tone.gradient,
        boxShadow: DS.shadows([BoxShadow(color: Colors.black.withValues(alpha: Alpha.v18), offset: const Offset(0, 6), blurRadius: 12)]),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: DS.s(150)),
        child: Padding(
          padding: DS.insets(l: 16, t: 102, r: 14, b: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      city.name,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: Ink3D.text(20, FontWeight.w700, white, height: 1.3, letterSpacing: 0).copyWith(shadows: shade),
                    ),
                    if (state.isNotEmpty) ...[
                      Gap.v(3),
                      Text(
                        state,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: Ink3D.text(12, FontWeight.w400, white, height: 1.5, letterSpacing: 0).copyWith(shadows: shade),
                      ),
                    ],
                  ],
                ),
              ),
              Gap.h(8),
              count,
            ],
          ),
        ),
      ),
    );
    final circle = Container(
      width: DS.s(132),
      height: DS.s(132),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: white.withValues(alpha: Alpha.v22),
        border: Border.all(color: white.withValues(alpha: Alpha.scrim), width: DS.s(2)),
      ),
      child: cover == null
          ? Art3D(
              asset: TripCityTile._hubArts[index % TripCityTile._hubArts.length],
              size: 118,
              shadowBlur: 5,
              shadowOffset: const Offset(4, 6),
              shadowAlpha: 0.22,
            )
          : ClipOval(
              child: KitPhoto(
                url: cover,
                width: DS.s(118),
                height: DS.s(118),
                tone: TripCityArt.toneOf(city.cityKey),
                asset: TravelIcon.map,
                iconSize: 40,
              ),
            ),
    );
    return RepaintBoundary(
      child: Semantics(
        label: city.name,
        button: true,
        container: true,
        excludeSemantics: true,
        child: PressScale(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: tile.onTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(padding: EdgeInsets.only(top: DS.s(40)), child: card),
                Positioned(left: DS.s(10), top: 0, child: circle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
