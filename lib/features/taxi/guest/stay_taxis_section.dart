import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_details.dart';
import '../../../controllers/location_controller.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../models/place_result_model.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../trip/controllers/trip_plan_controller.dart';
import '../../trip/models/trip_plan_model.dart';
import '../../trip/trip_strings_steps_a3.dart';
import '../../trip/trip_strings_city.dart';
import '../models/taxi_browse_item.dart';
import '../taxi_option_sets.dart';
import '../ways/models/taxi_ways_models.dart';
import '../ways/taxi_ways_navigation.dart';
import '../ways/taxi_ways_repository.dart';
import 'taxi_browse_repository.dart';
import 'taxi_card.dart';
import 'taxi_navigation.dart';
import 'traveller_city.dart';

enum _Phase { hidden, locating, loading, list, empty, unavailable, error, offline, summary, noWays, citiesLoading, noCity }

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

class _StayTaxisSectionState extends State<StayTaxisSection> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  _Phase? _playedPhase;
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
  String _summaryArt = ListingArt.bus;
  String? _tripId;
  DateTime? _tripDate;
  int? _tripPeople;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
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
    _anim.dispose();
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
    if (from == null) return;
    if (!TabConfigController.to.isTaxiActive) {
      if (mounted) setState(() => _phase = _Phase.hidden);
      return;
    }
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
          _summaryArt = r.allTheWay.isNotEmpty && !r.plans.any((p) => p.cars > 1) ? ListingArt.taxi : ListingArt.bus;
          _phase = r.hasWays ? _Phase.summary : _Phase.noWays;
        });
        return;
      }
      final city = await nearestCityOf(widget.toLat, widget.toLng);
      if (city == null) {
        if (mounted && myGen == _gen) setState(() => _phase = _Phase.citiesLoading);
        return;
      }
      if (!city.available) {
        if (mounted && myGen == _gen) setState(() => _phase = _Phase.noCity);
        return;
      }
      final page = await _repo.browseLocal(cityKey: city.cityKey, pageSize: _previewCount);
      if (!mounted || myGen != _gen) return;
      setState(() {
        _items = page.items.take(_previewCount).toList();
        _phase = _items.isEmpty ? _Phase.empty : _Phase.list;
      });
    } catch (e) {
      if (!mounted || myGen != _gen) return;
      setState(() => _phase = DioErrorMapper.errorType(e) == 'TripCitiesUnavailable'
          ? _Phase.citiesLoading
          : DioErrorMapper.isNetworkError(e)
              ? _Phase.offline
              : _Phase.error);
    }
  }

  DateTime get _date {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final d = _tripDate ?? widget.date;
    if (d == null) return DateTime(n.year, n.month, n.day + 1);
    final day = DateTime(d.year, d.month, d.day);
    if (day.isBefore(today)) return today;
    final limit = DateTime(n.year, n.month, n.day + 365);
    return day.isAfter(limit) ? limit : day;
  }

  int get _people => (_tripPeople ?? widget.people ?? 2).clamp(1, 12).toInt();

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
    if (_phase == _Phase.hidden) return const SizedBox.shrink();
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

    if (_phase != _playedPhase) {
      _playedPhase = _phase;
      if (_phase != _Phase.loading && _phase != _Phase.locating) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (MediaQuery.of(context).disableAnimations) {
            _anim.value = 1;
          } else {
            _anim.forward(from: 0);
          }
        });
      }
    }
    final body = switch (_phase) {
      _Phase.hidden => const <Widget>[],
      _Phase.locating => [_note(ListingArt.compass, 'Finding your city...')],
      _Phase.loading => [
          for (var i = 0; i < _previewCount; i++) const TaxiCardSkeleton(),
        ],
      _Phase.list => [
          for (final t in _items)
            TaxiCard(
              key: ValueKey(t.id),
              item: t,
              tone: DetailLook.chipCoral,
              inLabel: 'In $fromName',
              onOpen: () =>
                  TaxiNavigation.openDetail(t.id, matchedFare: t.matchedFare, matchedToName: t.matchedToName),
            ),
        ],
      _Phase.empty => [
          _note(
            ListingArt.taxi,
            local ? 'No local taxis in $fromName yet' : 'No taxis from $fromName to ${widget.stayCityName} yet',
            action: 'Search taxis',
            onTap: _seeAll,
          ),
        ],
      _Phase.unavailable => [
          _note(ListingArt.roundPushpin, 'Turn on location to see taxis from your city', action: 'Open Taxi', onTap: _seeAll),
        ],
      _Phase.error => [
          _note(ListingArt.taxi, local ? "Couldn't load taxis" : TripStringsStepsA3.waysFailed,
              action: TripStringsStepsA3.retry, onTap: _load),
        ],
      _Phase.citiesLoading => [
          _note(ListingArt.worldMap, '${TripStringsCity.citiesLoadingTitle}. ${TripStringsCity.citiesLoadingBody}',
              action: TripStringsStepsA3.retry, onTap: _load),
        ],
      _Phase.noCity => [_note(ListingArt.mountain, '${TripStringsCity.noTaxisTitle('')}. ${TripStringsCity.noSupplyBody}')],
      _Phase.offline => [
          _note(ListingArt.worldMap, TripStringsStepsA3.waysOffline, action: TripStringsStepsA3.retry, onTap: _load),
        ],
      _Phase.summary => [_note(_summaryArt, _summary, action: TripStringsStepsA3.seeWays, onTap: _openFeed)],
      _Phase.noWays => [
          _note(ListingArt.bus, TripStringsStepsA3.noWaysYet, action: TripStringsStepsA3.seeWays, onTap: _openFeed),
        ],
    };
    final animate = _phase != _Phase.loading && _phase != _Phase.locating;
    final count = (1 + body.length).clamp(1, 4);
    Widget wrap(int i, Widget child) => animate
        ? TemplateEntrance(
            animation: templateInterval(_anim, i.clamp(0, count - 1), count),
            animationController: _anim,
            child: child,
          )
        : child;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      wrap(0, _header(label: label, seeAll: local || from == null)),
      for (var i = 0; i < body.length; i++) wrap(i + 1, body[i]),
    ]);
  }

  Widget _note(String art, String text, {String? action, VoidCallback? onTap}) =>
      GettingThereNote(tone: ListingTone.forest, art: art, text: text, actionLabel: action, onAction: onTap);

  Widget _header({required String label, required bool seeAll}) =>
      GettingThereHeader(tone: ListingTone.forest, label: label, onSeeAll: seeAll ? _seeAll : null);
}
