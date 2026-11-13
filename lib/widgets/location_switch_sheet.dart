import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math' as math;
import '../config/app_tabs.dart';
import '../config/module_palette.dart';
import '../controllers/auth_controller.dart';
import '../controllers/location_controller.dart';
import '../design/design.dart';
import '../models/city_model.dart';
import '../services/top_route_observer.dart';
import '../utils/city_search_rank.dart';
import '../utils/input_formatters.dart';
import '../utils/search_fold.dart';

// Module colour for shared overlays: Stay forest, Taxi coral, others indigo.
ListingTone moduleToneFor([ModulePalette? palette]) {
  if (identical(palette, ModulePalette.stays) ||
      identical(palette, ModulePalette.jobs))
    return ListingTone.forest;
  if (identical(palette, ModulePalette.taxi)) return ListingTone.coral;
  final top = TopRouteObserver.top.value ?? '';
  if (top.startsWith('/trip')) return ListingTone.indigo;
  if (top.contains('taxi')) return ListingTone.coral;
  if (top.contains('stay') || top.contains('job')) return ListingTone.forest;
  if (Get.isRegistered<AuthController>()) {
    final tab = Get.find<AuthController>().tabIndex.value;
    if (tab == AppTabs.stays) return ListingTone.forest;
    if (tab == AppTabs.taxi) return ListingTone.coral;
  }
  return ListingTone.indigo;
}

class PickedPlace {
  final String name;
  final double latitude;
  final double longitude;
  final String cityId;
  final String districtId;
  final String districtName;

  const PickedPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.cityId,
    required this.districtId,
    required this.districtName,
  });
}

/// Shared bottom sheet for the district-switch feature — shared by Stay, Taxi
/// and Jobs. A 3-level drill-down: City (home) →
/// District (scoped to the current state) → State. Reads/writes browsing
/// state directly on [LocationController]; callers don't need any callbacks.
/// [pick] reuses the same UI but only returns the tapped city.
class LocationSwitchSheet extends StatefulWidget {
  final ModulePalette palette;
  final bool pickOnly;
  final String? title;
  const LocationSwitchSheet({
    super.key,
    this.palette = templateModulePalette,
    this.pickOnly = false,
    this.title,
  });

  static Future<PickedPlace?> pick(
    BuildContext context, {
    ModulePalette palette = templateModulePalette,
    String? title,
  }) {
    return Sheet3D.show<PickedPlace>(
      context,
      builder: (_) => LocationSwitchSheet(
        palette: palette,
        pickOnly: true,
        title: title ?? 'Pick a city',
      ),
    );
  }

  // The sheet keeps its own fixed height, so no keyboard padding is added here.
  static Future<void> show(
    BuildContext context, {
    ModulePalette palette = templateModulePalette,
  }) {
    return Sheet3D.show<void>(
      context,
      builder: (_) => LocationSwitchSheet(palette: palette),
    );
  }

  @override
  State<LocationSwitchSheet> createState() => _LocationSwitchSheetState();
}

enum _Level { city, district, state }

