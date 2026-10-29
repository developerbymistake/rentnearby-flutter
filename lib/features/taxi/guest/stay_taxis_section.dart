import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../controllers/location_controller.dart';
import '../models/taxi_browse_item.dart';
import '../taxi_option_sets.dart';
import 'taxi_browse_repository.dart';
import 'taxi_card.dart';
import 'taxi_list_controller.dart';
import 'taxi_navigation.dart';

class StayTaxisSection extends StatefulWidget {
  final double stayLat;
  final double stayLng;
  final String? stayCityName;
  final String? stayDistrictName;

  const StayTaxisSection({
    super.key,
    required this.stayLat,
    required this.stayLng,
    this.stayCityName,
    this.stayDistrictName,
  });

  @override
  State<StayTaxisSection> createState() => _StayTaxisSectionState();
}

class _StayTaxisSectionState extends State<StayTaxisSection> {
  static const _farMeters = 5000.0;

  final _repo = const TaxiBrowseRepository();
  List<TaxiBrowseItem> _items = const [];
  TaxiFromPlace? _from;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final from = TaxiListController.currentCity(Get.find<LocationController>());
    if (from == null) return;
    final p = from.place.latLng;
    if (TaxiOptionSets.distanceMeters(p.latitude, p.longitude, widget.stayLat, widget.stayLng) < _farMeters) return;
    setState(() {
      _from = from;
      _loading = true;
    });
    try {
      final page = await _repo.search(
        fromLat: p.latitude,
        fromLng: p.longitude,
        toLat: widget.stayLat,
        toLng: widget.stayLng,
        pageSize: 3,
      );
      if (!mounted) return;
      setState(() {
        _items = page.items.take(3).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _stayDistrict => widget.stayDistrictName?.trim() ?? '';

  String get _stayCity {
    final city = widget.stayCityName?.trim() ?? '';
    return city.isNotEmpty ? city : _stayDistrict;
  }

  String get _stayPlaceName => _stayCity.isNotEmpty ? _stayCity : 'This stay';

  bool get _showRoute => _from != null && (_loading || _items.isNotEmpty);

  void _seeAll() {
    final from = _from;
    if (_showRoute && from != null) {
      TaxiNavigation.openList(
        fromName: from.place.name,
        fromLat: from.place.latLng.latitude,
        fromLng: from.place.latLng.longitude,
        toName: _stayPlaceName,
        toLat: widget.stayLat,
        toLng: widget.stayLng,
      );
    } else {
      TaxiNavigation.openList(fromName: _stayPlaceName, fromLat: widget.stayLat, fromLng: widget.stayLng);
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = _showRoute;
    final district = _stayDistrict.isNotEmpty ? _stayDistrict : _stayCity;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header(
        label: route
            ? (district.isNotEmpty ? 'Taxis to $district' : 'Taxis to this stay')
            : (_stayCity.isNotEmpty ? 'Local taxis near $_stayCity' : 'Local taxis near this stay'),
        value: route ? 'From ${_from!.place.name}' : null,
      ),
      if (route && _loading)
        for (var i = 0; i < 3; i++) const Padding(padding: EdgeInsets.only(top: 10), child: TaxiCardSkeleton()),
      if (route && !_loading)
        for (final t in _items)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TaxiCard(
              key: ValueKey(t.id),
              item: t,
              onOpen: () => TaxiNavigation.openDetail(t.id, matchedFare: t.matchedFare, matchedToName: t.matchedToName),
            ),
          ),
    ]);
  }

  Widget _header({required String label, String? value}) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: TaxiColors.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Iconsax.car, size: 18, color: TaxiColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: value != null ? 11 : 13,
                      fontWeight: value != null ? FontWeight.w400 : FontWeight.w700,
                      color: value != null ? AppColors.textLight : AppColors.textDark,
                    )),
                if (value != null)
                  Text(value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ]),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: _seeAll,
            borderRadius: BorderRadius.circular(12),
            child: const SizedBox(
              height: 44,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('See all',
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: TaxiColors.accentDark)),
                  SizedBox(width: 2),
                  Icon(Iconsax.arrow_right_3, size: 14, color: TaxiColors.accentDark),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
