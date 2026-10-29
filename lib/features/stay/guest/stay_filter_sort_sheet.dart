import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/selectable_chip.dart';
import '../setup/stay_option_sets.dart';
import '../stay_types_controller.dart';
import 'stay_landing_controller.dart';

const _kSortChipPadding = EdgeInsets.symmetric(vertical: 13, horizontal: 10);

class StayFilterSortSheet extends StatefulWidget {
  final StayLandingController controller;

  const StayFilterSortSheet({super.key, required this.controller});

  static Future<void> show(BuildContext context, {required StayLandingController controller}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StayFilterSortSheet(controller: controller),
    );
  }

  @override
  State<StayFilterSortSheet> createState() => _StayFilterSortSheetState();
}

class _StayFilterSortSheetState extends State<StayFilterSortSheet> {
  late String? _meals = widget.controller.selectedMeals.value;
  late String? _stayTypeId = widget.controller.selectedStayTypeId.value;
  final _types = StayTypesController.ensure();
  late String _sort = widget.controller.sortBy.value;

  Worker? _externalResetWorker;
  bool _closing = false;
  double? _baseHeight;
  double? _baseTopPadding;

  static const _sortOptions = [
    (value: 'newest', label: 'Newest'),
    (value: 'price_asc', label: 'Price: low to high'),
    (value: 'price_desc', label: 'Price: high to low'),
  ];

  @override
  void initState() {
    super.initState();
    _types.ensureLoaded();
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

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final baseHeight = _baseHeight ?? media.size.height;
    final baseTopPadding = _baseTopPadding ?? media.padding.top;
    final maxHeight = (baseHeight - baseTopPadding) * 0.94;
    final sheetHeight = (baseHeight * 0.55).clamp(0.0, maxHeight);
    return SizedBox(
      height: sheetHeight,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
            decoration: const BoxDecoration(
              gradient: StayColors.gradient,
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
                const Text(
                  'Filter & Sort · Stays',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
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
                  const Text('Stay type', style: _sectionLabelStyle),
                  const SizedBox(height: 8),
                  _stayTypeGrid(),
                  const SizedBox(height: 16),
                  const Text('Meals', style: _sectionLabelStyle),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 2.4,
                    children: StayOptionSets.meals
                        .map((o) => SelectableChip(
                              label: o.label,
                              selected: _meals == o.value,
                              activeColor: StayColors.accent,
                              onTap: () => setState(() => _meals = _meals == o.value ? null : o.value),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Sort by', style: _sectionLabelStyle),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SelectableChip(
                      label: _sortOptions[0].label,
                      selected: _sort == _sortOptions[0].value,
                      activeColor: StayColors.accent,
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
                                  activeColor: StayColors.accent,
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
                      _meals = null;
                      _stayTypeId = null;
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
                    gradient: StayColors.gradient,
                    shadowColor: StayColors.accent,
                    onPressed: () {
                      _closing = true;
                      Navigator.of(context).pop();
                      widget.controller.applyFilters(meals: _meals, stayTypeId: _stayTypeId, sort: _sort);
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

  Widget _stayTypeGrid() {
    return Obx(() {
      final options = <({String? id, String name})>[
        (id: null, name: 'All'),
        ..._types.types.map((t) => (id: t.id, name: t.name)),
      ];
      return GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 2.4,
        children: options
            .map((t) => SelectableChip(
                  label: t.name,
                  selected: _stayTypeId == t.id,
                  activeColor: StayColors.accent,
                  onTap: () => setState(() => _stayTypeId = t.id),
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
