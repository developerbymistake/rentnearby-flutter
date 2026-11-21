import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_page.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/home/owner_home_models.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/soft_lock.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../home/taxi_driver_home_controller.dart';
import '../strings/taxi_calendar_strings.dart';
import '../taxi_driver_deps.dart';
import 'taxi_bookings_tab.dart';
import 'taxi_calendar_controller.dart';
import 'taxi_calendar_widgets.dart';
import 'taxi_paged_sections.dart';
import 'taxi_trip_text.dart';
import 'taxi_upcoming_card.dart';

class TaxiUpcomingScreen extends StatefulWidget {
  const TaxiUpcomingScreen({super.key, this.args = const {}, this.controller, this.windowEnd});

  final Map<String, dynamic> args;
  final TaxiCalendarController? controller;
  final DateTime? windowEnd;

  @override
  State<TaxiUpcomingScreen> createState() => _TaxiUpcomingScreenState();
}

class _TaxiUpcomingScreenState extends State<TaxiUpcomingScreen> {
  late final TaxiCalendarController _c;
  late final bool _owned;
  int _beyond = 0;
  DateTime? _beyondDate;

  @override
  void initState() {
    super.initState();
    final given = widget.controller;
    _owned = given == null;
    _c = given ?? TaxiCalendarController.acquire();
  }

  @override
  void dispose() {
    if (_owned) TaxiCalendarController.release();
    super.dispose();
  }

  DateTime? get _windowEnd {
    final w = widget.windowEnd ?? _c.current?.window.upcomingTo;
    if (w != null) return w;
    final home = TaxiDriverHomeController.maybe?.load.value;
    return home is OwnerLoadData<OwnerHomeDto> ? home.value.upcoming.window.upcomingTo : null;
  }

  Future<OwnerResult<OwnerPage<CalendarEntry>>> _load(String? cursor) async {
    final r = await _c.upcoming(cursor: cursor);
    if (r is OwnerOk<UpcomingPage>) {
      final p = r.value;
      if (mounted) {
        setState(() {
          _beyond = p.beyondWindowAppCount;
          _beyondDate = p.beyondWindowFirstDate;
        });
      }
      return OwnerOk(OwnerPage(items: p.items, nextCursor: p.nextCursor));
    }
    return switch (r) {
      OwnerRefused() => r.cast<OwnerPage<CalendarEntry>>(),
      OwnerFailed(:final message) => OwnerFailed(message: message),
      _ => const OwnerOffline(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final window = TaxiUpcomingWords.window();
    final end = _windowEnd;
    return Scaffold(
      backgroundColor: TaxiCal.page,
      body: Column(
        children: [
          TaxiPageHeader(
            title: TaxiCalendarStrings.upcoming,
            subtitle: end == null ? window : TaxiCalendarStrings.until(window, end),
            plusPill: true,
          ),
          Expanded(
            child: TaxiPagedSections(
              load: _load,
              sectionLabel: TaxiCalendarStrings.sectionMonth,
              row: (context, e) => TaxiTripRow(
                entry: e,
                line: TaxiTripText.upcomingLine(e),
                trailing: TaxiChip(entry: e),
                onTap: () => TaxiDriverDeps.openEntry(e.id),
              ),
              footer: (context, hasMore) {
                final d = end ?? _beyondDate;
                if (hasMore || _beyond <= 0 || d == null || !PlanGate.canUpgrade) return const [];
                return [SoftLock.row(text: TaxiCalendarStrings.afterWindow(d, _beyond, TaxiUpcomingWords.plusMonths), taxi: true)];
              },
            ),
          ),
          TaxiBottomActions(children: [
            PrimaryButton(label: TaxiCalendarStrings.viewCalendar, tone: TaxiCal.kit, onPressed: TaxiCalendarNav.viewCalendar),
            SecondaryButton(label: TaxiCalendarStrings.addTrip, tone: TaxiCal.kit, onPressed: () => TaxiAddTrip.fromAnywhere(context)),
          ]),
        ],
      ),
    );
  }
}