class _LocationSwitchSheetState extends State<LocationSwitchSheet>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    duration: const Duration(milliseconds: 600),
    vsync: this,
  )..forward();
  late final AnimationController _rows = AnimationController(
    duration: const Duration(milliseconds: 600),
    vsync: this,
  )..forward();
  final _locationCtrl = Get.find<LocationController>();
  final _searchCtrl = TextEditingController();
  late final ListingTone _tone = moduleToneFor(widget.palette);

  _Level _level = _Level.city;
  String _query = '';

  DistrictModel? _viewingDistrict;
  List<CityModel> _cities = [];
  bool _citiesLoading = false;
  String? _citiesError;

  String? _stateFilter;
  List<DistrictModel> _allDistricts = [];
  bool _districtsLoading = false;
  String? _districtsError;

  // True while THIS sheet is closing itself (a pick, or "Current"). Lets the
  // external-change worker below tell "we closed ourselves" apart from "the
  // browsing state changed out from under us" without double-popping.
  bool _closing = false;
  Worker? _externalResetWorker;

  // Captured once (didChangeDependencies, before the keyboard can open) and
  // reused for every build. AndroidManifest.xml sets
  // windowSoftInputMode="adjustResize", so Android shrinks the actual app
  // window when the keyboard opens — MediaQuery.size itself gets smaller,
  // it isn't just viewInsets.bottom growing. Reading MediaQuery.size live in
  // build() meant the sheet-height formula recomputed against that shrunk
  // size and visibly shrank the whole sheet the moment the search field was
  // focused. Freezing the baseline here keeps the sheet's height constant
  // regardless of the keyboard.
  double? _baseHeight;
  double? _baseTopPadding;

  @override
  void initState() {
    super.initState();
    _viewingDistrict = widget.pickOnly
        ? (_locationCtrl.selectedDistrict.value ??
              _locationCtrl.effectiveDistrict)
        : _locationCtrl.effectiveDistrict;
    _loadCitiesFor(_viewingDistrict);
    if (widget.pickOnly) return;

    // If browsing is reset/changed from outside this sheet — most notably
    // LocationController.refreshOnResume() discarding it when the app comes
    // back to the foreground while this sheet is still open — dismiss the
    // sheet instead of silently continuing to show a now-stale district/city
    // list. Without this, a pick made after that point would call
    // setBrowsing() and re-establish an override in the very resume cycle
    // that just tried to clear it.
    _externalResetWorker = ever(_locationCtrl.browsingDistrict, (_) {
      if (_closing || !mounted) return;
      _closing = true;
      Navigator.of(context).maybePop();
    });
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
    _enter.dispose();
    _rows.dispose();
    _externalResetWorker?.dispose();
    super.dispose();
  }

  Future<void> _loadCitiesFor(DistrictModel? district) async {
    if (district == null || _citiesLoading) return;
    setState(() {
      _citiesLoading = true;
      _citiesError = null;
    });
    try {
      final cities = await _locationCtrl.loadCitiesForDistrict(district.id);
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _citiesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _citiesLoading = false;
        _citiesError = 'Could not load cities. Please try again.';
      });
    }
  }

  Future<void> _loadDistricts() async {
    if (_districtsLoading) return;
    setState(() {
      _districtsLoading = true;
      _districtsError = null;
    });
    try {
      final districts = await _locationCtrl.loadAllDistricts();
      if (!mounted) return;
      setState(() {
        _allDistricts = districts;
        _districtsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _districtsLoading = false;
        _districtsError = 'Could not load districts. Please try again.';
      });
    }
  }

  void _clearSearch() {
    _query = '';
    _searchCtrl.clear();
  }

  void _goToDistrictLevel() {
    setState(() {
      _stateFilter = _viewingDistrict?.stateName;
      _level = _Level.district;
      _clearSearch();
    });
    if (_allDistricts.isEmpty) _loadDistricts();
  }

  void _goToStateLevel() {
    setState(() {
      _level = _Level.state;
      _clearSearch();
    });
    if (_allDistricts.isEmpty) _loadDistricts();
  }

  void _backToCityLevel() {
    setState(() {
      _level = _Level.city;
      _clearSearch();
    });
  }

  void _backToDistrictLevel() {
    setState(() {
      _level = _Level.district;
      _clearSearch();
    });
  }

  void _pickState(String state) {
    setState(() {
      _stateFilter = state;
      _level = _Level.district;
      _clearSearch();
    });
  }

  void _pickDistrict(DistrictModel district) {
    setState(() {
      _viewingDistrict = district;
      _level = _Level.city;
      _clearSearch();
    });
    _loadCitiesFor(district);
  }

  void _pickCity(CityModel city) {
    final district = _viewingDistrict;
    if (district == null) return;
    _closing = true;
    if (widget.pickOnly) {
      Navigator.pop(
        context,
        PickedPlace(
          name: city.name,
          latitude: city.latitude!,
          longitude: city.longitude!,
          cityId: city.id,
          districtId: district.id,
          districtName: district.name,
        ),
      );
      return;
    }
    _locationCtrl.setBrowsing(district, city);
    Navigator.pop(context);
  }

  void _pickCurrent() {
    _closing = true;
    _locationCtrl.resetBrowsing();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Fixed height from the frozen baseline: loading/empty states and the
    // keyboard (adjustResize) never resize the sheet, and no keyboard padding
    // is added (the modal route already places it against the live window).
    final media = MediaQuery.of(context);
    final baseHeight = _baseHeight ?? media.size.height;
    final baseTopPadding = _baseTopPadding ?? media.padding.top;
    final maxHeight = (baseHeight - baseTopPadding) * 0.94;
    final fiveRows = 615.0 + (widget.title != null ? 19 : 0);
    final sheetHeight = math.max(baseHeight * 0.75, fiveRows).clamp(0.0, maxHeight);
    final (title, subtitle, onBack, action, onAction) = _header();
    return SizedBox(
      height: sheetHeight + Sheet3D.artRoom,
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: Sheet3D(
          tone: _tone,
          art: _art,
          centerTitle: false,
          scrollable: false,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetListHeader(
                tone: _tone,
                title: title,
                subtitle: subtitle,
                onBack: onBack,
                action: action,
                onAction: onAction,
              ),
              TemplateEntrance(
                animation: templateInterval(_enter, 0, 2),
                animationController: _enter,
                child: _buildSearchBox(),
              ),
              Expanded(
                child: TemplateEntrance(
                  animation: templateInterval(_enter, 1, 2),
                  animationController: _enter,
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _art => switch (_level) {
    _Level.city =>
      widget.pickOnly && identical(_tone, ListingTone.coral)
          ? ListingArt.taxi
          : ListingArt.roundPushpin,
    _Level.district => ListingArt.compass,
    _Level.state => ListingArt.worldMap,
  };

  (String, String?, VoidCallback?, String?, VoidCallback?) _header() =>
      switch (_level) {
        _Level.city => (
          widget.title ?? _viewingDistrict?.name ?? 'Choose city',
          widget.title != null ? _viewingDistrict?.name : null,
          null,
          'Change district ›',
          _goToDistrictLevel,
        ),
        _Level.district => (
          _stateFilter ?? 'Districts',
          null,
          _backToCityLevel,
          'Change state ›',
          _goToStateLevel,
        ),
        _Level.state => ('All states', null, _backToDistrictLevel, null, null),
      };

  Widget _buildSearchBox() {
    final hint = switch (_level) {
      _Level.city => 'Search city',
      _Level.district => 'Search district',
      _Level.state => 'Search state',
    };
    return SheetSearchField(
      tone: _tone,
      controller: _searchCtrl,
      hint: hint,
      leadingArt: ListingArt.roundPushpin,
      inputFormatters: noEmojiInputFormatters,
      onChanged: (v) => setState(() => _query = v),
    );
  }

  Widget _buildBody() {
    final Widget child;
    switch (_level) {
      case _Level.city:
        child = _buildCityList();
        break;
      case _Level.district:
        child = _buildDistrictList();
        break;
      case _Level.state:
        child = _buildStateList();
        break;
    }
    return GateSwitcher(
      horizontal: true,
      reverse: _level == _Level.city,
      child: KeyedSubtree(key: ValueKey(_level), child: child),
    );
  }

  Widget _list(List<_Row> rows) {
    _rows.forward(from: 0);
    final count = math.min(rows.length, 10);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final r = rows[i];
        return TemplateEntrance(
          animation: templateInterval(_rows, math.min(i, count - 1), count),
          animationController: _rows,
          child: SheetListRow(
            tone: _tone,
            title: r.label,
            art: r.asset,
            selected: r.selected,
            enabled: r.onTap != null,
            onTap: r.onTap,
            divider: i > 0,
          ),
        );
      },
    );
  }

  Widget _buildCityList() {
    if (_citiesLoading) return _loadingIndicator();
    if (_citiesError != null) {
      return _errorState(_citiesError!, () => _loadCitiesFor(_viewingDistrict));
    }

    final pickOnly = widget.pickOnly;
    final isOwnDistrict =
        !pickOnly &&
        _viewingDistrict != null &&
        _locationCtrl.selectedDistrict.value != null &&
        _viewingDistrict!.id == _locationCtrl.selectedDistrict.value!.id;
    final activeCityId = pickOnly ? null : _locationCtrl.browsingCity.value?.id;

    final q = SearchFold.fold(_query);
    final filtered = CitySearchRank.rank<CityModel>(
      _cities,
      q,
      name: (c) => c.name,
    );

    final items = <_Row>[];
    if (isOwnDistrict && (q.isEmpty || 'current'.contains(q))) {
      items.add(
        _Row(ListingArt.pushpin, 'Current', activeCityId == null, _pickCurrent),
      );
    }
    items.addAll(
      filtered.map(
        (c) => _Row(
          ListingArt.roundPushpin,
          c.name,
          c.id == activeCityId,
          pickOnly && (c.latitude == null || c.longitude == null)
              ? null
              : () => _pickCity(c),
        ),
      ),
    );

    if (items.isEmpty) return _emptyState('No city matches "$_query"');
    return _list(items);
  }

  Widget _buildDistrictList() {
    if (_districtsLoading) return _loadingIndicator();
    if (_districtsError != null) {
      return _errorState(_districtsError!, _loadDistricts);
    }

    final q = SearchFold.fold(_query);
    final filtered = _allDistricts
        .where(
          (d) =>
              // Defensive: if we somehow have no state to filter by (e.g. a
              // district missing stateName), show all districts rather than
              // silently rendering an unexplained empty list.
              (_stateFilter == null || d.stateName == _stateFilter) &&
              (q.isEmpty || SearchFold.contains(d.name, q)),
        )
        .toList();

    if (filtered.isEmpty) return _emptyState('No district matches "$_query"');
    return _list(
      filtered.map((d) {
        if (!d.isActive)
          return _Row(
            ListingArt.compass,
            '${d.name} · coming soon',
            false,
            null,
          );
        return _Row(
          ListingArt.compass,
          d.name,
          d.id == _viewingDistrict?.id,
          () => _pickDistrict(d),
        );
      }).toList(),
    );
  }

  Widget _buildStateList() {
    if (_districtsLoading) return _loadingIndicator();
    if (_districtsError != null) {
      return _errorState(_districtsError!, _loadDistricts);
    }

    final q = SearchFold.fold(_query);
    final states = _locationCtrl.browsableStates
        .where((s) => q.isEmpty || SearchFold.contains(s, q))
        .toList();

    if (states.isEmpty) return _emptyState('No state matches "$_query"');
    return _list(
      states
          .map(
            (s) => _Row(
              ListingArt.worldMap,
              s,
              s == _stateFilter,
              () => _pickState(s),
            ),
          )
          .toList(),
    );
  }

  Widget _loadingIndicator() => sheetSkeleton(twoLines: false);

  Widget _emptyState(String message) => sheetStateView(_tone, message);

  Widget _errorState(String message, VoidCallback onRetry) =>
      sheetStateView(_tone, message, onRetry: onRetry);
}

class _Row {
  const _Row(this.asset, this.label, this.selected, this.onTap);

  final String asset;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
}

// Five skeleton rows with the list dividers (location sheets).
Widget sheetSkeleton({required bool twoLines}) => ListView(
  physics: const NeverScrollableScrollPhysics(),
  padding: const EdgeInsets.only(top: 4),
  children: [
    for (var i = 0; i < 5; i++)
      DecoratedBox(
        decoration: BoxDecoration(
          border: i == 0
              ? null
              : const Border(top: BorderSide(color: Ink3D.line)),
        ),
        child: SkeletonListRow(twoLines: twoLines),
      ),
  ],
);

// Empty / error message inside a list sheet, centred in the list area.
Widget sheetStateView(
  ListingTone tone,
  String message, {
  VoidCallback? onRetry,
}) => Center(
  child: SingleChildScrollView(
    child: StateCard3D(
      tone: tone,
      art: ListingArt.worldMap,
      title: message,
      layout: StateLayout.plain,
      actionLabel: onRetry == null ? null : 'Retry',
      onAction: onRetry,
    ),
  ),
);

// List sheet header: back slot, one-line title that shrinks to fit, gradient link pill.
class SheetListHeader extends StatelessWidget {
  const SheetListHeader({
    super.key,
    required this.tone,
    required this.title,
    this.subtitle,
    this.onBack,
    this.action,
    this.onAction,
  });

  final ListingTone tone;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final a = action;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null) ...[
            Tooltip(
              message: 'Back',
              child: Tap3D(
                onTap: onBack,
                label: 'Back',
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: DesignColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: Ink3D.softShadow,
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 26,
                    color: tone.text,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: Ink3D.text(
                            21,
                            FontWeight.w700,
                            Ink3D.title,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(13, FontWeight.w400, Ink3D.sub),
                  ),
              ],
            ),
          ),
          if (a != null) ...[
            const SizedBox(width: 10),
            SizedBox(
              height: 40,
              child: Center(
                child: Tap3D(
                  onTap: onAction,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 34),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: tone.gradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: tone.glow(blur: 8, dy: 3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          a,
                          maxLines: 1,
                          style: Ink3D.text(
                            12.5,
                            FontWeight.w700,
                            DesignColors.textInverse,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
