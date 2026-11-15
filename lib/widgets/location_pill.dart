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
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: DS.s(4)),
                  child: Icon(Icons.chevron_right_rounded,
                      size: DS.s(14), color: FitnessAppTheme.lightText),
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
          padding: DS.sym(h: 14, v: 10),
          decoration: GateKit.pill(),
          child: Row(children: [
            const TravelIcon(TravelIcon.map, size: 18),
            SizedBox(width: DS.s(8)),
            Expanded(
              child: Text.rich(
                TextSpan(children: spans),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: FitnessAppTheme.body2.copyWith(
                    fontSize: DS.f(13),
                    fontWeight: FontWeight.w700,
                    color: FitnessAppTheme.nearlyDarkBlue),
              ),
            ),
            if (!searching) ...[
              SizedBox(width: DS.s(4)),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: FitnessAppTheme.nearlyDarkBlue, size: DS.s(16)),
            ],
          ]),
        ),
      );
    });
  }
}
