import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../setup/stay_option_sets.dart';
import '../stay_types_controller.dart';
import 'v2/stay_landing_controller_v2.dart';

const _kAccent = DesignColors.primary;
const _tone = KitTone.stay;

class StayFilterSortSheet extends StatefulWidget {
  final StayLandingControllerV2 controller;

  const StayFilterSortSheet({super.key, required this.controller});

  static Future<void> show(BuildContext context, {required StayLandingControllerV2 controller}) {
    return SheetFrame.show(context, builder: (_) => StayFilterSortSheet(controller: controller));
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
    (value: 'nearest', label: 'Nearest'),
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
    final sheetHeight = (baseHeight * 0.78).clamp(0.0, maxHeight);
    return SizedBox(
      height: sheetHeight,
      child: StaggerHost(
        count: 4,
        child: SheetFrame(
          title: 'Filter & Sort · Stays',
          footer: StaggerItem(index: 3, child: _footer()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _group(0, [
                Text('Stay type', style: _sectionLabelStyle),
                const SizedBox(height: 8),
                _stayTypeGrid(),
              ]),
              const SizedBox(height: 16),
              _group(1, [
                Text('Meals', style: _sectionLabelStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: StayOptionSets.meals
                      .map((o) => PickChip(
                            label: o.label,
                            selected: _meals == o.value,
                            activeColor: _kAccent,
                            onTap: () => setState(() => _meals = _meals == o.value ? null : o.value),
                          ))
                      .toList(),
                ),
              ]),
              const SizedBox(height: 16),
              _group(2, [
                Text('Sort by', style: _sectionLabelStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sortOptions
                      .map((o) => PickChip(
                            label: o.label,
                            selected: _sort == o.value,
                            activeColor: _kAccent,
                            onTap: () => setState(() => _sort = o.value),
                          ))
                      .toList(),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group(int i, List<Widget> children) =>
      StaggerItem(index: i, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children));

  Widget _footer() {
    return Row(
      children: [
        Expanded(
          child: SecondaryButton(
            label: 'Clear',
            tone: _tone,
            neutral: true,
            onPressed: () => setState(() {
              _meals = null;
              _stayTypeId = null;
              _sort = StayLandingControllerV2.defaultSort;
            }),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: PrimaryButton(
            label: 'Apply',
            tone: _tone,
            onPressed: () {
              _closing = true;
              Navigator.of(context).pop();
              widget.controller.applyFilters(meals: _meals, stayTypeId: _stayTypeId, sort: _sort);
            },
          ),
        ),
      ],
    );
  }

  Widget _stayTypeGrid() {
    return Obx(() {
      final options = <({String? id, String name})>[
        (id: null, name: 'All'),
        ..._types.types.map((t) => (id: t.id, name: t.name)),
      ];
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options
            .map((t) => PickChip(
                  label: t.name,
                  selected: _stayTypeId == t.id,
                  activeColor: _kAccent,
                  onTap: () => setState(() => _stayTypeId = t.id),
                ))
            .toList(),
      );
    });
  }

  static final _sectionLabelStyle = TypeTokens.style(16, FontWeight.w600, color: DesignColors.textPrimary, letterSpacing: 0.18);
}
