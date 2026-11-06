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
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../trip_strings_a4.dart';
import '../trip_strings_mca_a2.dart';

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
  final List<String> draftIds;

  const TripCityPick(this.city, {this.next, this.draftIds = const []});
}

class TripNewDraft {
  final TripCityModel city;
  final TripCityModel? next;
  final List<String> ids;
  final TripSettings? settings;

  const TripNewDraft(this.city, this.next, this.ids, [this.settings]);

  static TripNewDraft? read() {
    final m = StorageService.getTripNewDraft();
    if (m == null) return null;
    try {
      final city = TripCityModel.fromJson(Map<String, dynamic>.from(m['city'] as Map));
      final n = m['next'];
      final ids = ((m['ids'] as List?) ?? const []).whereType<String>().toList();
      if (ids.isEmpty) return null;
      final st = m['settings'];
      return TripNewDraft(
        city,
        n is Map ? TripCityModel.fromJson(Map<String, dynamic>.from(n)) : null,
        ids,
        st is Map ? TripSettings.fromJson(Map<String, dynamic>.from(st)) : null,
      );
    } catch (_) {
      return null;
    }
  }

  static void save(TripCityModel city, TripCityModel? next, Iterable<String> ids, {TripSettings? settings}) {
    final list = ids.toList();
    if (list.isEmpty) {
      if (read()?.city.cityKey == city.cityKey) StorageService.clearTripNewDraft();
      return;
    }
    final keep = settings ?? (read()?.city.cityKey == city.cityKey ? read()?.settings : null);
    StorageService.saveTripNewDraft(
        {'city': city.toJson(), 'next': ?next?.toJson(), 'ids': list, 'settings': ?keep?.toJson()});
  }

  static TripSettings? settingsFor(TripCityModel city) {
    final d = read();
    return d != null && d.city.cityKey == city.cityKey ? d.settings : null;
  }
}

class TripCitySheet extends StatefulWidget {
  final TripCitySheetMode mode;
  final String? afterCity;
  final Set<int> inTrip;

  const TripCitySheet({
    super.key,
    this.mode = TripCitySheetMode.start,
    this.afterCity,
    this.inTrip = const {},
  });

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TripCitySheet(mode: mode, afterCity: afterCity, inTrip: inTrip),
    );
  }

  @override
  State<TripCitySheet> createState() => _TripCitySheetState();
}

enum _LoadError { none, failed, plannerOff }

class _TripCitySheetState extends State<TripCitySheet> {
  final _searchCtrl = TextEditingController();
  TripNewDraft? _draft = TripNewDraft.read();
  late final TripCityCatalog _catalog;

  List<TripCityModel> _items = const [];
  List<({TripCityModel from, TripCityModel to, int days})> _routes = const [];
  List<TripCityModel> _nextStops = const [];
  String _query = '';
  bool _loading = false;
  _LoadError _error = _LoadError.none;
  int? _expanded;
  final _supply = <int, TripCitySupply>{};
  final _supplyFailed = <int>{};

  double? _baseHeight;
  double? _baseTopPadding;

  bool get _add => widget.mode == TripCitySheetMode.add;

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
          Expanded(child: _buildBody()),
          SizedBox(height: 12 + AppInsets.bottomViewPadding(context)),
        ],
      ),
    );
  }

  String get _subtitle {
    final after = widget.afterCity?.trim() ?? '';
    return _add && after.isNotEmpty ? TripStringsMcaA2.afterCity(after) : TripStrings.pickCity;
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
          hintText: TripStrings.searchCity,
          hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textHint),
          filled: true,
          fillColor: TripColors.palette.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
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
    final draft = _add ? null : _draft;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: [
        if (draft != null) ...[
          _sectionHeader(TripStrings.continueNewTrip),
          _draftRow(draft),
        ],
        if (_routes.isNotEmpty) ...[
          _sectionHeader(TripStringsMcaA2.popularRoutes),
          ..._routes.map(_routeRow),
        ],
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
      _sectionHeader(TripStrings.popular),
      ...popular.map((c) => _cityRow(c)),
      if (rest.isNotEmpty) ...[
        _sectionHeader(TripStrings.allCities),
        ...rest.map((c) => _cityRow(c)),
      ],
    ];
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight),
        ),
      );

  Widget _draftRow(TripNewDraft d) {
    return InkWell(
      onTap: () => Navigator.pop(context, TripCityPick(d.city, next: d.next, draftIds: d.ids)),
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Iconsax.edit_2, size: 17, color: TripColors.accentDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  TripStrings.draftPlaces(d.city.name, d.ids.length),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  StorageService.clearTripNewDraft();
                  _draft = null;
                }),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: const Text(TripStrings.startOver,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _routeRow(({TripCityModel from, TripCityModel to, int days}) r) {
    return InkWell(
      onTap: () => Navigator.pop(context, TripCityPick(r.from, next: r.to)),
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
                          fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    ),
                    Text(
                      TripStringsMcaA2.routeMeta(r.days),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }

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
    TripCitySupplyCache.load(key).then((s) {
      if (mounted) setState(() => _supply[key] = s);
    }).catchError((Object _) {
      if (mounted) setState(() => _supplyFailed.add(key));
    });
  }

  Widget _cityRow(TripCityModel city, {String? subtitle}) {
    final ready = city.isReady;
    final inTrip = _add && widget.inTrip.contains(city.cityKey);
    final enabled = !inTrip && (ready || _add);
    final color = enabled ? AppColors.textDark : AppColors.textHint;
    final place = inTrip
        ? TripStringsMcaA2.alreadyAdded
        : !ready && _add
            ? TripStringsMcaA2.noPlacesYet
            : subtitle ?? city.placeLine;
    final open = enabled && _expanded == city.cityKey;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: open ? TripColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: enabled ? () => _toggle(city) : null,
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
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w500, color: color),
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
                            fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textHint),
                      )
                    else if (enabled) ...[
                      if (ready)
                        const Text(
                          TripStringsA4.ready,
                          style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.successText),
                        ),
                      Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: AppColors.textHint),
                    ] else
                      const Text(
                        TripStrings.comingSoon,
                        style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textHint),
                      ),
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
              onPressed: () => Navigator.pop(context, TripCityPick(city)),
              style: ElevatedButton.styleFrom(
                backgroundColor: TripColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _add ? TripStringsMcaA2.addToTrip : TripStringsA4.planHere,
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
                  fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
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
