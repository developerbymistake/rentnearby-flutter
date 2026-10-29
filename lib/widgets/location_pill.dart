import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/module_palette.dart';
import '../controllers/location_controller.dart';
import 'location_switch_sheet.dart';

/// Single shared city pill for the module map screens; [palette] is the only
/// thing that differs per module.
class LocationPill extends StatelessWidget {
  final ModulePalette palette;
  const LocationPill({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    final locationCtrl = Get.find<LocationController>();
    final accentColor = palette.accent;
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
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 14, color: accentColor.withValues(alpha: 0.6)),
                ),
              ),
              TextSpan(text: cityName),
            ];

      return GestureDetector(
        // Disabled while a location search is active — user must cancel the
        // search (via the toggle button) before switching city again, so
        // the two temporary overrides are never open at once.
        onTap: searching ? null : () => LocationSwitchSheet.show(context, palette: palette),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(children: [
            Icon(Icons.public_rounded, color: accentColor, size: 15),
            const SizedBox(width: 7),
            Expanded(
              child: Text.rich(
                TextSpan(children: spans),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accentColor),
              ),
            ),
            if (!searching) ...[
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: accentColor, size: 16),
            ],
          ]),
        ),
      );
    });
  }
}
