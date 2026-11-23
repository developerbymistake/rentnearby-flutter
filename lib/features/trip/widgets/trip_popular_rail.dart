import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/location_controller.dart';
import '../data/trip_city_catalog.dart';
import '../models/trip_city_model.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import 'trip_city_tile.dart';

class TripPopularRail extends StatefulWidget {
  const TripPopularRail({super.key, this.revision = 0});

  /// Bumped by the host after it reloads the catalog, so the rail rebuilds without being recreated.
  final int revision;

  @override
  State<TripPopularRail> createState() => _TripPopularRailState();
}

class _TripPopularRailState extends State<TripPopularRail> {
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

  Object? _memoData;
  String? _memoState;
  List<TripCityModel> _memo = const [];

  // Sorted once per (state, catalog list), not on every build (FX-31).
  List<TripCityModel> _ordered(String? stateName) {
    final data = _catalog.dataKey;
    if (data != null && identical(data, _memoData) && stateName == _memoState) return _memo;
    _memoData = data;
    _memoState = stateName;
    return _memo = _sorted(stateName);
  }

  List<TripCityModel> _sorted(String? stateName) {
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
          final width = (box.maxWidth - DS.s(28) - DS.gh(12)) / 2;
          final pad = DS.insets(l: 14, t: 4, r: 14, b: 4);
          return SizedBox(
            height: TripCityTile.hubHeightOf(context) + pad.vertical,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              padding: pad,
              itemCount: cities.length,
              separatorBuilder: (_, _) => Gap.h(12),
              itemBuilder: (_, i) => SizedBox(
                width: width,
                child: TripCityTile(
                  key: ValueKey('popular-${cities[i].cityKey}'),
                  city: cities[i],
                  index: i,
                  width: width,
                  hub: true,
                  onTap: () => TripNavigation.startWithCities([cities[i]]),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
