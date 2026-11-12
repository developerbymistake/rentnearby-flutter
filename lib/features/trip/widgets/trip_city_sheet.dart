import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../../config/app_insets.dart';
import '../../../services/storage_service.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../utils/input_formatters.dart';
import '../data/trip_city_catalog.dart';
import '../data/trip_popular_routes.dart';
import '../../../utils/search_fold.dart';
import '../data/trip_repository.dart';
import '../models/trip_city_model.dart';
import '../../../utils/app_toast.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_a4.dart';
import '../trip_strings_mca_a2.dart';
import '../trip_strings_v2_create.dart';

class TripCitySupplyCache {
  static const _ttl = Duration(minutes: 10);
  static final _cache = <int, (TripCitySupply, DateTime)>{};
  static final _inFlight = <int, Future<TripCitySupply>>{};

  static TripCitySupply? cached(int cityKey) {
    final hit = _cache[cityKey];
    if (hit == null || DateTime.now().difference(hit.$2) > _ttl) return null;
    return hit.$1;
  }

  static Future<TripCitySupply> load(int cityKey) {
    final hit = cached(cityKey);
    if (hit != null) return Future.value(hit);
    return _inFlight[cityKey] ??= _fetch(cityKey).whenComplete(() => _inFlight.remove(cityKey));
  }

  static Future<TripCitySupply> _fetch(int cityKey) async {
    final s = await const TripRepository().citySupply(cityKey);
    _cache[cityKey] = (s, DateTime.now());
    return s;
  }
}

enum TripCitySheetMode { start, add }

class TripCityPick {
  final TripCityModel city;
  final TripCityModel? next;
  final List<TripCityModel> cities;
  final List<TripDraftLeg> draftLegs;

  TripCityPick(this.city, {this.next, List<TripCityModel>? cities, this.draftLegs = const []})
    : cities = cities ?? [city, ?next];

  List<String> get draftIds => draftLegs.isEmpty ? const [] : draftLegs.first.ids;
}

class TripDraftLeg {
  final TripCityModel city;
  final List<String> ids;

  const TripDraftLeg(this.city, this.ids);
}

class TripNewDraft {
  static const _version = 3;
  final List<TripDraftLeg> legs;
  final int? days;

  const TripNewDraft(this.legs, [this.days]);

  TripCityModel get city => legs.first.city;

  int get placeCount => legs.fold(0, (n, l) => n + l.ids.length);

  static TripNewDraft? read() {
    final m = StorageService.getTripNewDraft();
    if (m == null || m['v'] != _version) return null;
    try {
      final legs = <TripDraftLeg>[];
      for (final raw in (m['legs'] as List)) {
        final e = Map<String, dynamic>.from(raw as Map);
        legs.add(
          TripDraftLeg(
            TripCityModel.fromJson(Map<String, dynamic>.from(e['city'] as Map)),
            ((e['ids'] as List?) ?? const []).whereType<String>().toList(),
          ),
        );
      }
      if (legs.isEmpty || legs.every((l) => l.ids.isEmpty)) return null;
      final d = m['days'];
      return TripNewDraft(legs, d is num ? d.toInt() : null);
    } catch (_) {
      return null;
    }
  }

  static void save(List<TripDraftLeg> legs, {int? days}) {
    if (legs.isEmpty || legs.every((l) => l.ids.isEmpty)) {
      StorageService.clearTripNewDraft();
      return;
    }
    StorageService.saveTripNewDraft({
      'v': _version,
      'legs': [
        for (final l in legs) {'city': l.city.toJson(), 'ids': l.ids},
      ],
      'days': ?(days ?? read()?.days),
    });
  }
}

class TripCitySheet extends StatefulWidget {
  final TripCitySheetMode mode;
  final String? afterCity;
  final Set<int> inTrip;

  const TripCitySheet({super.key, this.mode = TripCitySheetMode.start, this.afterCity, this.inTrip = const {}});

