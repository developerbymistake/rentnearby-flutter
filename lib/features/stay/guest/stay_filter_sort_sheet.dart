import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../setup/stay_option_sets.dart';
import '../stay_types_controller.dart';
import 'v2/stay_landing_controller_v2.dart';

final _tone = ListingTone.forest;

class StayFilterSortSheet extends StatefulWidget {
  final StayLandingControllerV2 controller;

  const StayFilterSortSheet({super.key, required this.controller});

  static Future<void> show(BuildContext context, {required StayLandingControllerV2 controller}) {
    return Sheet3D.show<void>(context, builder: (_) => StayFilterSortSheet(controller: controller));
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

  static final _typeLook = [
    (ListingTone.cE, ListingArt.sunrise),
    (ListingTone.cA, ListingArt.bed),
    (ListingTone.cB, ListingArt.hotel),
    (ListingTone.cC, ListingArt.beach),
    (ListingTone.cF, ListingArt.tent),
    (ListingTone.cD, ListingArt.mountain),
  ];
  static final _mealLook = [
    (ListingTone.cA, ListingArt.key),
    (ListingTone.cF, ListingArt.sunrise),
    (ListingTone.cE, ListingArt.backpack),
  ];
  static final _sortLook = [
    (ListingTone.cB, ListingArt.roundPushpin),
    (ListingTone.cE, ListingArt.moneyBag),
    (ListingTone.cD, ListingArt.moneyBag),
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
      height: sheetHeight + Sheet3D.artRoom,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Sheet3D(
        tone: _tone,
        art: ListingArt.hotel,
        title: 'Filter & Sort · Stays',
        centerTitle: false,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
        footer: _footer(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label('Stay type', first: true),
            _stayTypeGrid(),
            _label('Meals'),
            _grid([
              for (var i = 0; i < StayOptionSets.meals.length; i++)
                _card(_mealLook[i % _mealLook.length], StayOptionSets.meals[i].label, _meals == StayOptionSets.meals[i].value,
                    () => setState(() => _meals = _meals == StayOptionSets.meals[i].value ? null : StayOptionSets.meals[i].value)),
            ]),
            _label('Sort by'),
            _grid([
              for (var i = 0; i < _sortOptions.length; i++)
                _card(_sortLook[i % _sortLook.length], _sortOptions[i].label, _sort == _sortOptions[i].value,
                    () => setState(() => _sort = _sortOptions[i].value)),
            ]),
          ],
        ),
        ),
      ),
    );
  }

  Widget _label(String text, {bool first = false}) => Padding(
        padding: EdgeInsets.fromLTRB(2, first ? 4 : 18, 2, 0),
        child: Semantics(header: true, child: Text(text, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, height: 1.45))),
      );

  Widget _card((ListingTone, String) look, String label, bool selected, VoidCallback onTap) =>
      GradientOptionCard(tone: look.$1, art: look.$2, label: label, selected: selected, onTap: onTap);

  Widget _grid(List<Widget> cards) {
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 3) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var j = i; j < i + 3; j++) ...[
            if (j > i) const SizedBox(width: 10),
            Expanded(child: j < cards.length ? cards[j] : const SizedBox.shrink()),
          ],
        ],
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  Widget _footer() {
    return PillButtonRow(
      children: [
        WhitePillButton(
          tone: _tone,
          label: 'Clear',
          height: 52,
          onTap: () => setState(() {
            _meals = null;
            _stayTypeId = null;
            _sort = StayLandingControllerV2.defaultSort;
          }),
        ),
        GradientPillButton(
          tone: _tone,
          label: 'Apply',
          height: 52,
          onTap: () {
            _closing = true;
            Navigator.of(context).pop();
            widget.controller.applyFilters(meals: _meals, stayTypeId: _stayTypeId, sort: _sort);
          },
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
      return _grid([
        for (var i = 0; i < options.length; i++)
          _card(_typeLook[i % _typeLook.length], options[i].name, _stayTypeId == options[i].id,
              () => setState(() => _stayTypeId = options[i].id)),
      ]);
    });
  }
}
