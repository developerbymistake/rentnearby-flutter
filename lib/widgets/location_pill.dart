import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/module_palette.dart';
import '../controllers/location_controller.dart';
import '../design/design.dart';
import 'location_switch_sheet.dart';

class LocationPill extends StatelessWidget {
  final ModulePalette palette;
  const LocationPill({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    final locationCtrl = Get.find<LocationController>();
    return Obx(() {
      final district = locationCtrl.effectiveDistrict;
      if (district == null) return const SizedBox();
      final cityName = locationCtrl.browsingCity.value?.name ??
          locationCtrl.autoCity.value?.name ??
          'Current';
      final searchLabel = locationCtrl.searchPinLabel.value;
      final searching = searchLabel != null;

      final List<InlineSpan> spans = searching
          ? [TextSpan(text: searchLabel)]
          : [
              TextSpan(text: district.name),
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 14, color: FitnessAppTheme.lightText),
                ),
              ),
              TextSpan(text: cityName),
            ];

      return GestureDetector(
        onTap: searching
            ? null
            : () => LocationSwitchSheet.show(context, palette: palette),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: GateKit.pill(),
          child: Row(children: [
            const TravelIcon(TravelIcon.map, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(children: spans),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: FitnessAppTheme.body2.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FitnessAppTheme.nearlyDarkBlue),
              ),
            ),
            if (!searching) ...[
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: FitnessAppTheme.nearlyDarkBlue, size: 16),
            ],
          ]),
        ),
      );
    });
  }
}
