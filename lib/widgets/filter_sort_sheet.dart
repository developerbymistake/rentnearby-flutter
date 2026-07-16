import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../controllers/listing_controller.dart';
import '../controllers/plot_controller.dart';
import '../controllers/view_all_controller.dart';
import 'gradient_button.dart';
import 'selectable_chip.dart';

const _kPlotGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF92400E), Color(0xFF78350F)],
);
const _kPlotColor = Color(0xFF92400E);

// Sort options render one-per-row (full-width Newest, then a 2-up pair) so
// they read as real buttons — taller than the dense room/plot type grid's
// default chip padding, which stays untouched.
const _kSortChipPadding = EdgeInsets.symmetric(vertical: 13, horizontal: 10);

/// Modal sheet mirroring ReportListingSheet's structure (gradient header +
/// drag handle, showModalBottomSheet with top-24 rounded corners) — type
/// chips (3-per-row Rooms / 2-per-row Plots, matching the real counts) +
/// sort chips (always 1 row of 3, Newest pre-selected/default). Clear resets
/// the in-sheet draft without closing; Apply commits + closes.
///
/// Takes the controller directly (not a snapshot of its values) so it can
/// watch for an external reset (location change, Rooms/Plots toggle flip)
/// while open and dismiss itself instead of silently showing/committing a
/// stale draft — same defensive pattern LocationSwitchSheet already uses
/// against LocationController.refreshOnResume() clearing browsingDistrict
/// out from under it.
class FilterSortSheet extends StatefulWidget {
  final ViewAllController controller;

  const FilterSortSheet({super.key, required this.controller});

  static Future<void> show(BuildContext context, {required ViewAllController controller}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FilterSortSheet(controller: controller),
    );
  }

  @override
  State<FilterSortSheet> createState() => _FilterSortSheetState();
}

class _FilterSortSheetState extends State<FilterSortSheet> {
  late String? _typeId = widget.controller.selectedTypeId.value;
  late String _sort = widget.controller.sortBy.value;

  Worker? _externalResetWorker;
  bool _closing = false;

  // Same frozen-baseline approach as LocationSearchSheet/LocationSwitchSheet
  // — captured once before the keyboard/system UI can shrink MediaQuery's
  // live size, so the sheet's height doesn't recompute mid-interaction.
  double? _baseHeight;
  double? _baseTopPadding;

  @override
  void initState() {
    super.initState();
    _externalResetWorker = ever(widget.controller.resetGeneration, (_) {
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
    _externalResetWorker?.dispose();
    super.dispose();
  }

  bool get _isRooms => widget.controller.activeType.value == ViewAllListingType.rooms;
  Color get _activeColor => _isRooms ? AppColors.primary : _kPlotColor;
  Gradient get _headerGradient => _isRooms ? AppColors.primaryGradient : _kPlotGradient;

  List<_SortOption> get _sortOptions => _isRooms
      ? const [
          _SortOption('newest', 'Newest'),
          _SortOption('price_asc', 'Price: Low-High'),
          _SortOption('price_desc', 'Price: High-Low'),
        ]
      : const [
          _SortOption('newest', 'Newest'),
          _SortOption('area_asc', 'Area: Low-High'),
          _SortOption('area_desc', 'Area: High-Low'),
        ];

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
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
            decoration: BoxDecoration(
              gradient: _headerGradient,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                Text(
                  'Filter & Sort · ${_isRooms ? 'Rooms' : 'Plots'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_isRooms ? 'Room type' : 'Plot type', style: _sectionLabelStyle),
                  const SizedBox(height: 8),
                  _isRooms ? _roomTypeGrid() : _plotTypeGrid(),
                  const SizedBox(height: 16),
                  Text('Sort by', style: _sectionLabelStyle),
                  const SizedBox(height: 8),
                  // Newest alone on its own row (it's the default), the
                  // directional pair (price/area low-high, high-low) below it.
                  SizedBox(
                    width: double.infinity,
                    child: SelectableChip(
                      label: _sortOptions[0].label,
                      selected: _sort == _sortOptions[0].value,
                      activeColor: _activeColor,
                      padding: _kSortChipPadding,
                      onTap: () => setState(() => _sort = _sortOptions[0].value),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _sortOptions
                        .skip(1)
                        .map((o) => Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: o != _sortOptions.last ? 6 : 0),
                                child: SelectableChip(
                                  label: o.label,
                                  selected: _sort == o.value,
                                  activeColor: _activeColor,
                                  padding: _kSortChipPadding,
                                  onTap: () => setState(() => _sort = o.value),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + media.padding.bottom),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _typeId = null;
                      _sort = 'newest';
                    }),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: AppColors.divider, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Clear',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GradientButton(
                    label: 'Apply',
                    height: 46,
                    gradient: _headerGradient,
                    shadowColor: _activeColor,
                    onPressed: () {
                      _closing = true;
                      Navigator.of(context).pop();
                      widget.controller.applyFilters(typeId: _typeId, sort: _sort);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roomTypeGrid() {
    return Obx(() {
      final types = Get.find<ListingController>().roomTypes;
      return GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 2.4,
        children: types
            .map((t) => SelectableChip(
                  label: t.name,
                  selected: _typeId == t.id,
                  activeColor: _activeColor,
                  onTap: () => setState(() => _typeId = _typeId == t.id ? null : t.id),
                ))
            .toList(),
      );
    });
  }

  Widget _plotTypeGrid() {
    return Obx(() {
      final types = Get.find<PlotController>().plotTypes;
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 3.6,
        children: types
            .map((t) => SelectableChip(
                  label: t.name,
                  selected: _typeId == t.id,
                  activeColor: _activeColor,
                  onTap: () => setState(() => _typeId = _typeId == t.id ? null : t.id),
                ))
            .toList(),
      );
    });
  }

  static const _sectionLabelStyle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: AppColors.textLight,
    letterSpacing: 0.4,
  );
}

class _SortOption {
  final String value;
  final String label;
  const _SortOption(this.value, this.label);
}
