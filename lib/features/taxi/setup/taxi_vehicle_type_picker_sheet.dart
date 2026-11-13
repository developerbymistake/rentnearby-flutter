import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_taxi_owner.dart';
import '../../../utils/input_formatters.dart';
import '../models/taxi_vehicle_type_model.dart';
import '../taxi_option_sets.dart';
import '../taxi_vehicle_types_controller.dart';

class TaxiVehicleTypePickerSheet extends StatefulWidget {
  final String? selectedId;
  const TaxiVehicleTypePickerSheet({super.key, this.selectedId});

  static Future<TaxiVehicleTypeModel?> show(BuildContext context, {String? selectedId}) {
    return Sheet3D.show<TaxiVehicleTypeModel>(
      context,
      builder: (_) => TaxiVehicleTypePickerSheet(selectedId: selectedId),
    );
  }

  @override
  State<TaxiVehicleTypePickerSheet> createState() => _TaxiVehicleTypePickerSheetState();
}

class _TaxiVehicleTypePickerSheetState extends State<TaxiVehicleTypePickerSheet> {
  static final ListingTone _tone = ListingTone.coral;
  final _types = TaxiVehicleTypesController.ensure();
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _types.ensureLoaded();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Sheet3D(
      tone: _tone,
      art: TaxiOwnerArt.car,
      title: 'Vehicle Type',
      subtitle: 'Pick from the list. Admin keeps the list updated.',
      centerTitle: false,
      artRight: true,
      size: SheetSize.list,
      scrollable: false,
      padding: EdgeInsets.zero,
      child: Column(children: [
        Stack(
          alignment: Alignment.centerRight,
          children: [
            SheetSearchField(
              tone: _tone,
              flat: true,
              controller: _searchCtrl,
              hint: 'Search e.g. Innova',
              leadingArt: ListingArt.compass,
              inputFormatters: noEmojiInputFormatters,
              onChanged: (v) => setState(() => _query = v),
            ),
            if (_query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 24, top: 6),
                child: IconButton(
                  tooltip: 'Clear',
                  onPressed: () => setState(() {
                    _searchCtrl.clear();
                    _query = '';
                  }),
                  icon: const Icon(Icons.close_rounded, size: 20, color: Ink3D.grey),
                ),
              ),
          ],
        ),
        Expanded(child: Obx(_list)),
      ]),
    );
  }

  Widget _plain(String art, String title, {String? action, VoidCallback? onAction}) => ListView(
        padding: const EdgeInsets.only(top: 40),
        children: [
          StateCard3D(tone: _tone, art: art, title: title, actionLabel: action, onAction: onAction, layout: StateLayout.plain),
        ],
      );

  Widget _list() {
    final types = _types.types.toList();
    final loading = _types.isLoading.value;
    final failed = _types.loadFailed.value;
    if (types.isEmpty) {
      if (loading) {
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 6),
          children: [for (var i = 0; i < 5; i++) const SkeletonListRow()],
        );
      }
      if (!failed) return _plain(TaxiOwnerArt.car, 'No vehicle types yet');
      return _plain(ListingArt.clipboard, "Couldn't load vehicle types", action: 'Try again', onAction: _types.load);
    }
    final groups = _types.byCategory(_query);
    if (groups.isEmpty) return _plain(ListingArt.taxi, 'No match. Try another name.');
    final items = <Object>[
      for (final entry in groups.entries) ...[entry.key, ...entry.value],
    ];
    return ListView.builder(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item is TaxiVehicleTypeModel) return _row(item, divider: i > 0 && items[i - 1] is! String);
        return Padding(padding: const EdgeInsets.only(top: 12, bottom: 2), child: DayLabel3D(TaxiOptionSets.categoryLabel(item as String).toUpperCase()));
      },
    );
  }

  Widget _row(TaxiVehicleTypeModel t, {required bool divider}) {
    final selected = t.id == widget.selectedId;
    return SheetListRow(
      tone: _tone,
      art: ListingArt.taxi,
      roundArt: true,
      title: t.name,
      selected: selected,
      divider: divider,
      onTap: () => Navigator.pop(context, t),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (t.defaultSeats != null) Text('${TaxiOptionSets.seatsLabel(t.defaultSeats!)} seats', style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey)),
        const SizedBox(width: 10),
        Container(
          width: 28,
          height: 28,
          decoration: selected ? BoxDecoration(shape: BoxShape.circle, gradient: _tone.gradient, boxShadow: _tone.glow(blur: 6, dy: 3)) : null,
          child: selected ? const Icon(Icons.check_rounded, size: 17, color: DesignColors.textInverse) : null,
        ),
      ]),
    );
  }
}
