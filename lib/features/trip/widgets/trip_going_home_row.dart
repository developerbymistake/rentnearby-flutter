import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/module_palette.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_constants.dart';
import '../trip_strings_going_home.dart';

extension TripGoingHomeSetter on TripPlanController {
  TripStartFrom? get goingHomeTo => plan.value?.steps.goingHomeTo;

  // Where Coming back ends: the picked city, else the starting city.
  String get homeEndName => plan.value?.steps.homeEnd?.name ?? '';

  bool setGoingHomeTo(TripStartFrom? v) {
    final p = plan.value;
    if (p == null || isReadOnly) return false;
    var name = v?.name.trim() ?? '';
    if (name.length > TripConstants.startFromNameMax) name = name.substring(0, TripConstants.startFromNameMax).trim();
    final next = v == null || name.isEmpty ? null : TripStartFrom(name: name, lat: v.lat, lon: v.lon);
    final old = p.steps.goingHomeTo;
    if (next == null ? old == null : next.sameAs(old)) return false;
    plan.value = p.copyWith(
      steps: next == null ? p.steps.copyWith(clearGoingHomeTo: true) : p.steps.copyWith(goingHomeTo: next),
    );
    scheduleSave();
    return true;
  }
}

class TripGoingHomeRow extends StatefulWidget {
  const TripGoingHomeRow({super.key});

  @override
  State<TripGoingHomeRow> createState() => _TripGoingHomeRowState();
}

class _TripGoingHomeRowState extends State<TripGoingHomeRow> {
  final _c = TripPlanController.to;

  Future<void> _pick() async {
    final p = await LocationSwitchSheet.pick(context, palette: ModulePalette.trip, title: TripStringsGoingHome.pick);
    if (p == null || !mounted) return;
    setState(() => _c.setGoingHomeTo(TripStartFrom(name: p.name, lat: p.latitude, lon: p.longitude)));
  }

  @override
  Widget build(BuildContext context) {
    final home = _c.goingHomeTo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: TripColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _pick,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TripColors.accentLight.withValues(alpha: 0.7), width: 1.3),
            ),
            child: Row(
              children: [
                const Icon(Iconsax.home_2, size: 20, color: TripColors.accentDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(TripStringsGoingHome.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: AppColors.warningText)),
                      Text(home?.name ?? (_c.homeEndName.isEmpty ? TripStringsGoingHome.sameAsStart : _c.homeEndName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: home == null ? AppColors.textLight : AppColors.textDark)),
                    ],
                  ),
                ),
                if (home != null)
                  TextButton(
                    onPressed: () => setState(() => _c.setGoingHomeTo(null)),
                    style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                    child: const Text(TripStringsGoingHome.reset,
                        maxLines: 1, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600)),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(TripStringsGoingHome.change,
                        style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: TripColors.accentDark)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
