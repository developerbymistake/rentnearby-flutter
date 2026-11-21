import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../design/design.dart';
import '../../owner_core/calendar/calendar_api.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_api.dart';
import '../../owner_core/data/owner_cache.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/json/owner_json.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../home/stay_owner_home_controller.dart';
import '../strings/stay_calendar_strings.dart';
import '../widgets/stay_widgets.dart';
import 'data/stay_calendar_apis.dart';
import 'models/stay_calendar_models.dart';
import 'stay_entry_rows.dart';
import 'stay_list_controller.dart';
import 'widgets/stay_calendar_widgets.dart';

String? stayUserId() => Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null;

String stayListingName() => StayOwnerHomeController.maybe?.data?.listing.name ?? '';

class StayEntryListView extends StatelessWidget {
  const StayEntryListView({
    super.key,
    required this.c,
    required this.entryRow,
    this.blockRow,
    this.header,
    this.footer,
    this.groupTitle,
    this.empty,
  });

  final StayListController c;
  final Widget Function(StayListEntry item) entryRow;
  final Widget Function(StayListBlock item)? blockRow;
  final List<Widget> Function(List<StayListItem> items)? header;
  final List<Widget> Function(List<StayListItem> items)? footer;
  final String Function(StayListHeader h)? groupTitle;
  final Widget? empty;

  @override
  Widget build(BuildContext context) => Obx(() {
        final load = c.load.value;
        c.loadingMore.value;
        return OwnerStateView<List<StayListItem>>(
          load: load,
          look: OwnerLook.stay,
          words: const OwnerStateWords(),
          onRetry: c.fetch,
          data: (context, items, stale) {
            final top = header?.call(items) ?? const <Widget>[];
            final bottom = footer?.call(items) ?? const <Widget>[];
            return RefreshIndicator(
              onRefresh: c.fetch,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (stale) const SliverToBoxAdapter(child: OwnerStaleLine()),
                  for (final w in top) SliverToBoxAdapter(child: w),
                  if (items.isEmpty && empty != null) SliverToBoxAdapter(child: empty),
                  SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) => switch (items[i]) {
                      StayListHeader h => StayGroupHeader(title: groupTitle?.call(h) ?? StayCalendarStrings.monthYearUpper(h.month), count: h.count),
                      StayListEntry e => StayCardSegment(first: e.first, last: e.last, child: entryRow(e)),
                      StayListBlock b => StayCardSegment(first: b.first, last: b.last, child: blockRow?.call(b) ?? StayEntryRows.block(b.block)),
                    },
                  ),
                  if (c.hasMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: DS.insets(l: 18, t: 14, r: 18),
                        child: c.loadingMore.value
                            ? const Center(child: CircularProgressIndicator())
                            : StayPill(label: StayCalendarStrings.showMore, kind: StayPillKind.outline, expand: true, onTap: c.more),
                      ),
                    ),
                  for (final w in bottom) SliverToBoxAdapter(child: w),
                  SliverToBoxAdapter(child: Gap.v(24)),
                ],
              ),
            );
          },
        );
      });
}

class StayUpcomingMeta {
  int hiddenCount = 0;
  int beyondWindowAppCount = 0;
  DateTime? beyondWindowFirstDate;

  void read(Map<String, dynamic> raw) {
    hiddenCount = OwnerJson.integer(raw['hiddenCount']);
    beyondWindowAppCount = OwnerJson.integer(raw['beyondWindowAppCount']);
    beyondWindowFirstDate = OwnerDates.day(raw['beyondWindowFirstDate']);
  }
}

class StayUpcomingScreen extends StatefulWidget {
  const StayUpcomingScreen({super.key, this.args = const {}, this.api, this.blockApi, this.clock});

  final Map<String, dynamic> args;
  final CalendarApi? api;
  final StayBlockApi? blockApi;
  final DateTime Function()? clock;

  @override
  State<StayUpcomingScreen> createState() => _StayUpcomingScreenState();
}

class _StayUpcomingScreenState extends State<StayUpcomingScreen> {
  static const String tag = 'stay-upcoming';
  late final StayListController c;
  final meta = StayUpcomingMeta();

  DateTime get today => OwnerDates.only((widget.clock ?? DateTime.now)());

  @override
  void initState() {
    super.initState();
    final api = widget.api ?? const CalendarApi(CalendarApi.stayPrefix);
    final blocks = widget.blockApi ?? const StayBlockApi();
    c = Get.put(
      StayListController(
        loader: (cursor) => OwnerApi.get('${api.prefix}/upcoming', (j) => j, params: {'cursor': cursor}),
        cacheKey: OwnerCacheKeys.calUpcoming,
        userIdOf: stayUserId,
        blocksLoader: () async {
          final r = await blocks.list();
          return r is OwnerOk<StayBlockList> ? r.value.items : const <CalendarBlock>[];
        },
        onFirstPage: meta.read,
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
    final days = PlanGate.limit(PlanKey.upcomingDays);
    final until = OwnerDates.addDays(today, days <= 0 ? 15 : days);
    final six = days >= 180;
    final sub = six ? StayCalendarStrings.next6MonthsUntil(until) : StayCalendarStrings.nextDaysUntil(days <= 0 ? 15 : days, until);
    final plus = PlanGate.paymentOn && !PlanGate.canUpgrade;
    return Scaffold(
      backgroundColor: OwnerLook.stay.page,
      body: Column(
        children: [
          StayCalHeader(title: StayCalendarStrings.upcoming, subtitle: sub, trailing: plus ? const StayPlusTag() : null),
          Expanded(
            child: StayEntryListView(
              c: c,
              entryRow: (i) => StayEntryRows.upcoming(i.entry),
              footer: (items) => [
                if (c.items.any((e) => e.cancelled)) const StayNote(art: ListingArt.calendar, text: StayCalendarStrings.movedNote),
                if (!six && PlanGate.canUpgrade && meta.beyondWindowAppCount > 0)
                  StayAmberRow(
                    text: StayCalendarStrings.beyondWindow(until, meta.beyondWindowAppCount),
                    margin: DS.insets(l: 18, t: 14, r: 18),
                  ),
              ],
            ),
          ),
          StayCalBar(
            primary: StayCalendarStrings.viewCalendar,
            secondary: StayCalendarStrings.addBooking,
            onPrimary: () => Get.toNamed(AppRoutes.stayCalendar),
            onSecondary: () => Get.toNamed(AppRoutes.stayCalendar, arguments: const {'add': true}),
          ),
        ],
      ),
    );
  }
}