  static Future<TripCityPick?> pick(
    BuildContext context, {
    TripCitySheetMode mode = TripCitySheetMode.start,
    String? afterCity,
    Set<int> inTrip = const {},
  }) {
    return showModalBottomSheet<TripCityPick>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DesignColors.surface,
      barrierColor: DesignColors.scrim,
      elevation: 0,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(borderRadius: CardRadius.sheet),
      builder: (_) => TripCitySheet(mode: mode, afterCity: afterCity, inTrip: inTrip),
    );
  }

  @override
  State<TripCitySheet> createState() => _TripCitySheetState();
}

enum _LoadError { none, failed, plannerOff }

class _SheetText {
  static const String addCity = 'Add city';
  static const String remove = 'Remove';
  static String continueCities(int n) => 'Continue ($n ${n == 1 ? 'city' : 'cities'})';
  static String maxCities(int n) => 'Up to $n cities';
}

class _TripCitySheetState extends State<TripCitySheet> {
  final _searchCtrl = TextEditingController();
  late final TripCityCatalog _catalog;

  List<TripCityModel> _items = const [];
  List<({TripCityModel from, TripCityModel to})> _routes = const [];
  List<TripCityModel> _nextStops = const [];
  String _query = '';
  bool _loading = false;
  _LoadError _error = _LoadError.none;
  int? _expanded;
  final _picked = <TripCityModel>[];
  final _supply = <int, TripCitySupply>{};
  final _supplyFailed = <int>{};

  double? _baseHeight;
  double? _baseTopPadding;

  bool get _add => widget.mode == TripCitySheetMode.add;

  bool _isPicked(TripCityModel c) => _picked.any((p) => p.cityKey == c.cityKey);

  void _togglePicked(TripCityModel c) {
    if (_isPicked(c)) {
      setState(() {
        _picked.removeWhere((p) => p.cityKey == c.cityKey);
        _expanded = null;
      });
      return;
    }
    if (_picked.length >= TripConstants.maxLegs) {
      AppToast.warning(_SheetText.maxCities(TripConstants.maxLegs));
      return;
    }
    setState(() {
      _picked.add(c);
      _expanded = null;
    });
  }

  void _continue() {
    if (_picked.isEmpty) return;
    Navigator.pop(context, TripCityPick(_picked.first, cities: List.of(_picked)));
  }

  bool _routeOn(({TripCityModel from, TripCityModel to}) r) =>
      _picked.length == 2 && _picked[0].cityKey == r.from.cityKey && _picked[1].cityKey == r.to.cityKey;

  void _toggleRoute(({TripCityModel from, TripCityModel to}) r) {
    setState(() {
      final on = _routeOn(r);
      _picked.clear();
      if (!on) _picked.addAll([r.from, r.to]);
      _expanded = null;
    });
  }

  void _refreshSuggestions() {
    final all = _catalog.search('');
    if (!_add) {
      _routes = TripPopularRoutes.resolve(all);
      _nextStops = const [];
      return;
    }
    _routes = const [];
    final key = _afterKey(all);
    _nextStops = key == null ? const [] : TripPopularRoutes.nextStops(all, key);
  }

