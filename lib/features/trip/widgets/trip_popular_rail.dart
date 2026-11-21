import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/location_controller.dart';
import '../data/trip_city_catalog.dart';
import '../models/trip_city_model.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';

class TripPopularRail extends StatefulWidget {
  const TripPopularRail({super.key});

  @override
  State<TripPopularRail> createState() => _TripPopularRailState();
}

class _TripPopularRailState extends State<TripPopularRail> {
  static const List<String> _arts = [ListingArt.mountain, ListingArt.hinduTemple, ListingArt.canoe, ListingArt.camping, ListingArt.tent, ListingArt.beach, ListingArt.sunrise];

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: const TitleRow3D(
            title: TripStrings.popularDestinations,
            action: 'See all',
            onAction: TripNavigation.openTripsTab,
          ),
        ),
        LayoutBuilder(builder: (context, box) {
          final width = ((box.maxWidth - DS.s(18) * 2 - DS.gh(12) * 2) / 3).clamp(DS.s(96), DS.s(160)).toDouble();
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            padding: DS.insets(l: 18, t: 4, r: 18, b: 4),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cities.length; i++) ...[
                    if (i > 0) Gap.h(12),
                    PopularCityCard(key: ValueKey('popular-${cities[i].cityKey}'), city: cities[i], width: width, art: _arts[cities[i].cityKey.abs() % _arts.length]),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class PopularCityCard extends StatelessWidget {
  const PopularCityCard({super.key, required this.city, required this.width, required this.art});

  final TripCityModel city;
  final double width;
  final String art;

  static const BorderRadius radius = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(30),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );

  @override
  Widget build(BuildContext context) {
    final place = city.stateName.isNotEmpty ? city.stateName : city.districtName;
    final cover = city.cover;
    final circle = DS.s(64);
    return Semantics(
      button: true,
      label: place.isEmpty ? city.name : '${city.name}, $place',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => TripNavigation.startWithCities([city]),
        child: Container(
          width: width,
          padding: DS.insets(l: 10, t: 12, r: 10, b: 12),
          decoration: BoxDecoration(color: DesignColors.onPrimary, borderRadius: DS.br(radius), boxShadow: DS.shadows(Ink3D.softShadow)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: SizedBox(
                  width: circle,
                  height: circle,
                  child: cover == null
                      ? DecoratedBox(
                          decoration: BoxDecoration(color: ListingPalette.sunrise.tint),
                          child: Center(child: Art3D(asset: art, size: 46)),
                        )
                      : KitPhoto(url: cover, width: circle, height: circle, asset: TravelIcon.map, iconSize: 32),
                ),
              ),
              Gap.v(6),
              Text(city.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, Ink3D.title)),
              if (place.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: DS.s(2)),
                  child: Text(place, maxLines: 1, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
