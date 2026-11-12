import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../utils/input_formatters.dart';
import '../controllers/my_trips_controller.dart';
import '../data/trip_city_catalog.dart';
import '../models/trip_city_model.dart';
import '../models/trip_model.dart';
import '../data/trip_repository.dart' show TripErrorTypes;
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_tab.dart';
import '../utils/trip_bar_rules.dart';
import '../widgets/trip_city_tile.dart';

enum _Load { loading, ready, failed, plannerOff }

class TripsDiscoveryScreen extends StatefulWidget {
  const TripsDiscoveryScreen({super.key});

  @override
  State<TripsDiscoveryScreen> createState() => _TripsDiscoveryScreenState();
}

class _TripsDiscoveryScreenState extends State<TripsDiscoveryScreen> {
  static const double _maxWidth = 640;
  static const double _tileExtent = 180;
  static const double _gap = 12;

  static const _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: _tileExtent,
    mainAxisSpacing: _gap,
    crossAxisSpacing: _gap,
    childAspectRatio: TripCityTile.aspect,
  );

  final _search = TextEditingController();
  late final TripCityCatalog _catalog;
  late final MyTripsController _trips;
  Worker? _tabWorker;
  List<TripCityModel> _cities = const [];
  List<String> _states = const [];
  String? _state;
  String _query = '';
  _Load _load = _Load.loading;

  bool get _typing => _query.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _catalog = TripCityCatalog.to;
    _trips = MyTripsController.to;
    _catalog.warmFromDisk();
    _apply();
    _trips.ensureLoaded();
    _refresh();
    if (Get.isRegistered<AuthController>()) {
      _tabWorker = ever<int>(Get.find<AuthController>().tabIndex, (i) {
        if (i != AppTabs.trips || !mounted) return;
        _trips.refreshIfStale();
        _refresh();
      });
    }
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    _search.dispose();
    super.dispose();
  }

  void _apply() {
    _states = _catalog.liveStates();
    if (_state != null && !_states.contains(_state)) _state = null;
    _cities = _catalog.ready(_query, stateName: _state);
    if (_catalog.hasData) _load = _Load.ready;
  }

  Future<void> _refresh({bool force = false}) async {
    try {
      await _catalog.load(force: force);
      if (!mounted) return;
      setState(_apply);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _apply();
        if (!_catalog.hasData) {
          _load = DioErrorMapper.errorType(e) == TripErrorTypes.plannerDisabled ? _Load.plannerOff : _Load.failed;
        }
      });
    }
  }

  void _retry() {
    setState(() => _load = _Load.loading);
    _refresh(force: true);
  }

  void _onSearch(String v) => setState(() {
        _query = v;
        _apply();
      });

  void _clearSearch() {
    _search.clear();
    _onSearch('');
  }

  void _pickState(String? s) => setState(() {
        _state = s;
        _apply();
      });

  void _continue(TripSummaryModel t) {
    Get.toNamed(AppRoutes.tripPlan, arguments: TripBarRules.continueArgs(t))?.then((_) {
      if (mounted) _trips.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final side = w > _maxWidth ? (w - _maxWidth) / 2 : KitMetrics.gutter;
    final page = Scaffold(
      backgroundColor: DesignColors.scaffold,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: const ModuleHeader(title: TripStringsTab.title, tone: KitTone.trip, tabRoot: true),
          ),
          Expanded(
            child: RefreshIndicator(
              color: KitTone.trip.accentDark,
              onRefresh: () async {
                _trips.load();
                await _refresh(force: true);
              },
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(side, ModuleHeader.contentGap, side, 0),
                    sliver: SliverToBoxAdapter(child: _top()),
                  ),
                  ..._body(side),
                  SliverToBoxAdapter(child: SizedBox(height: BarMetrics.bodyBottomOf(context))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return TabEntrance(tab: AppTabs.trips, child: page);
  }

  Widget _top() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _searchBox(),
          const SizedBox(height: 12),
          _filterRow(),
          if (!_typing) ...[
            Obx(() {
              final t = _trips.continueTrip;
              return t == null ? const SizedBox.shrink() : _continueCard(t);
            }),
            const SizedBox(height: 20),
            Text(TripStringsTab.sectionTitle, style: TypeTokens.style(18, FontWeight.w700, letterSpacing: 0.2)),
            const SizedBox(height: 2),
            Text(TripStringsTab.sectionSub, style: TypeTokens.style(13, FontWeight.w400, color: TypeTokens.secondary)),
          ],
          const SizedBox(height: 12),
        ],
      );

  Widget _searchBox() => TextField(
        controller: _search,
        onChanged: _onSearch,
        inputFormatters: noEmojiInputFormatters,
        textInputAction: TextInputAction.search,
        cursorColor: KitTone.trip.accentDark,
        style: TypeTokens.style(14, FontWeight.w500),
        decoration: InputDecoration(
          hintText: TripStringsTab.searchHint,
          hintStyle: TypeTokens.style(14, FontWeight.w400, color: TypeTokens.secondary),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: DesignColors.textGrey),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: TripStringsTab.clearSearch,
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close_rounded, size: 18, color: DesignColors.textGrey),
                ),
          filled: true,
          fillColor: DesignColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: const OutlineInputBorder(borderRadius: KitMetrics.buttonRadius, borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: KitMetrics.buttonRadius,
            borderSide: BorderSide(color: KitTone.trip.accentDark, width: 1.5),
          ),
        ),
      );

  Widget _filterRow() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Obx(() => _chip(
                  TripStringsTab.myTripsCount(_trips.openTripCount),
                  selected: false,
                  icon: Icons.luggage_rounded,
                  onTap: TripNavigation.openMyTrips,
                )),
            if (_states.length >= 2) ...[
              const SizedBox(width: 8),
              _chip(TripStringsTab.all, selected: _state == null, onTap: () => _pickState(null)),
              for (final s in _states) ...[
                const SizedBox(width: 8),
                _chip(s, selected: _state == s, onTap: () => _pickState(s)),
              ],
            ],
          ],
        ),
      );

  Widget _chip(String label, {required bool selected, required VoidCallback onTap, IconData? icon}) {
    const tone = KitTone.trip;
    final fg = selected ? DesignColors.onPrimary : tone.accentDark;
    return PressScale(
      child: Material(
        color: selected ? tone.accentDark : DesignColors.surface,
        borderRadius: CardRadius.pill,
        child: InkWell(
          onTap: onTap,
          borderRadius: CardRadius.pill,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: KitMetrics.touch),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
                  Text(label, maxLines: 1, style: TypeTokens.style(13, FontWeight.w700, color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _continueCard(TripSummaryModel t) {
    final name = t.title.trim().isEmpty ? t.routeLine : t.title.trim();
    final sub = TripBarRules.nextTitle(t) ?? TripStringsTab.continueHeading;
    const tone = KitTone.trip;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: PressScale(
        child: DecoratedBox(
          decoration: const BoxDecoration(borderRadius: KitMetrics.photo, boxShadow: ShadowTokens.elev1),
          child: Material(
            color: DesignColors.surface,
            borderRadius: KitMetrics.photo,
            child: InkWell(
              onTap: () => _continue(t),
              borderRadius: KitMetrics.photo,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: tone.tint, shape: BoxShape.circle),
                      child: Icon(Icons.arrow_forward_rounded, color: tone.accentDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TypeTokens.style(15, FontWeight.w700),
                          ),
                          Text(
                            sub,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TypeTokens.style(13, FontWeight.w400, color: TypeTokens.secondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: tone.accentDark),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(double side) {
    final pad = EdgeInsets.symmetric(horizontal: side);
    if (_load == _Load.loading && _cities.isEmpty) {
      return [
        SliverPadding(
          padding: pad,
          sliver: SliverGrid(
            gridDelegate: _gridDelegate,
            delegate: SliverChildBuilderDelegate((_, _) => const _TileSkeleton(), childCount: 6),
          ),
        ),
      ];
    }
    if (_cities.isEmpty) {
      final StateCard card;
      switch (_load) {
        case _Load.plannerOff:
          card = const StateCard(
              title: TripStrings.plannerOff, message: TripStrings.plannerOffSubtitle, kit: KitTone.trip);
        case _Load.failed:
          card = StateCard.error(
            title: TripStringsTab.errorTitle,
            message: TripStringsTab.errorSub,
            kit: KitTone.trip,
            actionLabel: TripStringsTab.retry,
            onAction: _retry,
          );
        default:
          final searching = _typing || _state != null;
          card = StateCard(
            title: searching ? TripStringsTab.emptyTitle : TripStringsTab.noCitiesTitle,
            message: searching ? TripStringsTab.emptySub : TripStringsTab.noCitiesSub,
            kit: KitTone.trip,
            actionLabel: _state != null ? TripStringsTab.showAllStates : null,
            onAction: _state != null ? () => _pickState(null) : null,
          );
      }
      return [SliverToBoxAdapter(child: card), ..._soon(side)];
    }
    final cities = _cities;
    return [
      SliverPadding(
        padding: pad,
        sliver: SliverGrid(
          gridDelegate: _gridDelegate,
          delegate: SliverChildBuilderDelegate(
            (_, i) => TripCityTile(
              key: ValueKey(cities[i].cityKey),
              city: cities[i],
              onTap: () => TripNavigation.startWithCities([cities[i]]),
            ),
            childCount: cities.length,
            addRepaintBoundaries: false,
            findChildIndexCallback: (k) {
              final id = (k as ValueKey<int>).value;
              final i = cities.indexWhere((c) => c.cityKey == id);
              return i < 0 ? null : i;
            },
          ),
        ),
      ),
      ..._soon(side),
    ];
  }

  List<Widget> _soon(double side) {
    final soon = _catalog.comingSoon(_query, stateName: _state);
    if (soon.isEmpty) return const [];
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(side, 16, side, 0),
        sliver: SliverList.list(children: [for (final c in soon) _SoonRow(city: c)]),
      ),
    ];
  }
}

class _SoonRow extends StatelessWidget {
  const _SoonRow({required this.city});

  final TripCityModel city;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '${city.name}, ${TripStringsTab.comingSoon}',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  city.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeTokens.style(14, FontWeight.w600, color: TypeTokens.secondary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                TripStringsTab.comingSoon,
                style: TypeTokens.style(12, FontWeight.w600, color: TypeTokens.secondary),
              ),
            ],
          ),
        ),
      );
}

class _TileSkeleton extends StatelessWidget {
  const _TileSkeleton();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(borderRadius: KitMetrics.photo, color: DesignColors.surface),
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(widthFactor: 0.7, child: TemplatePlaceholder(height: 14)),
              SizedBox(height: 6),
              FractionallySizedBox(widthFactor: 0.4, child: TemplatePlaceholder(height: 10)),
            ],
          ),
        ),
      );
}
