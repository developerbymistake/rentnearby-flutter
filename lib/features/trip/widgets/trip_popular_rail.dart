import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/location_controller.dart';
import '../data/trip_city_catalog.dart';
import '../models/trip_city_model.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_tab.dart';

class TripPopularRail extends StatefulWidget {
  const TripPopularRail({super.key});

  @override
  State<TripPopularRail> createState() => _TripPopularRailState();
}

class _TripPopularRailState extends State<TripPopularRail> {
  static const List<String> _arts = [ListingArt.mountain, ListingArt.camping, ListingArt.tent, ListingArt.beach, ListingArt.sunrise];

  late final TripCityCatalog _catalog;

  @override
  void initState() {
    super.initState();
    _catalog = TripCityCatalog.to;
    _catalog.warmFromDisk();
    _load();
  }

  Future<void> _load() async {
    try {
      await _catalog.load();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  List<TripCityModel> _ordered(String? stateName) {
    final all = _catalog.popular();
    final state = stateName?.trim().toLowerCase() ?? '';
    if (state.isEmpty) return all;
    final mine = all.where((c) => c.stateName.toLowerCase() == state);
    final others = all.where((c) => c.stateName.toLowerCase() != state);
    return [...mine, ...others];
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<LocationController>()) return _rail(null);
    final loc = Get.find<LocationController>();
    return Obx(() => _rail(loc.effectiveDistrict?.stateName));
  }

  Widget _rail(String? stateName) {
    final cities = _ordered(stateName);
    if (cities.isEmpty) return const SizedBox.shrink();
    final width = _cardWidth(cities);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TitleRow3D(
          title: TripStrings.popularDestinations,
          subtitle: TripStrings.popularDestinationsSubtitle,
          action: 'See all',
          onAction: TripNavigation.openTripsTab,
        ),
        MealsRail(
          physics: const BouncingScrollPhysics(),
          children: [for (var i = 0; i < cities.length; i++) _card(cities[i], i, width)],
        ),
      ],
    );
  }

  static const double _minWidth = 160;
  static const double _maxWidth = 210;

  double _cardWidth(List<TripCityModel> cities) {
    final scaler = MediaQuery.textScalerOf(context);
    final style = Ink3D.text(17, FontWeight.w700, DesignColors.onPrimary, height: 1.3);
    var longest = 0.0;
    for (final c in cities) {
      for (final w in c.name.split(RegExp(r'\s+'))) {
        final x = KitText.widthOf(w, style, scaler);
        if (x > longest) longest = x;
      }
    }
    final need = (longest + MealsCardV.cellPadding.horizontal + 32).ceilToDouble();
    return need.clamp(_minWidth, _maxWidth);
  }

  Widget _card(TripCityModel city, int index, double width) {
    final ready = city.isReady;
    final place = city.stateName.isNotEmpty ? city.stateName : city.districtName;
    final spots = city.spotCount;
    final art = _arts[city.cityKey.abs() % _arts.length];
    final cover = city.cover;
    final hasNumber = ready && spots > 0;
    final second = !ready ? TripStrings.comingSoon : '';
    return MealsCardV(
      key: ValueKey('popular-${city.cityKey}'),
      tone: ListingTone.at(index),
      title: city.name,
      titleLines: 2,
      width: width,
      description: second.isEmpty ? place : '$place\n$second',
      art: cover == null ? art : null,
      photo: cover == null ? null : KitPhoto(url: cover, width: 100, height: 100, asset: TravelIcon.map, iconSize: 40),
      sticker: cover == null ? null : art,
      number: hasNumber ? '$spots' : null,
      unit: TripStringsTab.cityUnit(spots),
      onTap: ready ? () => TripNavigation.startWithCities([city]) : null,
      semanticsLabel: ready ? city.name : '${city.name}, ${TripStrings.comingSoon}',
    );
  }
}
