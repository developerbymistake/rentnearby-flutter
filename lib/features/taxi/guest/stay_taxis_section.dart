import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../config/app_colors.dart';
import '../../../controllers/location_controller.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../models/place_result_model.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../trip/controllers/trip_plan_controller.dart';
import '../../trip/models/trip_plan_model.dart';
import '../../trip/utils/trip_wizard_rules.dart';
import '../../trip/trip_strings_steps_a3.dart';
import '../models/taxi_browse_item.dart';
import '../taxi_option_sets.dart';
import '../ways/models/taxi_ways_models.dart';
import '../ways/taxi_ways_navigation.dart';
import '../ways/taxi_ways_repository.dart';
import 'taxi_browse_repository.dart';
import 'taxi_card.dart';
import 'taxi_navigation.dart';
import 'traveller_city.dart';

enum _Phase { locating, loading, list, empty, unavailable, error, offline, summary, noWays }

class StayTaxisSection extends StatefulWidget {
  final String? stayCityId;
  final String stayCityName;
  final double toLat;
  final double toLng;
  final DateTime? date;
  final int? people;

  const StayTaxisSection({
    super.key,
    this.date,
    this.people,
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
  final _waysRepo = const TaxiWaysRepository();
  final _loc = Get.find<LocationController>();
  Worker? _locWorker;
  List<TaxiBrowseItem> _items = const [];
  TaxiFromPlace? _from;
  _Phase _phase = _Phase.locating;
  int _gen = 0;
  String _summary = '';
  String? _tripId;
  DateTime? _tripDate;
  int? _tripPeople;

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
    final from = _tripFrom() ?? travellerCity(_loc);
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

  TaxiFromPlace? _tripFrom() {
    if (!Get.isRegistered<TripPlanController>()) return null;
    final c = Get.find<TripPlanController>();
    final t = c.trip.value;
    final start = c.startFrom;
    if (t == null || c.plan.value == null || c.isReadOnly || start == null) return null;
    final cityGap = TaxiOptionSets.distanceMeters(t.cityLatitude, t.cityLongitude, widget.toLat, widget.toLng);
    if (cityGap >= _sameCityMeters) return null;
    if (TaxiOptionSets.distanceMeters(start.lat, start.lon, widget.toLat, widget.toLng) < _sameCityMeters) return null;
    _tripId = t.id;
    _tripDate = c.stepDate(TripStepRole.gettingThere);
    final n = c.settings.peopleCount;
    _tripPeople = n > 0 ? n : null;
    return (place: PlaceResult(name: start.name, subtitle: '', latLng: LatLng(start.lat, start.lon)), districtId: '', cityId: null);
  }

  bool get _forTrip => _tripId != null;

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
      if (!_sameCity) {
        final r = await _waysRepo.ways(
          fromLat: p.latitude,
          fromLng: p.longitude,
          toLat: widget.toLat,
          toLng: widget.toLng,
          date: _date,
          people: _people,
          fromMyLocation: !_forTrip,
          fromName: from.place.name,
          toName: widget.stayCityName,
        );
        if (!mounted || myGen != _gen) return;
        setState(() {
          _summary = _summaryOf(r);
          _phase = r.hasWays ? _Phase.summary : _Phase.noWays;
        });
        return;
      }
      final page = await _repo.browseLocal(districtId: from.districtId, cityId: from.cityId, pageSize: _previewCount);
      if (!mounted || myGen != _gen) return;
      setState(() {
        _items = page.items.take(_previewCount).toList();
        _phase = _items.isEmpty ? _Phase.empty : _Phase.list;
      });
    } catch (e) {
      if (!mounted || myGen != _gen) return;
      setState(() => _phase = DioErrorMapper.isNetworkError(e) ? _Phase.offline : _Phase.error);
    }
  }

  DateTime get _date {
    final d = _tripDate ?? widget.date;
    if (d != null) return d;
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + 1);
  }

  int get _people => _tripPeople ?? widget.people ?? 2;

  static String _summaryOf(TaxiWaysResult r) {
    final direct = r.allTheWay;
    final plans = r.plans.where((p) => p.cars > 1).toList()..sort((a, b) => a.total.compareTo(b.total));
    if (direct.isNotEmpty) {
      final from = direct.map((d) => d.listedFare).reduce((a, b) => a < b ? a : b);
      if (plans.isEmpty) return TripStringsStepsA3.directOnly(direct.length, from);
      return TripStringsStepsA3.waysSummary(
        direct: direct.length,
        directFrom: from,
        cars: plans.first.cars,
        carsFrom: plans.first.total,
      );
    }
    if (plans.isEmpty) return TripStringsStepsA3.noWaysYet;
    final fewest = plans.map((p) => p.cars).reduce((a, b) => a < b ? a : b);
    return TripStringsStepsA3.noDirect(fewest);
  }

  void _openFeed() {
    final from = _from;
    if (from == null) return;
    TaxiWaysNavigation.openFeed(
      from: from.place,
      to: PlaceResult(name: widget.stayCityName, subtitle: '', latLng: LatLng(widget.toLat, widget.toLng)),
      fromMyLocation: !_forTrip,
      date: _forTrip ? _date : widget.date,
      people: _forTrip ? _people : widget.people,
      fromTrip: _forTrip || widget.date != null || widget.people != null,
      tripId: _tripId,
      tripRole: _forTrip ? TripStepRole.gettingThere.name : null,
      fromStep: _forTrip ? TripStepKey.gettingThere.id : null,
    );
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
    if (from == null) {
      label = TripStringsStepsA3.gettingThere;
    } else if (local) {
      label = TripStringsStepsA3.localTaxisIn(fromName);
    } else {
      label = TripStringsStepsA3.fromTo(fromName, widget.stayCityName);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header(label: label, seeAll: local || from == null),
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
        _Phase.error => [
            _note(local ? "Couldn't load taxis" : TripStringsStepsA3.waysFailed,
                action: TripStringsStepsA3.retry, onTap: _load),
          ],
        _Phase.offline => [_note(TripStringsStepsA3.waysOffline, action: TripStringsStepsA3.retry, onTap: _load)],
        _Phase.summary => [_note(_summary, action: TripStringsStepsA3.seeWays, onTap: _openFeed)],
        _Phase.noWays => [_note(TripStringsStepsA3.noWaysYet, action: TripStringsStepsA3.seeWays, onTap: _openFeed)],
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

  Widget _header({required String label, required bool seeAll}) {
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
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ]),
            ),
          ),
          if (seeAll) const SizedBox(width: 4),
          if (seeAll)
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
