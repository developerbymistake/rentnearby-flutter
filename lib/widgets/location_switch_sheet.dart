import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../controllers/location_controller.dart';
import '../models/city_model.dart';

/// Shared bottom sheet for the district-switch feature — used identically by
/// Explore Rooms and Explore Plots. A 3-level drill-down: City (home) →
/// District (scoped to the current state) → State. Reads/writes browsing
/// state directly on [LocationController]; callers don't need any callbacks.
class LocationSwitchSheet extends StatefulWidget {
  const LocationSwitchSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // No manual keyboard padding here — this sheet has its own fixed
      // height (see build() below), so padding the whole subtree up by the
      // keyboard height on top of that fixed height fights it and pushes
      // list content down away from the search box. The sheet computes its
      // own height around the keyboard instead (see _sheetHeight()).
      builder: (_) => const LocationSwitchSheet(),
    );
  }

  @override
  State<LocationSwitchSheet> createState() => _LocationSwitchSheetState();
}

enum _Level { city, district, state }

class _LocationSwitchSheetState extends State<LocationSwitchSheet> {
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
    _viewingDistrict = _locationCtrl.effectiveDistrict;
    _loadCitiesFor(_viewingDistrict);

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
    if (_viewingDistrict == null) return;
    _closing = true;
    _locationCtrl.setBrowsing(_viewingDistrict!, city);
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
    // this formula and shrank the whole sheet. The sheet is additionally
    // shifted upward by the keyboard height via the outer AnimatedPadding
    // below (a no-op under adjustResize, but correct insurance either way).
    final media = MediaQuery.of(context);
    final baseHeight = _baseHeight ?? media.size.height;
    final baseTopPadding = _baseTopPadding ?? media.padding.top;
    final budget = baseHeight - baseTopPadding;
    final preferredHeight = (baseHeight * 0.75).clamp(0.0, budget * 0.94);
    // Safety net: AnimatedPadding below adds live viewInsets.bottom on top
    // of this height. That's a no-op under pure adjustResize (viewInsets
    // stays ~0), but isn't guaranteed on every device/keyboard — if it's
    // ever nonzero, keep sheetHeight + viewInsets.bottom within the frozen
    // budget so the sheet can never render partly above the visible screen.
    // Bounded against the frozen budget (not live media.size.height), so
    // this never reintroduces the original shrink-on-keyboard-open bug.
    final sheetHeight =
        preferredHeight.clamp(0.0, (budget - media.viewInsets.bottom).clamp(0.0, budget));
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            _buildSearchBox(),
            Expanded(child: _buildBody()),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title;
    VoidCallback? onBack;
    Widget? trailing;

    switch (_level) {
      case _Level.city:
        title = _viewingDistrict?.name ?? 'Choose city';
        onBack = null;
        trailing = TextButton(
          onPressed: _goToDistrictLevel,
          child: const Text('Change district ›',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              )),
        );
        break;
      case _Level.district:
        title = _stateFilter ?? 'Districts';
        onBack = _backToCityLevel;
        trailing = TextButton(
          onPressed: _goToStateLevel,
          child: const Text('Change state ›',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              )),
        );
        break;
      case _Level.state:
        title = 'All states';
        onBack = _backToDistrictLevel;
        trailing = null;
        break;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
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
              if (onBack != null)
                GestureDetector(
                  onTap: onBack,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    final hint = switch (_level) {
      _Level.city => 'Search city',
      _Level.district => 'Search district',
      _Level.state => 'Search state',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 20, color: AppColors.textHint),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
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
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(_level), child: child),
    );
  }

  Widget _buildCityList() {
    if (_citiesLoading) return _loadingIndicator();
    if (_citiesError != null) {
      return _errorState(_citiesError!, () => _loadCitiesFor(_viewingDistrict));
    }

    final isOwnDistrict = _viewingDistrict != null &&
        _locationCtrl.selectedDistrict.value != null &&
        _viewingDistrict!.id == _locationCtrl.selectedDistrict.value!.id;
    final activeCityId = _locationCtrl.browsingCity.value?.id;

    final filtered = _cities
        .where((c) => _query.isEmpty ||
            c.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    final items = <Widget>[];
    if (isOwnDistrict && (_query.isEmpty || 'current'.contains(_query.toLowerCase()))) {
      items.add(_locationRow(
        icon: Icons.my_location_rounded,
        label: 'Current',
        selected: activeCityId == null,
        onTap: _pickCurrent,
      ));
    }
    items.addAll(filtered.map((c) => _locationRow(
          icon: Iconsax.location,
          label: c.name,
          selected: c.id == activeCityId,
          onTap: () => _pickCity(c),
        )));

    if (items.isEmpty) return _emptyState('No city matches "$_query"');
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: items,
    );
  }

  Widget _buildDistrictList() {
    if (_districtsLoading) return _loadingIndicator();
    if (_districtsError != null) {
      return _errorState(_districtsError!, _loadDistricts);
    }

    final filtered = _allDistricts
        .where((d) =>
            // Defensive: if we somehow have no state to filter by (e.g. a
            // district missing stateName), show all districts rather than
            // silently rendering an unexplained empty list.
            (_stateFilter == null || d.stateName == _stateFilter) &&
            (_query.isEmpty ||
                d.name.toLowerCase().contains(_query.toLowerCase())))
        .toList();

    if (filtered.isEmpty) return _emptyState('No district matches "$_query"');
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: filtered.map((d) {
        if (!d.isActive) {
          return _locationRow(
            icon: Iconsax.location,
            label: '${d.name} · coming soon',
            selected: false,
            onTap: null,
          );
        }
        return _locationRow(
          icon: Iconsax.location,
          label: d.name,
          selected: d.id == _viewingDistrict?.id,
          onTap: () => _pickDistrict(d),
        );
      }).toList(),
    );
  }

  Widget _buildStateList() {
    if (_districtsLoading) return _loadingIndicator();
    if (_districtsError != null) {
      return _errorState(_districtsError!, _loadDistricts);
    }

    final states = _locationCtrl.browsableStates
        .where((s) =>
            _query.isEmpty || s.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    if (states.isEmpty) return _emptyState('No state matches "$_query"');
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: states
          .map((s) => _locationRow(
                icon: Iconsax.map,
                label: s,
                selected: s == _stateFilter,
                onTap: () => _pickState(s),
              ))
          .toList(),
    );
  }

  Widget _locationRow({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    final color = disabled
        ? AppColors.textHint
        : (selected ? AppColors.primary : AppColors.textDark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 17, color: disabled ? AppColors.textHint : color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _loadingIndicator() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.primary),
          ),
        ),
      );

  Widget _emptyState(String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight),
          ),
        ),
      );

  Widget _errorState(String message, VoidCallback onRetry) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
          ],
        ),
      );
}
