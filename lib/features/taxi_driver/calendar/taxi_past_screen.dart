import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../owner_core/home/owner_home_models.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../home/taxi_driver_home_controller.dart';
import '../strings/taxi_calendar_strings.dart';
import '../taxi_driver_deps.dart';
import 'taxi_bookings_tab.dart';
import 'taxi_calendar_controller.dart';
import 'taxi_calendar_widgets.dart';
import 'taxi_paged_sections.dart';
import 'taxi_trip_text.dart';

class TaxiPastScreen extends StatefulWidget {
  const TaxiPastScreen({super.key, this.args = const {}, this.controller, this.plate});

  final Map<String, dynamic> args;
  final TaxiCalendarController? controller;
  final String? plate;

  @override
  State<TaxiPastScreen> createState() => _TaxiPastScreenState();
}

class _TaxiPastScreenState extends State<TaxiPastScreen> {
  late final TaxiCalendarController _c;
  late final bool _owned;

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

  String? get _plate {
    if (widget.plate != null) return widget.plate;
    final home = TaxiDriverHomeController.maybe?.load.value;
    return home is OwnerLoadData<OwnerHomeDto> ? home.value.listing.plate : null;
  }

  @override
  Widget build(BuildContext context) {
    final today = _c.serverToday;
    return Scaffold(
      backgroundColor: TaxiCal.page,
      body: Column(
        children: [
          TaxiCalPageHeader(
            title: TaxiCalendarStrings.past3Months,
            subtitle: TaxiCalendarStrings.pastSub(_plate, OwnerDates.addDays(today, -91), OwnerDates.addDays(today, -1)),
          ),
          Expanded(
            child: TaxiPagedSections(
              saving: _c.saving,
              load: (cursor) => _c.past(cursor: cursor),
              byLastDay: true,
              sectionLabel: TaxiCalendarStrings.sectionMonthOnly,
              row: (context, e) => TaxiTripRow(
                entry: e,
                line: TaxiTripText.pastLine(e),
                trailing: TaxiChip(entry: e),
                onTap: () => TaxiDriverDeps.openEntry(e.id),
              ),
              footer: (context, hasMore) => hasMore ? const [] : const [TaxiFootLine(text: TaxiCalendarStrings.olderRemoved)],
            ),
          ),
          TaxiBottomActions(children: [
            PrimaryButton(label: TaxiCalendarStrings.viewCalendar, tone: TaxiCal.kit, onPressed: TaxiCalendarNav.viewCalendar),
          ]),
        ],
      ),
    );
  }
}
