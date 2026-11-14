import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../utils/input_formatters.dart';
import '../data/trip_city_catalog.dart';
import '../data/trip_repository.dart' show TripErrorTypes;
import '../models/trip_city_model.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_hub_where.dart';
import '../trip_strings_tab.dart';
import '../widgets/hub/hub_header.dart';
import '../widgets/hub/hub_page_background.dart';
import '../widgets/hub/hub_section_title.dart';
import '../widgets/hub/hub_state_chip.dart';
import '../widgets/trip_city_tile.dart';

enum _Load { loading, ready, failed, plannerOff }

class TripWhereScreen extends StatefulWidget {
  const TripWhereScreen({super.key});

  @override
  State<TripWhereScreen> createState() => _TripWhereScreenState();
}

class _TripWhereScreenState extends State<TripWhereScreen> {
  static const double _maxWidth = 640;
  static const double _tileWidth = 160;
  static const List<Color> _allColors = [Color(0xFF54D3C2), Color(0xFF1FA396)];
  static const List<List<Color>> _stateColors = [
    [Color(0xFF6F72CA), Color(0xFF1E1466)],
    [Color(0xFFFFC371), Color(0xFFFF8A3D)],
    [Color(0xFFFA7D82), Color(0xFFE0525C)],
    [Color(0xFF66BB6A), Color(0xFF2E7D32)],
  ];
  static final ListingTone _page = ListingTone.indigo;
  static const List<String> _stateArts = [ListingArt.mountain, ListingArt.camping, ListingArt.tent, ListingArt.beach];

  static int _stateSlot(String name) {
    final k = name.toLowerCase();
    if (k.contains('uttarakhand')) return 0;
    if (k.contains('himachal')) return 1;
    return 2 + k.codeUnits.fold<int>(0, (a, c) => a + c) % 2;
  }

  final _search = TextEditingController();
  final _focus = FocusNode();
  late final TripCityCatalog _catalog;
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
    _catalog.warmFromDisk();
    _apply();
    _refresh();
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _apply() {
    _states = _catalog.liveStates();
    final counts = <String, int>{};
    for (final c in _catalog.ready('')) {
      counts[c.stateName] = (counts[c.stateName] ?? 0) + 1;
    }
    _states.sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
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

  Widget _center(Widget child) => Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _maxWidth), child: child),
      );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final top = media.padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFEEF1FD),
      resizeToAvoidBottomInset: false,
      body: KitStatusBar(
        lightIcons: false,
        child: RefreshIndicator(
          color: _page.g2,
          edgeOffset: top,
          onRefresh: () => _refresh(force: true),
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              physics: const AlwaysScrollableScrollPhysics(),
              child: HubPageBackground(
                minHeight: box.maxHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _center(_top()),
                    const SizedBox(height: 6),
                    ..._body(media.size.width),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _top() {
    final plain = !_typing && _state == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: const HubHeader(title: TripStringsHubWhere.title, lead: TripStringsHubWhere.lead, back: true, minHeight: 94, titleTop: 2),
        ),
        _searchBox(),
        _filterRow(),
        HubSectionTitle(
          title: plain ? TripStringsHubWhere.popular : TripStringsHubWhere.cities,
          sub: plain ? TripStringsHubWhere.popularSub : null,
          top: 24,
        ),
      ],
    );
  }

  Widget _searchBox() => SearchPill(
        tone: _page,
        inline: true,
        flat: true,
        margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
        padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
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

  Widget _filterRow() {
    if (_states.length < 2) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Row(
        children: [
          HubStateChip(
            art: ListingArt.worldMap,
            label: TripStringsTab.all,
            colors: _allColors,
            onTap: () => _pickState(null),
          ),
          for (var i = 0; i < _states.length; i++) ...[
            const SizedBox(width: 8),
            HubStateChip(
              art: _stateArts[_stateSlot(_states[i])],
              label: _states[i],
              colors: _stateColors[_stateSlot(_states[i])],
              onTap: () => _pickState(_states[i]),
            ),
          ],
        ],
      ),
    );
  }

  double _cell(double screenW) {
    final col = ((screenW > _maxWidth ? _maxWidth : screenW) - 24) / 2;
    return col < _tileWidth ? col : _tileWidth;
  }

  Widget _slot(Widget? child) => Expanded(child: Center(child: child));

  Widget _pair(double cell, Widget a, Widget? b) => _center(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_slot(a), const SizedBox(width: 4), _slot(b)],
            ),
          ),
        ),
      );

  Widget _stateBox(Widget card) => _center(Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 0), child: card));

  List<Widget> _body(double screenW) {
    final cell = _cell(screenW);
    if (_load == _Load.loading && _cities.isEmpty) {
      return [
        for (var i = 0; i < 3; i++) _pair(cell, MealsCardSkeleton(width: cell), MealsCardSkeleton(width: cell)),
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
      return [_stateBox(card)];
    }
    final cities = _cities;
    Widget tile(int i) => TripCityTile(
          key: ValueKey(cities[i].cityKey),
          city: cities[i],
          index: i,
          width: cell,
          hub: true,
          onTap: () => TripNavigation.startWithCities([cities[i]]),
        );
    return [
      for (var r = 0; r < (cities.length + 1) ~/ 2; r++)
        KeyedSubtree(
          key: ValueKey(cities[r * 2].cityKey),
          child: _pair(cell, tile(r * 2), r * 2 + 1 < cities.length ? tile(r * 2 + 1) : null),
        ),
    ];
  }
}
