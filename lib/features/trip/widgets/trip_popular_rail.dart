import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../../../controllers/location_controller.dart';
import '../data/trip_city_catalog.dart';
import '../models/trip_city_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';

class TripPopularRail extends StatefulWidget {
  const TripPopularRail({super.key});

  @override
  State<TripPopularRail> createState() => _TripPopularRailState();
}

class _TripPopularRailState extends State<TripPopularRail> {
  static const double _cardWidth = 150;
  static const double _cardHeight = 150;

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
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              TripStrings.popularDestinations,
              style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              TripStrings.popularDestinationsSubtitle,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: _cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: cities.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _card(cities[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(TripCityModel city) {
    final ready = city.isReady;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return GestureDetector(
      onTap: ready ? () => TripNavigation.openDays([city]) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: _cardWidth,
          height: _cardHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              city.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: city.imageUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: (_cardWidth * dpr).round(),
                      placeholder: (_, __) => _placeholder(),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
                    stops: const [0.4, 1],
                  ),
                ),
              ),
              if (!ready)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      TripStrings.comingSoon,
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      city.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    if (city.stateName.isNotEmpty)
                      Text(
                        city.stateName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => const DecoratedBox(decoration: BoxDecoration(gradient: TripColors.gradient));
}