  int? _afterKey(List<TripCityModel> all) {
    final name = SearchFold.fold(widget.afterCity);
    if (name.isEmpty) return null;
    int? fallback;
    for (final c in all) {
      if (SearchFold.fold(c.name) != name) continue;
      if (widget.inTrip.contains(c.cityKey)) return c.cityKey;
      fallback ??= c.cityKey;
    }
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _catalog = TripCityCatalog.to;
    _catalog.warmFromDisk();
    _items = _catalog.search('');
    _refreshSuggestions();
    _loading = _items.isEmpty;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _baseHeight ??= media.size.height;
    _baseTopPadding ??= media.padding.top;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _loading = _items.isEmpty;
      _error = _LoadError.none;
    });
    _load();
  }

  Future<void> _load() async {
    try {
      await _catalog.load();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = _catalog.search(_query);
        _refreshSuggestions();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = _catalog.search(_query);
        _refreshSuggestions();
        if (_items.isEmpty) {
          _error = DioErrorMapper.errorType(e) == TripErrorTypes.plannerDisabled
              ? _LoadError.plannerOff
              : _LoadError.failed;
        }
      });
    }
  }

  void _onSearch(String v) {
    setState(() {
      _query = v;
      _items = _catalog.search(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final baseHeight = _baseHeight ?? media.size.height;
    final baseTopPadding = _baseTopPadding ?? media.padding.top;
    final maxHeight = (baseHeight - baseTopPadding) * 0.94;
    final sheetHeight = (baseHeight * 0.75).clamp(0.0, maxHeight);
    return SizedBox(
      height: sheetHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TemplateEntranceOnce(duration: const Duration(milliseconds: 300), child: _buildHeader()),
          _buildSearchBox(),
          if (!_add && _picked.isNotEmpty) _pickedRow(),
          Expanded(child: _buildBody()),
          if (!_add && _picked.isNotEmpty) _continueBar(),
          SizedBox(height: 12 + AppInsets.bottomViewPadding(context)),
        ],
      ),
    );
  }

  String get _subtitle {
    final after = widget.afterCity?.trim() ?? '';
    return _add
        ? (after.isNotEmpty ? TripStringsMcaA2.afterCity(after) : TripStrings.pickCity)
        : TripStringsV2Create.citiesHint;
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: const BoxDecoration(
        gradient: TripEntryStyle.gradient,
        borderRadius: CardRadius.sheet,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: DesignColors.onPrimary.withValues(alpha: Alpha.half),
              borderRadius: CardRadius.pill,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _add ? TripStringsMcaA2.addACity : TripStrings.planATrip,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.27,
                        color: DesignColors.onPrimary,
                      ),
                    ),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: FitnessAppTheme.fontName,
                        fontSize: 12,
                        color: DesignColors.onPrimary.withValues(alpha: Alpha.high),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pickedRow() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
        itemCount: _picked.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = _picked[i];
          return InkWell(
            onTap: () => _togglePicked(c),
            borderRadius: CardRadius.tile,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 0, 6, 0),
              decoration: BoxDecoration(color: TripEntryStyle.accent, borderRadius: CardRadius.tile),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: DesignColors.onPrimary, shape: BoxShape.circle),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: TripEntryStyle.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    c.name,
                    style: const TextStyle(
                      fontFamily: FitnessAppTheme.fontName,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: DesignColors.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.close_rounded, size: 14, color: DesignColors.onPrimary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _continueBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: TripGradientButton(
        label: _SheetText.continueCities(_picked.length),
        height: 48,
        onPressed: _continue,
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: TextField(
        controller: _searchCtrl,
        cursorColor: TripEntryStyle.accent,
        inputFormatters: noEmojiInputFormatters,
        onChanged: _onSearch,
        style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 14),
        decoration: InputDecoration(
          hintText: _add ? TripStrings.searchCity : TripStringsV2Create.searchCity,
          hintStyle: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 14, color: FitnessAppTheme.deactivatedText),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: FitnessAppTheme.deactivatedText),
          filled: true,
          fillColor: TripEntryStyle.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: const OutlineInputBorder(borderRadius: CardRadius.tile, borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: CardRadius.tile,
            borderSide: const BorderSide(color: TripEntryStyle.accent, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_items.isEmpty) {
      if (_loading) return _loadingIndicator();
      switch (_error) {
        case _LoadError.plannerOff:
          return _messageState(TripStrings.plannerOff, TripStrings.plannerOffSubtitle);
        case _LoadError.failed:
          return _messageState(TripStrings.citiesFailed, TripStrings.checkConnection, onRetry: _retry);
        case _LoadError.none:
          break;
      }
      if (_query.trim().isEmpty) return _messageState(TripStrings.noCitiesYet, TripStrings.noCitiesYetSubtitle);
      return _emptyState(TripStrings.noCityMatch(_query));
    }
    final browsing = _query.trim().isEmpty;
    if (!browsing) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: _stag(_items.map((c) => _cityRow(c)).toList()),
      );
    }
    final nextKeys = {for (final c in _nextStops) c.cityKey};
    final rest = nextKeys.isEmpty ? _items : _items.where((c) => !nextKeys.contains(c.cityKey)).toList();
    final from = widget.afterCity?.trim() ?? '';
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: _stag([
        if (_routes.isNotEmpty) ...[_sectionHeader(TripStringsMcaA2.popularRoutes), ..._routes.map(_routeRow)],
        if (_nextStops.isNotEmpty) ...[
          _sectionHeader(TripStringsMcaA2.popularNextStops),
          ..._nextStops.map((c) => _cityRow(c, subtitle: from.isEmpty ? null : TripStringsMcaA2.taxisGoFrom(from))),
        ],
        ..._sectionedRows(rest),
      ]),
    );
  }

  List<Widget> _stag(List<Widget> rows) => [
        for (var i = 0; i < rows.length; i++)
          i < 6 ? TemplateEntranceOnce(index: i, count: 6, child: rows[i]) : rows[i],
      ];

  List<Widget> _sectionedRows(List<TripCityModel> items) {
    if (!items.any((c) => c.isPopularDestination)) {
      return [
        if (_routes.isNotEmpty || _nextStops.isNotEmpty) _sectionHeader(TripStrings.allCities),
        ...items.map((c) => _cityRow(c)),
      ];
    }
    final popular = items.where((c) => c.isPopularDestination).toList();
    final rest = items.where((c) => !c.isPopularDestination).toList();
    return [
      _sectionHeader(_add ? TripStrings.popular : TripStringsV2Create.popularCities),
      ...popular.map((c) => _cityRow(c)),
      if (rest.isNotEmpty) ...[_sectionHeader(TripStrings.allCities), ...rest.map((c) => _cityRow(c))],
    ];
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: FitnessAppTheme.fontName,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: FitnessAppTheme.lightText,
      ),
    ),
  );

  Widget _tick() => Container(
    width: 22,
    height: 22,
    decoration: const BoxDecoration(color: TripEntryStyle.accent, shape: BoxShape.circle),
    child: const Icon(Icons.check_rounded, size: 15, color: DesignColors.onPrimary),
  );

  void _toggle(TripCityModel city) {
    final key = city.cityKey;
    if (_expanded == key) {
      setState(() => _expanded = null);
      return;
    }
    setState(() => _expanded = key);
    _loadSupply(key);
  }

  void _loadSupply(int key) {
    final hit = TripCitySupplyCache.cached(key);
    if (hit != null) {
      _supply[key] = hit;
      _supplyFailed.remove(key);
      return;
    }
    _supplyFailed.remove(key);
    TripCitySupplyCache.load(key)
        .then((s) {
          if (mounted) setState(() => _supply[key] = s);
        })
        .catchError((Object _) {
          if (mounted) setState(() => _supplyFailed.add(key));
        });
  }

  Widget _routeRow(({TripCityModel from, TripCityModel to}) r) {
    final on = _routeOn(r);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: on ? TripEntryStyle.surface : Colors.transparent,
        borderRadius: CardRadius.tile,
      ),
      child: InkWell(
        onTap: () => _toggleRoute(r),
        borderRadius: CardRadius.tile,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: TripEntryStyle.surface, borderRadius: CardRadius.tile),
                  child: const Icon(Icons.alt_route_rounded, size: 18, color: TripEntryStyle.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TripStringsMcaA2.routeTitle(r.from.name, r.to.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: FitnessAppTheme.fontName,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: FitnessAppTheme.darkerText,
                        ),
                      ),
                      const Text(
                        TripStringsMcaA2.routeMeta,
                        style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: FitnessAppTheme.lightText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                on
                    ? const Icon(Icons.check_circle_rounded, size: 22, color: TripEntryStyle.accent)
                    : const Icon(Icons.chevron_right_rounded, size: 20, color: FitnessAppTheme.deactivatedText),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cityRow(TripCityModel city, {String? subtitle}) {
    final ready = city.isReady;
    final inTrip = _add && widget.inTrip.contains(city.cityKey);
    final enabled = !inTrip;
    final color = enabled ? FitnessAppTheme.darkerText : FitnessAppTheme.deactivatedText;
    final place = inTrip
        ? TripStringsMcaA2.alreadyAdded
        : !ready
        ? TripStringsMcaA2.noPlacesYet
        : subtitle ?? (!_add && city.spotCount > 0 ? TripStringsV2Create.cityMeta(city.spotCount) : city.placeLine);
    final picked = !_add && _isPicked(city);
    final open = _add && enabled && _expanded == city.cityKey;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: open || picked ? TripEntryStyle.surface : Colors.transparent,
        borderRadius: CardRadius.tile,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: enabled ? () => _add ? _toggle(city) : _togglePicked(city) : null,
            borderRadius: CardRadius.tile,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                child: Row(
                  children: [
                    TravelIcon(TravelIcon.place, size: 17),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            city.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: FitnessAppTheme.fontName,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: color,
                            ),
                          ),
                          if (place.isNotEmpty)
                            Text(
                              place,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: FitnessAppTheme.lightText),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (inTrip)
                      const Text(
                        TripStringsMcaA2.inThisTrip,
                        style: TextStyle(
                          fontFamily: FitnessAppTheme.fontName,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: FitnessAppTheme.deactivatedText,
                        ),
                      )
                    else if (enabled && !_add)
                      (picked
                          ? _tick()
                          : Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: FitnessAppTheme.grey.withValues(alpha: Alpha.strong), width: 1.5),
                              ),
                            ))
                    else if (enabled) ...[
                      if (ready)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: const BoxDecoration(
                            color: TripEntryStyle.skyTint,
                            borderRadius: BorderRadius.all(Radius.circular(16.0)),
                          ),
                          child: const Text(
                            TripStringsA4.ready,
                            style: TextStyle(
                              fontFamily: FitnessAppTheme.fontName,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: TravelPalette.skyEnd,
                            ),
                          ),
                        ),
                      Icon(
                        open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 20,
                        color: FitnessAppTheme.deactivatedText,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (open) _supplyPanel(city),
        ],
      ),
    );
  }

  Widget _supplyPanel(TripCityModel city) {
    final key = city.cityKey;
    final s = _supply[key];
    final failed = _supplyFailed.contains(key);
    final String line;
    final String icon;
    if (s != null) {
      line = s.isEmpty ? TripStringsA4.noSupplyLine : TripStringsA4.supplyLine(s.stays, s.drivers);
      icon = s.isEmpty ? TravelIcon.route : TravelIcon.stay;
    } else if (failed) {
      line = TripStringsA4.supplyFailed;
      icon = TravelIcon.map;
    } else {
      line = TripStringsA4.supplyChecking;
      icon = TravelIcon.calendar;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(37, 0, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TravelIcon(icon, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: FitnessAppTheme.grey),
                ),
              ),
              if (failed)
                TextButton(
                  onPressed: () => setState(() => _loadSupply(key)),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: const Text(
                    TripStrings.retry,
                    style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontWeight: FontWeight.w600, color: TripEntryStyle.accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TripGradientButton(
            height: 44,
            onPressed: () => _add ? Navigator.pop(context, TripCityPick(city)) : _togglePicked(city),
            label: _add
                ? TripStringsMcaA2.addToTrip
                : _isPicked(city)
                    ? _SheetText.remove
                    : _SheetText.addCity,
          ),
        ],
      ),
    );
  }

  Widget _loadingIndicator() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Column(
      children: [
        for (var i = 0; i < 6; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                TemplatePlaceholder(height: 24, width: 24, radius: 12),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(widthFactor: 0.6, child: TemplatePlaceholder(height: 14)),
                      SizedBox(height: 6),
                      FractionallySizedBox(widthFactor: 0.35, child: TemplatePlaceholder(height: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _emptyState(String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, color: FitnessAppTheme.lightText),
      ),
    ),
  );

  Widget _messageState(String title, String subtitle, {VoidCallback? onRetry}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: FitnessAppTheme.fontName,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: FitnessAppTheme.darkerText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, color: FitnessAppTheme.lightText),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              TripStrings.retry,
              style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontWeight: FontWeight.w600, color: TripEntryStyle.accent),
            ),
          ),
        ],
      ],
    ),
  );
}
