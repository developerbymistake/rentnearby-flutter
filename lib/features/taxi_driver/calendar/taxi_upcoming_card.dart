import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/calendar/owner_upcoming_heading.dart';
import '../../owner_core/home/owner_home_models.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/plan/soft_lock.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../home/taxi_driver_home_controller.dart';
import '../strings/taxi_calendar_strings.dart';
import '../taxi_driver_deps.dart';
import '../widgets/taxi_widgets.dart';
import 'taxi_calendar_controller.dart';
import 'taxi_calendar_widgets.dart';
import 'taxi_trip_sheet.dart';
import 'taxi_trip_text.dart';

abstract final class TaxiUpcomingWords {
  static String window({int? labelDays}) {
    final months = PlanGate.limit(PlanKey.monthsAhead);
    if (months > 0) return TaxiCalendarStrings.nextMonths(months);
    return TaxiCalendarStrings.nextDays(labelDays ?? PlanGate.limit(PlanKey.upcomingDays));
  }

  static int get plusMonths => PlanKeys.plusSeed[PlanKey.monthsAhead] ?? 6;
}

abstract final class TaxiAddTrip {
  static Future<void> fromAnywhere(BuildContext context) async {
    final c = TaxiCalendarController.acquire();
    try {
      if (c.current == null) c.open(c.serverToday).ignore();
      await TaxiTripSheet.show(context, controller: c, date: c.serverToday);
    } finally {
      TaxiCalendarController.release();
    }
  }
}

class TaxiUpcomingCard extends StatelessWidget {
  const TaxiUpcomingCard({super.key});

  static OwnerLoad<OwnerUpcoming> _read(TaxiDriverHomeController home) => switch (home.load.value) {
        OwnerLoadData<OwnerHomeDto>(:final value, :final stale) => OwnerLoadData(value.upcoming, stale: stale),
        OwnerLoadLoading<OwnerHomeDto>() => const OwnerLoadLoading(),
        _ => const OwnerLoadError(),
      };

  @override
  Widget build(BuildContext context) {
    final home = TaxiDriverHomeController.maybe;
    if (home == null) return const TaxiUpcomingCardView(load: OwnerLoadLoading());
    return Obx(() => TaxiUpcomingCardView(load: _read(home)));
  }
}

class TaxiUpcomingCardView extends StatelessWidget {
  const TaxiUpcomingCardView({super.key, required this.load});

  final OwnerLoad<OwnerUpcoming> load;

  @override
  Widget build(BuildContext context) {
    final up = load.valueOrNull;
    final windowText = TaxiUpcomingWords.window(labelDays: up?.windowLabelDays);
    final children = <Widget>[];
    if (up == null) {
      if (load is OwnerLoadLoading<OwnerUpcoming>) {
        children.add(Column(children: [
          for (var i = 0; i < 3; i++) ...[SkeletonBox(height: DS.s(64), radius: DS.radius(16)), Gap.v(8)],
        ]));
      }
    } else {
      final rows = up.rows;
      final lock = up.beyondWindowAppCount > 0 && PlanGate.canUpgrade;
      final segments = rows.length + (lock ? 1 : 0);
      var k = 0;
      bool first() => k == 0;
      bool last() => k == segments - 1;
      for (final e in rows) {
        children.add(TaxiCardSegment(first: first(), last: last(), child: _row(e)));
        k++;
      }
      if (lock) {
        final d = up.window.upcomingTo ?? up.beyondWindowFirstDate;
        children.add(TaxiCardSegment(
          first: first(),
          last: last(),
          child: Padding(
            padding: DS.all(6),
            child: d == null
                ? const SizedBox.shrink()
                : SoftLock.row(text: TaxiCalendarStrings.afterWindow(d, up.beyondWindowAppCount, TaxiUpcomingWords.plusMonths), taxi: true),
          ),
        ));
        k++;
      }
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OwnerUpcomingHeading(
          title: TaxiCalendarStrings.upcomingBookings,
          sub: windowText,
          seeAll: TaxiCalendarStrings.seeAll,
          onSeeAll: () => Get.toNamed(AppRoutes.taxiUpcoming),
          linkColor: TaxiLook.accentText,
        ),
        Padding(
          padding: DS.sym(h: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ],
    );
  }

  Widget _row(CalendarEntry e) {
    final f = e.finalAmount;
    return TaxiTripRow(
      entry: e,
      line: TaxiTripText.upcomingLine(e),
      trailing: f == null ? null : TaxiAmount(amount: f),
      onTap: () => TaxiDriverDeps.openEntry(e.id),
    );
  }
}
