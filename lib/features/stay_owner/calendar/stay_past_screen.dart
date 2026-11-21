import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../owner_core/calendar/calendar_api.dart';
import '../../owner_core/data/owner_api.dart';
import '../../owner_core/data/owner_cache.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/look/owner_look.dart';
import '../strings/stay_calendar_strings.dart';
import 'stay_entry_rows.dart';
import 'stay_list_controller.dart';
import 'stay_upcoming_screen.dart';
import 'widgets/stay_calendar_widgets.dart';

class StayPastScreen extends StatefulWidget {
  const StayPastScreen({super.key, this.args = const {}, this.api, this.clock});

  final Map<String, dynamic> args;
  final CalendarApi? api;
  final DateTime Function()? clock;

  @override
  State<StayPastScreen> createState() => _StayPastScreenState();
}

class _StayPastScreenState extends State<StayPastScreen> {
  static const String tag = 'stay-past';
  late final StayListController c;

  DateTime get today => OwnerDates.only((widget.clock ?? DateTime.now)());

  @override
  void initState() {
    super.initState();
    final api = widget.api ?? const CalendarApi(CalendarApi.stayPrefix);
    c = Get.put(
      StayListController(
        loader: (cursor) => OwnerApi.get('${api.prefix}/past', (j) => j, params: {'cursor': cursor}),
        cacheKey: OwnerCacheKeys.calPast,
        userIdOf: stayUserId,
        newestFirst: true,
      ),
      tag: tag,
    );
    c.fetch();
  }

  @override
  void dispose() {
    if (Get.isRegistered<StayListController>(tag: tag)) Get.delete<StayListController>(tag: tag, force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = today;
    return Scaffold(
      backgroundColor: OwnerLook.stay.page,
      body: Column(
        children: [
          StayCalHeader(
            title: StayCalendarStrings.past3Months,
            subtitle: StayCalendarStrings.pastSub(stayListingName(), OwnerDates.addDays(t, -91), OwnerDates.addDays(t, -1)),
          ),
          Expanded(
            child: StayEntryListView(
              c: c,
              groupTitle: (h) => StayCalendarStrings.monthUpper(h.month),
              entryRow: (i) => StayEntryRows.past(i.entry),
              blockRow: (b) => StayEntryRows.block(b.block, past: true),
              footer: (_) => const [StaySmallLine(text: StayCalendarStrings.olderRemoved)],
            ),
          ),
          StayCalBar(primary: StayCalendarStrings.viewCalendar, onPrimary: () => Get.toNamed(AppRoutes.stayCalendar)),
        ],
      ),
    );
  }
}
