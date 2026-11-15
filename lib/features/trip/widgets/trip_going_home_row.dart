import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
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
    final p = await LocationSwitchSheet.pick(context, title: TripStringsGoingHome.pick);
    if (p == null || !mounted) return;
    setState(() => _c.setGoingHomeTo(TripStartFrom(name: p.name, lat: p.latitude, lon: p.longitude)));
  }

  @override
  Widget build(BuildContext context) {
    final home = _c.goingHomeTo;
    return Padding(
      padding: EdgeInsets.only(bottom: DS.gv(12)),
      child: DecoratedBox(
        decoration: TripLook.card(),
        child: InkWell(
          onTap: _pick,
          borderRadius: DS.br(TripLook.softRadius),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(minHeight: DS.s(56)),
            padding: DS.insets(l: 12, t: 8, r: 4, b: 8),
            child: Row(
              children: [
                Container(
                  width: DS.s(36),
                  height: DS.s(36),
                  decoration: BoxDecoration(
                    gradient: TripLook.gradient,
                    shape: BoxShape.circle,
                    boxShadow: DS.shadows(TripLook.shadowFor(FitnessAppTheme.nearlyDarkBlue)),
                  ),
                  child: const Center(child: TravelIcon(TravelIcon.place, size: 20)),
                ),
                Gap.h(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(TripStringsGoingHome.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: FitnessAppTheme.fontName,
                              fontSize: DS.f(11),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: TripLook.warningText)),
                      Text(home?.name ?? (_c.homeEndName.isEmpty ? TripStringsGoingHome.sameAsStart : _c.homeEndName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: FitnessAppTheme.fontName,
                              fontSize: DS.f(13),
                              fontWeight: FontWeight.w600,
                              color: home == null ? TripLook.textLight : TripLook.textDark)),
                    ],
                  ),
                ),
                if (home != null)
                  InkWell(
                    onTap: () => setState(() => _c.setGoingHomeTo(null)),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: SizedBox(
                      width: DS.s(56),
                      height: DS.s(44),
                      child: Center(
                        child: Text(TripStringsGoingHome.reset,
                            maxLines: 1,
                            style: TextStyle(
                                fontFamily: FitnessAppTheme.fontName,
                                fontSize: DS.f(12),
                                fontWeight: FontWeight.w600,
                                color: FitnessAppTheme.nearlyDarkBlue)),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: DS.sym(h: 12),
                    child: Text(TripStringsGoingHome.change,
                        style: TextStyle(
                            fontFamily: FitnessAppTheme.fontName, fontSize: DS.f(12), fontWeight: FontWeight.w700, color: TripLook.accentDark)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
