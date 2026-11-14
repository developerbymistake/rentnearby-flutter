import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../models/trip_city_model.dart';
import '../trip_strings_tab.dart';
import 'trip_city_art.dart';

class TripCityTile extends StatelessWidget {
  const TripCityTile({super.key, required this.city, required this.onTap, this.index = 0, this.width = 160});

  final TripCityModel city;
  final VoidCallback onTap;
  final int index;
  final double width;

  static const double aspect = 0.86;

  static const List<String> _arts = [ListingArt.mountain, ListingArt.camping, ListingArt.tent, ListingArt.beach];
  static final List<ListingTone> _tones = [ListingTone.cA, ListingTone.cB, ListingTone.cC, ListingTone.cE];

  static String artOf(int index) => _arts[index % _arts.length];

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
    final spots = city.spotCount;
    final scaler = MediaQuery.textScalerOf(context);
    final room = width - MealsCardV.cellPadding.horizontal - 32;
    final lines = placeLines(city).map((e) => _fit(e, room, scaler)).toList();
    final place = lines.join('\n');
    final art = artOf(index);
    final cover = city.cover;
    return RepaintBoundary(
      child: MealsCardV(
        tone: _tones[index % _tones.length],
        title: city.name,
        description: place,
        art: cover == null ? art : null,
        photo: cover == null
            ? null
            : KitPhoto(
                url: cover,
                width: 100,
                height: 100,
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
        descriptionLines: lines.length < 2 ? 2 : lines.length,
      ),
    );
  }
}
