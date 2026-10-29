import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../../../controllers/location_controller.dart';
import '../models/taxi_browse_item.dart';
import '../taxi_option_sets.dart';
import 'taxi_browse_repository.dart';
import 'taxi_card.dart';
import 'taxi_navigation.dart';

class StayTaxisSection extends StatefulWidget {
  final String stayPlace;
  final double stayLat;
  final double stayLng;
  final Widget fallback;

  const StayTaxisSection({
    super.key,
    required this.stayPlace,
    required this.stayLat,
    required this.stayLng,
    required this.fallback,
  });

  @override
  State<StayTaxisSection> createState() => _StayTaxisSectionState();
}

class _StayTaxisSectionState extends State<StayTaxisSection> {
  final _repo = const TaxiBrowseRepository();
  List<TaxiBrowseItem> _items = const [];
  String _fromName = '';
  double _fromLat = 0;
  double _fromLng = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loc = Get.find<LocationController>();
    final center = loc.effectiveSearchCenter;
    final city = loc.effectiveCity?.name ?? loc.effectiveDistrict?.name ?? '';
    final far = TaxiOptionSets.distanceMeters(center.latitude, center.longitude, widget.stayLat, widget.stayLng) >= 5000;
    if (city.isEmpty || !far) return;
    _fromName = city;
    _fromLat = center.latitude;
    _fromLng = center.longitude;
    try {
      final page = await _repo.search(
        fromLat: _fromLat,
        fromLng: _fromLng,
        toLat: widget.stayLat,
        toLng: widget.stayLng,
        pageSize: 3,
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _ready = true;
      });
    } catch (_) {}
  }

  void _seeAll() => TaxiNavigation.openList(
        fromName: _fromName,
        fromLat: _fromLat,
        fromLng: _fromLng,
        toName: widget.stayPlace,
        toLat: widget.stayLat,
        toLng: widget.stayLng,
      );

  @override
  Widget build(BuildContext context) {
    if (!_ready || _items.isEmpty) return widget.fallback;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Taxis to ${widget.stayPlace}',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            Text('From $_fromName',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          ]),
        ),
        GestureDetector(
          onTap: _seeAll,
          child: const Text('See all ›',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: TaxiColors.accentDark)),
        ),
      ]),
      const SizedBox(height: 10),
      for (final t in _items)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TaxiCard(
            item: t,
            onOpen: () => TaxiNavigation.openDetail(t.id, matchedFare: t.matchedFare, matchedToName: t.matchedToName),
          ),
        ),
    ]);
  }
}
