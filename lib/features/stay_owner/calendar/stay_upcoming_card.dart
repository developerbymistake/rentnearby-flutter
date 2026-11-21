import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../owner_core/home/owner_home_models.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../home/stay_owner_home_controller.dart';
import '../strings/stay_calendar_strings.dart';
import '../widgets/stay_widgets.dart';
import 'stay_entry_rows.dart';
import 'widgets/stay_calendar_widgets.dart';

class StayUpcomingCard extends StatelessWidget {
  const StayUpcomingCard({super.key, this.upcoming, this.loading = false});

  final OwnerUpcoming? upcoming;
  final bool loading;

  static Widget fromHome() {
    final c = StayOwnerHomeController.maybe;
    if (c == null) return const SizedBox.shrink();
    return Obx(() {
      final load = c.load.value;
      return StayUpcomingCard(upcoming: load.valueOrNull?.upcoming, loading: load is OwnerLoadLoading<OwnerHomeDto>);
    });
  }

  @override
  Widget build(BuildContext context) {
    final u = upcoming;
    if (u == null && !loading) return const SizedBox.shrink();
    final days = u?.windowLabelDays;
    final sixMonths = days != null && days >= 180 || (u != null && days == null && !u.window.locked);
    final sub = sixMonths ? StayCalendarStrings.next6Months : StayCalendarStrings.nextDays(days ?? 15);
    final rows = u?.rows ?? const [];
    final more = u?.moreInWindowCount ?? 0;
    final beyond = u?.beyondWindowAppCount ?? 0;
    final after = u?.window.upcomingTo ?? u?.beyondWindowFirstDate;
    final showBeyond = PlanGate.canUpgrade && beyond > 0 && after != null && !sixMonths;
    final children = <Widget>[];
    if (loading && u == null) {
      for (var i = 0; i < 3; i++) {
        children.add(Padding(padding: DS.sym(h: 14, v: 8), child: SkeletonBox(height: DS.s(48), radius: DS.radius(12))));
      }
    } else {
      for (var i = 0; i < rows.length; i++) {
        if (i > 0) children.add(Divider(height: DS.s(1), thickness: DS.s(1), color: StayLook.rowLine));
        children.add(StayEntryRows.home(rows[i]));
      }
      if (more > 0) {
        children.add(Container(
          decoration: BoxDecoration(color: DesignColors.surfaceAlt, border: Border(top: BorderSide(color: StayLook.rowLine, width: DS.s(1)))),
          padding: DS.sym(h: 14, v: 4),
          child: Row(
            children: [
              ExcludeSemantics(child: Art3D(asset: ListingArt.calendar, size: 20)),
              Gap.h(8),
              Expanded(
                child: Text(StayCalendarStrings.moreInWindow(more, StayCalendarStrings.windowWords(days)),
                    style: Ink3D.text(11, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
              ),
              Semantics(
                label: StayCalendarStrings.seeAllUpcoming,
                button: true,
                excludeSemantics: true,
                child: StayPill(label: StayCalendarStrings.seeAll, kind: StayPillKind.outline, onTap: () => Get.toNamed(AppRoutes.stayUpcoming)),
              ),
            ],
          ),
        ));
      }
      if (showBeyond) {
        children.add(StayAmberRow(text: StayCalendarStrings.beyondWindow(after, beyond)));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: DS.insets(l: 22, t: 22, r: 22, b: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(StayCalendarStrings.upcoming, style: Ink3D.text(17, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
              Gap.h(8),
              Flexible(child: Text(sub, style: Ink3D.text(11, FontWeight.w500, Ink3D.grey, letterSpacing: 0))),
            ],
          ),
        ),
        if (children.isNotEmpty)
          Container(
            margin: DS.insets(l: 18, r: 18),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: DesignColors.surface, borderRadius: StayLook.cardRadius(34), boxShadow: DS.shadows(ShadowTokens.elev1)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        Padding(
          padding: DS.insets(l: 18, t: 12, r: 18),
          child: Row(
            children: [
              Expanded(child: StayPill(label: StayCalendarStrings.viewCalendar, kind: StayPillKind.indigo, expand: true, onTap: () => Get.toNamed(AppRoutes.stayCalendar))),
              Gap.h(8),
              Expanded(child: StayPill(label: StayCalendarStrings.past, kind: StayPillKind.outline, expand: true, onTap: () => Get.toNamed(AppRoutes.stayPast))),
              Gap.h(8),
              Expanded(
                child: StayPill(
                  label: StayCalendarStrings.addBooking,
                  kind: StayPillKind.outline,
                  expand: true,
                  onTap: () => Get.toNamed(AppRoutes.stayCalendar, arguments: const {'add': true}),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
