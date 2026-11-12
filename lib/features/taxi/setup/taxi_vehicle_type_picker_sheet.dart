import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_insets.dart';
import '../../../design/design.dart';
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
      backgroundColor: FitnessAppTheme.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
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
        height: (_baseHeight ?? 700) * 0.7,
        child: Column(children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            decoration: BoxDecoration(color: FitnessAppTheme.spacer, borderRadius: BorderRadius.circular(2)),
          ),
          TemplateEntranceOnce(
            index: 0,
            count: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Vehicle Type', style: TripKit.text(18, weight: FontWeight.w700).copyWith(letterSpacing: 0.27)),
                  Text('Pick from the list. Admin keeps the list updated.',
                      style: TripKit.text(12, color: FitnessAppTheme.lightText)),
                ]),
              ),
            ),
          ),
          TemplateEntranceOnce(
            index: 1,
            count: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                inputFormatters: noEmojiInputFormatters,
                cursorColor: FitnessAppTheme.nearlyDarkBlue,
                onChanged: (v) => setState(() => _query = v),
                style: TripKit.text(14),
                decoration: InputDecoration(
                  hintText: 'Search e.g. Innova',
                  hintStyle: TripKit.text(14, color: FitnessAppTheme.deactivatedText),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: FitnessAppTheme.lightText),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(() {
                            _searchCtrl.clear();
                            _query = '';
                          }),
                          icon: const Icon(Icons.close_rounded, size: 18, color: FitnessAppTheme.lightText),
                        ),
                  filled: true,
                  fillColor: FitnessAppTheme.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  enabledBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: FitnessAppTheme.nearlyDarkBlue, width: 1.5)),
                ),
              ),
            ),
          ),
          Expanded(child: Obx(_list)),
        ]),
      ),
    );
  }

  Widget _list() {
    final types = _types.types.toList();
    final loading = _types.isLoading.value;
    final failed = _types.loadFailed.value;
    if (types.isEmpty) {
      if (loading) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(children: [
            for (var i = 0; i < 5; i++) ...[
              const TemplatePlaceholder(height: 44, radius: 12),
              const SizedBox(height: 10),
            ],
          ]),
        );
      }
      if (!failed) {
        return Center(
          child: Text('No vehicle types yet', style: TripKit.text(14, color: FitnessAppTheme.grey)),
        );
      }
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Couldn't load vehicle types", style: TripKit.text(14, color: FitnessAppTheme.grey)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _types.load,
            style: TextButton.styleFrom(minimumSize: const Size(88, 44)),
            child: Text('Try again',
                style: TripKit.text(14, weight: FontWeight.w600, color: FitnessAppTheme.nearlyDarkBlue)),
          ),
        ]),
      );
    }
    final groups = _types.byCategory(_query);
    if (groups.isEmpty) {
      return Center(
        child: Text('No match. Try another name.', style: TripKit.text(13, color: FitnessAppTheme.lightText)),
      );
    }
    final items = <Object>[
      for (final entry in groups.entries) ...[entry.key, ...entry.value],
    ];
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 0, 16, AppInsets.bottomViewPadding(context) + 16),
      itemCount: items.length,
      separatorBuilder: (_, i) => items[i] is String || items[i + 1] is String
          ? const SizedBox.shrink()
          : const Divider(height: 1, thickness: 1, color: FitnessAppTheme.spacer),
      itemBuilder: (_, i) {
        final item = items[i];
        return item is TaxiVehicleTypeModel ? _row(item) : _groupHeader(item as String);
      },
    );
  }

  Widget _groupHeader(String category) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(TaxiOptionSets.categoryLabel(category).toUpperCase(),
            style: TripKit.text(11, weight: FontWeight.w700, color: FitnessAppTheme.deactivatedText)
                .copyWith(letterSpacing: 0.4)),
      );

  Widget _row(TaxiVehicleTypeModel t) {
    final selected = t.id == widget.selectedId;
    return InkWell(
      onTap: () => Navigator.pop(context, t),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected ? PickKit.taxiGradient : null,
                color: selected ? null : FitnessAppTheme.background,
              ),
              child: Image.asset(TravelIcon.taxi),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(t.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TripKit.text(14,
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? FitnessAppTheme.nearlyDarkBlue : FitnessAppTheme.darkerText)),
            ),
            if (t.defaultSeats != null) ...[
              const SizedBox(width: 8),
              Text('${TaxiOptionSets.seatsLabel(t.defaultSeats!)} seats',
                  style: TripKit.text(11, color: FitnessAppTheme.lightText)),
            ],
            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle_rounded, size: 20, color: FitnessAppTheme.nearlyDarkBlue),
            ],
          ]),
        ),
      ),
    );
  }
}
