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
import '../trip_strings_v2_plan.dart';
import '../utils/trip_bar_rules.dart';
import '../utils/trip_clock.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_city_tile.dart';

enum _Load { loading, ready, failed, plannerOff }

class TripsDiscoveryScreen extends StatefulWidget {
  const TripsDiscoveryScreen({super.key});

  @override
  State<TripsDiscoveryScreen> createState() => _TripsDiscoveryScreenState();
}

class _TripsDiscoveryScreenState extends State<TripsDiscoveryScreen> {
  static const double _maxWidth = 640;
  static const String _lead = 'Choose your';
  static final ListingTone _page = ListingTone.indigo;
  static const List<String> _stateArts = [ListingArt.mountain, ListingArt.camping, ListingArt.tent, ListingArt.beach];
  static final List<ListingTone> _stateTones = [ListingTone.cA, ListingTone.cC, ListingTone.cF, ListingTone.cD];

  final _search = TextEditingController();
  final _focus = FocusNode();
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
    _focus.dispose();
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

  Widget _center(Widget child) => Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _maxWidth), child: child),
      );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final top = media.padding.top;
    final page = Scaffold(
      backgroundColor: ListingPalette.indigo.page,
      resizeToAvoidBottomInset: false,
      body: KitStatusBar(
        lightIcons: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: _page.g2,
              edgeOffset: top,
              onRefresh: () async {
                _trips.load();
                await _refresh(force: true);
              },
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: top)),
                  SliverToBoxAdapter(child: _center(_top())),
                  ..._body(media.size.width),
                  SliverToBoxAdapter(child: SizedBox(height: BarMetrics.bodyBottomOf(context))),
                ],
              ),
            ),
            Positioned(left: 0, right: 0, top: 0, height: top, child: ColoredBox(color: ListingPalette.indigo.page)),
          ],
        ),
      ),
    );
    return TabEntrance(tab: AppTabs.trips, child: page);
  }

  Widget _top() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: ModuleTitleBar(
              tone: _page,
              art: ListingArt.luggage,
              title: TripStringsTab.title,
              subtitle: _lead,
              subtitleFirst: true,
            ),
          ),
          _searchBox(),
          _filterRow(),
          if (!_typing) ...[
            Obx(() {
              final t = _trips.continueTrip;
              return t == null ? const SizedBox.shrink() : _continueCard(t);
            }),
            TitleRow3D(title: TripStringsTab.sectionTitle, subtitle: TripStringsTab.sectionSub, tone: _page),
          ] else
            const SizedBox(height: 8),
        ],
      );

  Widget _searchBox() => SearchPill(
        tone: _page,
        inline: true,
        value: TripStringsTab.searchHint,
        buttonArt: ListingArt.search,
        field: TextField(
          controller: _search,
          focusNode: _focus,
          onChanged: _onSearch,
          inputFormatters: noEmojiInputFormatters,
          textInputAction: TextInputAction.search,
          cursorColor: _page.g2,
          maxLines: 1,
          style: Ink3D.text(16, FontWeight.w400, Ink3D.body, letterSpacing: 0),
          decoration: InputDecoration(
            isCollapsed: true,
            isDense: true,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            hintText: TripStringsTab.searchHint,
            hintStyle: Ink3D.text(16, FontWeight.w400, Ink3D.hint, letterSpacing: 0),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
          ),
        ),
        buttonSemantics: _query.isEmpty ? TripStringsTab.searchHint : TripStringsTab.clearSearch,
        onButtonTap: _query.isEmpty ? _focus.requestFocus : _clearSearch,
        buttonChild: _query.isEmpty
            ? null
            : const Tooltip(
                message: TripStringsTab.clearSearch,
                child: Icon(Icons.close_rounded, color: DesignColors.onPrimary, size: 26),
              ),
      );

  Widget _filterRow() => ChipCPRow(
        children: [
          Obx(() => ChipCP(
                tone: ListingTone.cB,
                art: ListingArt.luggage,
                label: TripStringsTab.myTripsCount(_trips.openTripCount),
                onTap: TripNavigation.openMyTrips,
              )),
          if (_states.length >= 2) ...[
            ChipCP(
              tone: ListingTone.teal,
              art: ListingArt.worldMap,
              label: TripStringsTab.all,
              off: _state != null,
              onTap: () => _pickState(null),
            ),
            for (var i = 0; i < _states.length; i++)
              ChipCP(
                tone: _stateTones[i % _stateTones.length],
                art: _stateArts[i % _stateArts.length],
                label: _states[i],
                off: _state != _states[i],
                onTap: () => _pickState(_states[i]),
              ),
          ],
        ],
      );

  Widget _continueCard(TripSummaryModel t) {
    final name = t.title.trim().isEmpty ? TripCard.routeTitle(t) : t.title.trim();
    final dates = TripCard.lineBreakDates(TripBarRules.datesLine(t, TripClock.today()));
    final next = TripBarRules.nextTitle(t);
    final p = t.progress;
    final needs = TripBarRules.needCount(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TitleRow3D(title: TripStringsTab.continueHeading, tone: _page),
        WideCard(
          tone: ListingTone.cB,
          art: ListingArt.luggage,
          title: name,
          subtitle: next == null ? dates : '$dates\n$next',
          chips: [
            if (p.total > 0) TripStringsTab.doneShort(p.done, p.total),
            if (needs > 0) TripStringsV2Plan.needsYou(needs) else if (p.inProgress > 0) TripStringsTab.waitingShort(p.inProgress),
          ],
          showPrice: false,
          progress: p.percent / 100,
          onTap: () => _continue(t),
        ),
      ],
    );
  }

  double _cell(double screenW) => ((screenW > _maxWidth ? _maxWidth : screenW) - 16) / 2;

  Widget _pair(double cell, Widget a, Widget? b) => _center(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [a, b ?? SizedBox(width: cell)],
            ),
          ),
        ),
      );

  Widget _stateBox(Widget card) => _center(Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 0), child: card));

  List<Widget> _body(double screenW) {
    final cell = _cell(screenW);
    if (_load == _Load.loading && _cities.isEmpty) {
      return [
        SliverList.builder(
          itemCount: 3,
          itemBuilder: (_, _) => _pair(cell, MealsCardSkeleton(width: cell), MealsCardSkeleton(width: cell)),
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
      return [SliverToBoxAdapter(child: _stateBox(card))];
    }
    final cities = _cities;
    Widget tile(int i) => TripCityTile(
          key: ValueKey(cities[i].cityKey),
          city: cities[i],
          index: i,
          width: cell,
          onTap: () => TripNavigation.startWithCities([cities[i]]),
        );
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, r) => KeyedSubtree(
            key: ValueKey(cities[r * 2].cityKey),
            child: _pair(cell, tile(r * 2), r * 2 + 1 < cities.length ? tile(r * 2 + 1) : null),
          ),
          childCount: (cities.length + 1) ~/ 2,
          addRepaintBoundaries: false,
          findChildIndexCallback: (k) {
            final id = (k as ValueKey<int>).value;
            final i = cities.indexWhere((c) => c.cityKey == id);
            return i < 0 || i.isOdd ? null : i ~/ 2;
          },
        ),
      ),
    ];
  }
}
