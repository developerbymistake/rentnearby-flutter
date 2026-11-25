import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../owner_core/calendar/owner_upcoming_heading.dart';
import '../../owner_core/home/owner_home_models.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../home/stay_owner_home_controller.dart';
import '../strings/stay_calendar_strings.dart';
import '../strings/stay_home_strings.dart';
import '../widgets/stay_widgets.dart';
import 'stay_entry_rows.dart';

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
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OwnerUpcomingHeading(
          title: StayHomeStrings.upcomingBookings,
          sub: sub,
          seeAll: StayHomeStrings.seeAllLink,
          seeAllSemantics: StayCalendarStrings.seeAllUpcoming,
          onSeeAll: () => Get.toNamed(AppRoutes.stayUpcoming),
          linkColor: StayLook.greenText,
        ),
        Container(
          margin: DS.insets(l: 18, r: 18),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: DesignColors.surface, borderRadius: StayLook.cardRadius(34), boxShadow: DS.shadows(ShadowTokens.elev1)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ],
    );
  }
}
