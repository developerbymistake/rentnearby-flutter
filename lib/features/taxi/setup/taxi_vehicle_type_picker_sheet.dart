import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../utils/input_formatters.dart';
import '../models/taxi_vehicle_type_model.dart';
import '../taxi_option_sets.dart';
import '../taxi_vehicle_types_controller.dart';

class TaxiVehicleTypePickerSheet extends StatefulWidget {
  final String? selectedId;
  const TaxiVehicleTypePickerSheet({super.key, this.selectedId});

  static Future<TaxiVehicleTypeModel?> show(BuildContext context, {String? selectedId}) {
    return showModalBottomSheet<TaxiVehicleTypeModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => TaxiVehicleTypePickerSheet(selectedId: selectedId),
    );
  }

  @override
  State<TaxiVehicleTypePickerSheet> createState() => _TaxiVehicleTypePickerSheetState();
}

class _TaxiVehicleTypePickerSheetState extends State<TaxiVehicleTypePickerSheet> {
  final _types = TaxiVehicleTypesController.ensure();
  final _searchCtrl = TextEditingController();
  String _query = '';
  double? _baseHeight;

  @override
  void initState() {
    super.initState();
    _types.ensureLoaded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _baseHeight ??= MediaQuery.of(context).size.height;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: (_baseHeight ?? 700) * 0.8,
        child: Column(children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Vehicle Type',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                Text('Pick from the list. Admin keeps the list updated.',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              inputFormatters: noEmojiInputFormatters,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search e.g. Innova',
                hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint),
                prefixIcon: const Icon(Iconsax.search_normal, size: 18, color: AppColors.textLight),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _query = '';
                        }),
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textLight),
                      ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: TaxiColors.accent, width: 1.5)),
              ),
            ),
          ),
          Expanded(child: Obx(_list)),
        ]),
      ),
    );
  }

  Widget _list() {
    final types = _types.types;
    if (types.isEmpty) {
      if (_types.isLoading.value) {
        return const Center(child: CircularProgressIndicator(color: TaxiColors.accent, strokeWidth: 2));
      }
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Couldn't load vehicle types",
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _types.load,
            child: const Text('Try again',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: TaxiColors.accentDark)),
          ),
        ]),
      );
    }
    final groups = _types.byCategory(_query);
    if (groups.isEmpty) {
      return const Center(
        child: Text('No match. Try another name.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, AppInsets.bottomViewPadding(context) + 16),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(TaxiOptionSets.categoryLabel(entry.key).toUpperCase(),
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.textHint)),
          ),
          for (final t in entry.value) _row(t),
        ],
      ],
    );
  }

  Widget _row(TaxiVehicleTypeModel t) {
    final selected = t.id == widget.selectedId;
    return InkWell(
      onTap: () => Navigator.pop(context, t),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? TaxiColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? TaxiColors.accent : AppColors.divider, width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(Iconsax.car, size: 18, color: selected ? TaxiColors.accentDark : AppColors.textLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(t.name,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: AppColors.textDark)),
          ),
          if (t.defaultSeats != null)
            Text('${TaxiOptionSets.seatsLabel(t.defaultSeats!)} seats',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
          if (selected) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle_rounded, size: 18, color: TaxiColors.accent),
          ],
        ]),
      ),
    );
  }
}
