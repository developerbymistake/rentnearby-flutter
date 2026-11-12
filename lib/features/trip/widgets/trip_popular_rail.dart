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
  static const double _cardWidth = 168;
  static const double _cardHeight = 168;

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter),
            child: Text(
              TripStrings.popularDestinations,
              style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong, letterSpacing: 0.27),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter),
            child: Text(
              TripStrings.popularDestinationsSubtitle,
              style: TypeTokens.style(12, FontWeight.w400, color: TypeTokens.secondary),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _cardHeight + 24,
            child: RailReveal(
              itemCount: cities.length,
              padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 4, KitMetrics.gutter, 20),
              itemBuilder: (_, i) => _card(cities[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(TripCityModel city) {
    final ready = city.isReady;
    return PressScale(
      enabled: ready,
      child: Container(
        width: _cardWidth,
        height: _cardHeight,
        decoration: const BoxDecoration(borderRadius: CardRadius.tile, boxShadow: ShadowTokens.elev2),
        child: Material(
          color: DesignColors.surface,
          borderRadius: CardRadius.tile,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: ready ? () => TripNavigation.startWithCities([city]) : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                KitPhoto(
                  url: city.cover,
                  width: _cardWidth,
                  height: _cardHeight,
                  tone: KitTone.trip,
                  asset: TravelIcon.map,
                  iconSize: 56,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, DesignColors.overlayDark.withValues(alpha: Alpha.strong)],
                      stops: const [0.4, 1],
                    ),
                  ),
                ),
                if (!ready)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: DesignColors.tint(DesignColors.overlayDark, Alpha.strong),
                        borderRadius: CardRadius.chip,
                      ),
                      child: Text(
                        TripStrings.comingSoon,
                        style: TypeTokens.style(10, FontWeight.w600, color: DesignColors.surface, chip: true),
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        city.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypeTokens.style(14, FontWeight.w700, color: DesignColors.surface),
                      ),
                      if (city.stateName.isNotEmpty)
                        Text(
                          city.stateName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TypeTokens.style(11, FontWeight.w500, color: DesignColors.tint(DesignColors.surface, Alpha.high)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
