import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math' as math;
import '../config/module_palette.dart';
import '../controllers/location_controller.dart';
import '../design/design.dart';
import '../models/city_model.dart';
import '../utils/city_search_rank.dart';
import '../utils/input_formatters.dart';
import '../utils/search_fold.dart';

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

  static Future<PickedPlace?> pick(BuildContext context,
      {ModulePalette palette = templateModulePalette, String? title}) {
    return showModalBottomSheet<PickedPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FitnessAppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LocationSwitchSheet(
          palette: palette, pickOnly: true, title: title ?? 'Pick a city'),
    );
  }

  static Future<void> show(BuildContext context, {ModulePalette palette = templateModulePalette}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FitnessAppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // No manual keyboard padding here — this sheet has its own fixed
      // height (see build() below), so padding the whole subtree up by the
      // keyboard height on top of that fixed height fights it and pushes
      // list content down away from the search box. The sheet computes its
      // own height around the keyboard instead (see _sheetHeight()).
      builder: (_) => LocationSwitchSheet(palette: palette),
    );
  }

  @override
  State<LocationSwitchSheet> createState() => _LocationSwitchSheetState();
}

enum _Level { city, district, state }

class _LocationSwitchSheetState extends State<LocationSwitchSheet> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..forward();
  late final AnimationController _rows = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..forward();
  final _locationCtrl = Get.find<LocationController>();
  final _searchCtrl = TextEditingController();

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
        ? (_locationCtrl.selectedDistrict.value ?? _locationCtrl.effectiveDistrict)
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
    // Fixed height regardless of content — loading/empty/error states must
    // not shrink the sheet, that reads as broken and jumps around as data
    // arrives. Built from the frozen _baseHeight/_baseTopPadding (captured
    // in didChangeDependencies, before the keyboard could open) rather than
    // live MediaQuery, so it never changes when the keyboard opens —
    // android:windowSoftInputMode="adjustResize" shrinks MediaQuery.size
    // itself while the keyboard is up, which previously fed straight into
    // this formula and shrank the whole sheet.
    //
    // No manual keyboard padding/shifting here. An earlier version wrapped
    // this in AnimatedPadding(bottom: media.viewInsets.bottom) to "shift the
    // sheet above the keyboard" — but viewInsets.bottom is in fact nonzero
    // on-device (not the ~0 this was assumed to be under adjustResize), so
    // that padding painted a growing blank white gap between the list and
    // the keyboard every time it opened. The modal route already positions
    // this fixed-height sheet correctly against the live (keyboard-aware)
    // window on its own — no extra padding is needed.
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
          TemplateEntrance(
            animation: templateInterval(_enter, 0, 3),
            animationController: _enter,
            child: _buildHeader(),
          ),
          TemplateEntrance(
            animation: templateInterval(_enter, 1, 3),
            animationController: _enter,
            child: _buildSearchBox(),
          ),
          Expanded(
            child: TemplateEntrance(
              animation: templateInterval(_enter, 2, 3),
              animationController: _enter,
              child: _buildBody(),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _linkButton(String label, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        child: Text(label,
            style: FitnessAppTheme.caption.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: FitnessAppTheme.white.withValues(alpha: Alpha.high))),
      );

  Widget _buildHeader() {
    String title;
    String? subtitle;
    Widget? leading;
    Widget? trailing;

    switch (_level) {
      case _Level.city:
        title = widget.title ?? _viewingDistrict?.name ?? 'Choose city';
        if (widget.title != null) subtitle = _viewingDistrict?.name;
        trailing = _linkButton('Change district ›', _goToDistrictLevel);
        break;
      case _Level.district:
        title = _stateFilter ?? 'Districts';
        leading = _backArrow(_backToCityLevel);
        trailing = _linkButton('Change state ›', _goToStateLevel);
        break;
      case _Level.state:
        title = 'All states';
        leading = _backArrow(_backToDistrictLevel);
        break;
    }

    return GateSheetHeader(title: title, subtitle: subtitle, leading: leading, trailing: trailing);
  }

  Widget _backArrow(VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: const Icon(Icons.arrow_back_ios_new_rounded, color: FitnessAppTheme.white, size: 16),
      );

  Widget _buildSearchBox() {
    final hint = switch (_level) {
      _Level.city => 'Search city',
      _Level.district => 'Search district',
      _Level.state => 'Search state',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: GateSearchBar(
        controller: _searchCtrl,
        hint: hint,
        inputFormatters: noEmojiInputFormatters,
        onChanged: (v) => setState(() => _query = v),
      ),
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

  Widget _list(List<Widget> items) {
    _rows.forward(from: 0);
    final count = math.min(items.length, 10);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: items.length,
      itemBuilder: (context, i) => TemplateEntrance(
        animation: templateInterval(_rows, math.min(i, count - 1), count),
        animationController: _rows,
        child: items[i],
      ),
    );
  }

  Widget _buildCityList() {
    if (_citiesLoading) return _loadingIndicator();
    if (_citiesError != null) {
      return _errorState(_citiesError!, () => _loadCitiesFor(_viewingDistrict));
    }

    final pickOnly = widget.pickOnly;
    final isOwnDistrict = !pickOnly &&
        _viewingDistrict != null &&
        _locationCtrl.selectedDistrict.value != null &&
        _viewingDistrict!.id == _locationCtrl.selectedDistrict.value!.id;
    final activeCityId = pickOnly ? null : _locationCtrl.browsingCity.value?.id;

    final q = SearchFold.fold(_query);
    final filtered = CitySearchRank.rank<CityModel>(_cities, q, name: (c) => c.name);

    final items = <Widget>[];
    if (isOwnDistrict && (q.isEmpty || 'current'.contains(q))) {
      items.add(_locationRow(
        asset: TravelIcon.pin,
        label: 'Current',
        selected: activeCityId == null,
        onTap: _pickCurrent,
      ));
    }
    items.addAll(filtered.map((c) => _locationRow(
          asset: TravelIcon.place,
          label: c.name,
          selected: c.id == activeCityId,
          onTap: pickOnly && (c.latitude == null || c.longitude == null)
              ? null
              : () => _pickCity(c),
        )));

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
        .where((d) =>
            // Defensive: if we somehow have no state to filter by (e.g. a
            // district missing stateName), show all districts rather than
            // silently rendering an unexplained empty list.
            (_stateFilter == null || d.stateName == _stateFilter) &&
            (q.isEmpty || SearchFold.contains(d.name, q)))
        .toList();

    if (filtered.isEmpty) return _emptyState('No district matches "$_query"');
    return _list(filtered.map((d) {
        if (!d.isActive) {
          return _locationRow(
            asset: TravelIcon.route,
            label: '${d.name} · coming soon',
            selected: false,
            onTap: null,
          );
        }
        return _locationRow(
          asset: TravelIcon.route,
          label: d.name,
          selected: d.id == _viewingDistrict?.id,
          onTap: () => _pickDistrict(d),
        );
      }).toList());
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
    return _list(states
        .map((s) => _locationRow(
              asset: TravelIcon.map,
              label: s,
              selected: s == _stateFilter,
              onTap: () => _pickState(s),
            ))
        .toList());
  }

  Widget _locationRow({
    required String asset,
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    final color = disabled
        ? FitnessAppTheme.deactivatedText
        : (selected ? FitnessAppTheme.nearlyDarkBlue : FitnessAppTheme.darkerText);
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
              child: Row(
                children: [
                  Opacity(opacity: disabled ? Alpha.v40 : Alpha.full, child: TravelIcon(asset, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TripKit.text(14, weight: selected ? FontWeight.w700 : FontWeight.w500, color: color),
                    ),
                  ),
                  if (selected) const Icon(Icons.check_rounded, size: 18, color: FitnessAppTheme.nearlyDarkBlue),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: FitnessAppTheme.spacer),
      ],
    );
  }

  Widget _loadingIndicator() => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          for (var i = 0; i < 5; i++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  TemplatePlaceholder(height: 40, width: 40, radius: 20),
                  SizedBox(width: 12),
                  TemplatePlaceholder(height: 14, width: 160),
                ],
              ),
            ),
        ],
      );

  Widget _emptyState(String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            const TravelIcon(TravelIcon.map, size: 44),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: FitnessAppTheme.caption),
          ],
        ),
      );

  Widget _errorState(String message, VoidCallback onRetry) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          children: [
            const TravelIcon(TravelIcon.map, size: 44),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: FitnessAppTheme.caption),
            const SizedBox(height: 10),
            GateTextButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      );
}
