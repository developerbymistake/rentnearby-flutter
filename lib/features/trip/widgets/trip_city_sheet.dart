import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../services/storage_service.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../utils/input_formatters.dart';
import '../../../utils/search_fold.dart';
import '../data/trip_city_catalog.dart';
import '../data/trip_popular_routes.dart';
import '../data/trip_repository.dart';
import '../models/trip_city_model.dart';
import '../../../utils/app_toast.dart';
import '../trip_colors.dart';
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
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
          _buildHeader(),
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
        gradient: TripColors.gradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
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
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
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
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 0, 6, 0),
              decoration: BoxDecoration(color: TripColors.accent, borderRadius: BorderRadius.circular(999)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: TripColors.accentDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    c.name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.close_rounded, size: 14, color: Colors.white),
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
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: _continue,
          style: ElevatedButton.styleFrom(
            backgroundColor: TripColors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            _SheetText.continueCities(_picked.length),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: TextField(
        controller: _searchCtrl,
        cursorColor: TripColors.accent,
        inputFormatters: noEmojiInputFormatters,
        onChanged: _onSearch,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
        decoration: InputDecoration(
          hintText: _add ? TripStrings.searchCity : TripStringsV2Create.searchCity,
          hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textHint),
          filled: true,
          fillColor: TripColors.palette.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TripColors.accent, width: 1.5),
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
        children: _items.map((c) => _cityRow(c)).toList(),
      );
    }
    final nextKeys = {for (final c in _nextStops) c.cityKey};
    final rest = nextKeys.isEmpty ? _items : _items.where((c) => !nextKeys.contains(c.cityKey)).toList();
    final from = widget.afterCity?.trim() ?? '';
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: [
        if (_routes.isNotEmpty) ...[_sectionHeader(TripStringsMcaA2.popularRoutes), ..._routes.map(_routeRow)],
        if (_nextStops.isNotEmpty) ...[
          _sectionHeader(TripStringsMcaA2.popularNextStops),
          ..._nextStops.map((c) => _cityRow(c, subtitle: from.isEmpty ? null : TripStringsMcaA2.taxisGoFrom(from))),
        ],
        ..._sectionedRows(rest),
      ],
    );
  }

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
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textLight,
      ),
    ),
  );

  Widget _routeRow(({TripCityModel from, TripCityModel to}) r) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: _routeOn(r) ? TripColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _toggleRoute(r),
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Iconsax.routing_2, size: 17, color: TripColors.accentDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TripStringsMcaA2.routeTitle(r.from.name, r.to.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        TripStringsMcaA2.routeMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _routeOn(r) ? _tick() : const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tick() => Container(
    width: 22,
    height: 22,
    decoration: const BoxDecoration(color: TripColors.accent, shape: BoxShape.circle),
    child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
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

  Widget _cityRow(TripCityModel city, {String? subtitle}) {
    final ready = city.isReady;
    final inTrip = _add && widget.inTrip.contains(city.cityKey);
    final enabled = !inTrip;
    final color = enabled ? AppColors.textDark : AppColors.textHint;
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
        color: open || picked ? TripColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: enabled ? () => _add ? _toggle(city) : _togglePicked(city) : null,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                child: Row(
                  children: [
                    Icon(Iconsax.location, size: 17, color: color),
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
                              fontFamily: 'Poppins',
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
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (inTrip)
                      const Text(
                        TripStringsMcaA2.inThisTrip,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHint,
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
                                border: Border.all(color: AppColors.divider, width: 1.5),
                              ),
                            ))
                    else if (enabled) ...[
                      if (ready)
                        const Text(
                          TripStringsA4.ready,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.successText,
                          ),
                        ),
                      Icon(
                        open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 20,
                        color: AppColors.textHint,
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
    final IconData icon;
    if (s != null) {
      line = s.isEmpty ? TripStringsA4.noSupplyLine : TripStringsA4.supplyLine(s.stays, s.drivers);
      icon = s.isEmpty ? Iconsax.info_circle : Iconsax.building_4;
    } else if (failed) {
      line = TripStringsA4.supplyFailed;
      icon = Iconsax.cloud_cross;
    } else {
      line = TripStringsA4.supplyChecking;
      icon = Iconsax.clock;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(37, 0, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textMedium),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium),
                ),
              ),
              if (failed)
                TextButton(
                  onPressed: () => setState(() => _loadSupply(key)),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: const Text(
                    TripStrings.retry,
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: TripColors.accentDark),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: () => _add ? Navigator.pop(context, TripCityPick(city)) : _togglePicked(city),
              style: ElevatedButton.styleFrom(
                backgroundColor: TripColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _add
                    ? TripStringsMcaA2.addToTrip
                    : _isPicked(city)
                    ? _SheetText.remove
                    : _SheetText.addCity,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingIndicator() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: TripColors.accent),
      ),
    ),
  );

  Widget _emptyState(String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight),
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
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              TripStrings.retry,
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: TripColors.accent),
            ),
          ),
        ],
      ],
    ),
  );
}
