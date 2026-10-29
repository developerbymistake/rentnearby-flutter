import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../controllers/location_controller.dart';
import '../../../controllers/tab_config_controller.dart';
import '../models/taxi_browse_item.dart';
import '../taxi_option_sets.dart';
import 'taxi_browse_repository.dart';
import 'taxi_card.dart';
import 'taxi_navigation.dart';
import 'traveller_city.dart';

enum _Phase { locating, loading, list, empty, unavailable, error }

class StayTaxisSection extends StatefulWidget {
  final String? stayCityId;
  final String stayCityName;
  final double toLat;
  final double toLng;

  const StayTaxisSection({
    super.key,
    this.stayCityId,
    required this.stayCityName,
    required this.toLat,
    required this.toLng,
  });

  @override
  State<StayTaxisSection> createState() => _StayTaxisSectionState();
}

class _StayTaxisSectionState extends State<StayTaxisSection> {
  static const _sameCityMeters = 5000.0;
  static const _previewCount = 3;

  final _repo = const TaxiBrowseRepository();
  final _loc = Get.find<LocationController>();
  Worker? _locWorker;
  List<TaxiBrowseItem> _items = const [];
  TaxiFromPlace? _from;
  _Phase _phase = _Phase.locating;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _resolveFrom();
    if (_from == null) {
      _locWorker = everAll(
        [_loc.autoCity, _loc.userLocation, _loc.selectedDistrict, _loc.locationLoading],
        (_) => _resolveFrom(),
      );
    }
  }

  @override
  void dispose() {
    _locWorker?.dispose();
    super.dispose();
  }

  void _resolveFrom() {
    if (!mounted || _from != null) return;
    final from = travellerCity(_loc);
    if (from == null) {
      final next = _loc.locationLoading.value ? _Phase.locating : _Phase.unavailable;
      if (next != _phase) setState(() => _phase = next);
      return;
    }
    _locWorker?.dispose();
    _locWorker = null;
    _from = from;
    _load();
  }

  bool get _sameCity {
    final from = _from;
    if (from == null) return false;
    final cityId = from.cityId;
    if (cityId != null && widget.stayCityId != null) return cityId == widget.stayCityId;
    final p = from.place.latLng;
    return TaxiOptionSets.distanceMeters(p.latitude, p.longitude, widget.toLat, widget.toLng) < _sameCityMeters;
  }

  Future<void> _load() async {
    final from = _from;
    if (from == null || !TabConfigController.to.isTaxiActive) return;
    final myGen = ++_gen;
    setState(() => _phase = _Phase.loading);
    try {
      final p = from.place.latLng;
      final page = _sameCity
          ? await _repo.browseLocal(districtId: from.districtId, cityId: from.cityId, pageSize: _previewCount)
          : await _repo.search(
              fromLat: p.latitude,
              fromLng: p.longitude,
              toLat: widget.toLat,
              toLng: widget.toLng,
              pageSize: _previewCount,
            );
      if (!mounted || myGen != _gen) return;
      setState(() {
        _items = page.items.take(_previewCount).toList();
        _phase = _items.isEmpty ? _Phase.empty : _Phase.list;
      });
    } catch (_) {
      if (mounted && myGen == _gen) setState(() => _phase = _Phase.error);
    }
  }

  void _seeAll() {
    if (_sameCity) {
      TaxiNavigation.openList();
      return;
    }
    TaxiNavigation.openList(
      toName: widget.stayCityName,
      toLat: widget.toLat,
      toLng: widget.toLng,
      toCityId: widget.stayCityId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final from = _from;
    final local = from != null && _sameCity;
    final fromName = from?.place.name ?? '';
    final String label;
    final String? value;
    if (from == null) {
      label = 'Taxis to ${widget.stayCityName}';
      value = null;
    } else if (local) {
      label = 'Local taxis in $fromName';
      value = null;
    } else {
      label = 'Taxis to ${widget.stayCityName}';
      value = 'From $fromName';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header(label: label, value: value),
      ...switch (_phase) {
        _Phase.locating => [_note('Finding your city...')],
        _Phase.loading => [
            for (var i = 0; i < _previewCount; i++)
              const Padding(padding: EdgeInsets.only(top: 10), child: TaxiCardSkeleton()),
          ],
        _Phase.list => [
            for (final t in _items)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TaxiCard(
                  key: ValueKey(t.id),
                  item: t,
                  onOpen: () =>
                      TaxiNavigation.openDetail(t.id, matchedFare: t.matchedFare, matchedToName: t.matchedToName),
                ),
              ),
          ],
        _Phase.empty => [
            _note(
              local
                  ? 'No local taxis in $fromName yet'
                  : 'No taxis from $fromName to ${widget.stayCityName} yet',
              action: 'Search taxis',
              onTap: _seeAll,
            ),
          ],
        _Phase.unavailable => [
            _note('Turn on location to see taxis from your city', action: 'Open Taxi', onTap: _seeAll),
          ],
        _Phase.error => [_note("Couldn't load taxis", action: 'Retry', onTap: _load)],
      },
    ]);
  }

  Widget _note(String text, {String? action, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: TaxiColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Expanded(
            child: Text(text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium, height: 1.4)),
          ),
          if (action != null && onTap != null) ...[
            const SizedBox(width: 4),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: TaxiColors.accentDark,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(action,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
    );
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
