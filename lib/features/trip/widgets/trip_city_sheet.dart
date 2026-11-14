import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/sheet_close_button.dart';
import 'package:flutter/material.dart';
import '../../../config/app_insets.dart';
import '../../../services/storage_service.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../utils/input_formatters.dart';
import '../data/trip_city_catalog.dart';
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
    return showDockSheet<TripCityPick>(
      context,
      backgroundColor: DesignColors.scaffold,
      barrierColor: DesignColors.scrim,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
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

  @override
  void initState() {
    super.initState();
    _catalog = TripCityCatalog.to;
    _catalog.warmFromDisk();
    _items = _catalog.search('');
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = _catalog.search(_query);
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
    final sheetHeight = (baseHeight * 0.94).clamp(0.0, maxHeight);
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
          ColoredBox(
            color: !_add && _picked.isNotEmpty ? DesignColors.surface : DesignColors.scaffold,
            child: SizedBox(height: 14 + AppInsets.bottomViewPadding(context)),
          ),
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

  static final ListingTone _tone = ListingTone.indigo;

  Widget _buildHeader() {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final art = narrow ? 84.0 : 104.0;
    final header = Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: EdgeInsets.fromLTRB(22, 22, art + 66, 18),
      decoration: BoxDecoration(gradient: _tone.gradient),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _add ? TripStringsMcaA2.addACity : TripStrings.planATrip,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ink3D.text(22, FontWeight.w700, DesignColors.textInverse),
              ),
              const SizedBox(height: 2),
              Text(_subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, DesignColors.whiteHigh)),
            ],
          ),
          Positioned(
            right: -art - 10,
            top: -12,
            child: IgnorePointer(
              child: Art3D(asset: ListingArt.luggage, size: art, halo: art + 10, haloColor: DesignColors.tint(DesignColors.surface, Alpha.v22)),
            ),
          ),
        ],
      ),
    );
    return Stack(children: [header, const Positioned(top: 4, right: 4, child: SheetCloseButton())]);
  }

  Widget _pickedRow() {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
        itemCount: _picked.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = _picked[i];
          return Tap3D(
            onTap: () => _togglePicked(c),
            label: '${c.name}, ${_SheetText.remove}',
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
              decoration: BoxDecoration(
                gradient: _tone.gradient,
                borderRadius: CardRadius.pill,
                boxShadow: [BoxShadow(color: _tone.shadow, offset: const Offset(1, 3), blurRadius: 6)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: DesignColors.surface, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: Ink3D.text(12, FontWeight.w700, _tone.text)),
                  ),
                  const SizedBox(width: 8),
                  Text(c.name, style: Ink3D.text(13, FontWeight.w700, DesignColors.textInverse)),
                  const SizedBox(width: 4),
                  const Icon(Icons.close_rounded, size: 16, color: DesignColors.surface),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _continueBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      decoration: const BoxDecoration(color: DesignColors.surface, boxShadow: Ink3D.topEdge),
      child: GradientPillButton(tone: _tone, label: _SheetText.continueCities(_picked.length), onTap: _continue),
    );
  }

  Widget _buildSearchBox() {
    return SheetSearchField(
      tone: _tone,
      controller: _searchCtrl,
      hint: _add ? TripStrings.searchCity : TripStringsV2Create.searchCity,
      trailingArt: ListingArt.search,
      inputFormatters: noEmojiInputFormatters,
      onChanged: _onSearch,
      margin: const EdgeInsets.fromLTRB(18, 16, 18, 8),
    );
  }

  Widget _group(List<Widget> rows) => Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 6),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
            topRight: Radius.circular(28),
          ),
          boxShadow: Ink3D.softShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
      );

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
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        children: [_group([for (var i = 0; i < _items.length; i++) _cityRow(_items[i], divider: i > 0)])],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: _stag(_sectionedRows(_items)),
    );
  }

  List<Widget> _stag(List<Widget> rows) => [
        for (var i = 0; i < rows.length; i++)
          i < 6 ? TemplateEntranceOnce(index: i, count: 6, child: rows[i]) : rows[i],
      ];

  Widget _list(List<TripCityModel> items) => _group([for (var i = 0; i < items.length; i++) _cityRow(items[i], divider: i > 0)]);

  List<Widget> _sectionedRows(List<TripCityModel> items) {
    if (!items.any((c) => c.isPopularDestination)) {
      return [if (items.isNotEmpty) _list(items)];
    }
    final popular = items.where((c) => c.isPopularDestination).toList();
    final rest = items.where((c) => !c.isPopularDestination).toList();
    return [
      _sectionHeader(_add ? TripStrings.popular : TripStringsV2Create.popularCities),
      _list(popular),
      if (rest.isNotEmpty) ...[_sectionHeader(TripStrings.allCities), _list(rest)],
    ];
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
        child: Text(
          text.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Ink3D.text(11.5, FontWeight.w700, Ink3D.grey, letterSpacing: 0.8),
        ),
      );

  Widget _ring() => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Ink3D.hint, width: 1.5)),
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

  static String _artOf(TripCityModel c, bool ready) {
    if (!ready) return ListingArt.tent;
    const arts = [ListingArt.mountain, ListingArt.camping, ListingArt.beach, ListingArt.sunrise];
    return arts[c.cityKey.abs() % arts.length];
  }

  Widget _cityRow(TripCityModel city, {bool divider = false}) {
    final ready = city.isReady;
    final inTrip = _add && widget.inTrip.contains(city.cityKey);
    final enabled = !inTrip;
    final place = inTrip
        ? TripStringsMcaA2.alreadyAdded
        : !ready
        ? TripStringsMcaA2.noPlacesYet
        : (!_add && city.spotCount > 0 ? TripStringsV2Create.cityMeta(city.spotCount) : city.placeLine);
    final picked = !_add && _isPicked(city);
    final open = _add && enabled && _expanded == city.cityKey;
    final Widget? trailing;
    if (inTrip) {
      trailing = Text(TripStringsMcaA2.inThisTrip, style: Ink3D.text(11.5, FontWeight.w600, Ink3D.hint));
    } else if (!_add) {
      trailing = picked ? null : _ring();
    } else {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ready)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _tone.tint, borderRadius: CardRadius.pill),
              child: Text(TripStringsA4.ready, style: Ink3D.text(11, FontWeight.w700, _tone.text)),
            ),
          Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 22, color: _tone.text),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetListRow(
          tone: _tone,
          art: _artOf(city, ready),
          title: city.name,
          subtitle: place.isEmpty ? null : place,
          selected: picked,
          enabled: enabled,
          divider: divider,
          onTap: enabled ? () => _add ? _toggle(city) : _togglePicked(city) : null,
          trailing: trailing,
        ),
        if (open) _supplyPanel(city),
      ],
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
      icon = s.isEmpty ? ListingArt.compass : ListingArt.hotel;
    } else if (failed) {
      line = TripStringsA4.supplyFailed;
      icon = ListingArt.worldMap;
    } else {
      line = TripStringsA4.supplyChecking;
      icon = ListingArt.calendar;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Art3D(asset: icon, size: 26, shadowBlur: 2, shadowOffset: const Offset(1, 2)),
              const SizedBox(width: 8),
              Expanded(child: Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Ink3D.grey))),
              if (failed)
                Tap3D(
                  onTap: () => setState(() => _loadSupply(key)),
                  label: TripStrings.retry,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    child: Center(child: Text(TripStrings.retry, style: Ink3D.text(13, FontWeight.w700, _tone.text))),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          GradientPillButton(
            tone: _tone,
            height: 46,
            fontSize: 15,
            onTap: () => _add ? Navigator.pop(context, TripCityPick(city)) : _togglePicked(city),
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

  Widget _loadingIndicator() => ListView(
        padding: const EdgeInsets.only(top: 14),
        physics: const NeverScrollableScrollPhysics(),
        children: [_group([for (var i = 0; i < 5; i++) const SkeletonListRow()])],
      );

  Widget _emptyState(String message) => ListView(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
        children: [StateCard3D(tone: _tone, art: ListingArt.compass, layout: StateLayout.plain, title: message)],
      );

  Widget _messageState(String title, String subtitle, {VoidCallback? onRetry}) => ListView(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
        children: [
          StateCard3D(
            tone: _tone,
            art: onRetry != null ? ListingArt.worldMap : ListingArt.luggage,
            layout: StateLayout.plain,
            title: title,
            message: subtitle,
            actionLabel: onRetry == null ? null : TripStrings.retry,
            onAction: onRetry,
          ),
        ],
      );
}
