import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../../utils/money_format.dart';
import '../../owner_core/calendar/month_grid.dart';
import '../../owner_core/calendar/month_pager.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_args.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/money/money_summary_card.dart';
import '../../owner_core/plan/gate_keys.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../stay_owner_deps.dart';
import '../strings/stay_calendar_strings.dart';
import '../strings/stay_special_price_strings.dart';
import '../widgets/stay_widgets.dart';
import 'stay_calendar_controller.dart';
import 'stay_day_sheet.dart';
import 'stay_entry_sheet.dart';
import 'stay_entry_rows.dart';
import 'widgets/stay_calendar_widgets.dart';

class StayCalendarScreen extends StatefulWidget {
  const StayCalendarScreen({super.key, this.args = const {}, this.controller});

  final Map<String, dynamic> args;
  final StayCalendarController? controller;

  @override
  State<StayCalendarScreen> createState() => _StayCalendarScreenState();
}

class _StayCalendarScreenState extends State<StayCalendarScreen> {
  late final StayCalendarController c;
  late final bool _owns;
  final GlobalKey _summaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final given = widget.controller;
    _owns = given == null;
    c = given ?? Get.put(StayCalendarController(), tag: StayCalendarController.tag);
    final date = OwnerDates.day(OwnerArgs.text(widget.args, 'date')) ?? OwnerDates.month(OwnerArgs.text(widget.args, 'month'));
    c.start(date: date).then((_) {
      if (!mounted) return;
      if (OwnerArgs.flag(widget.args, 'add')) _add();
      if (OwnerArgs.flag(widget.args, 'summary')) _scrollToSummary();
    });
  }

  @override
  void dispose() {
    if (_owns && Get.isRegistered<StayCalendarController>(tag: StayCalendarController.tag)) {
      Get.delete<StayCalendarController>(tag: StayCalendarController.tag, force: true);
    }
    super.dispose();
  }

  void _scrollToSummary() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _summaryKey.currentContext;
      if (ctx != null && ctx.mounted) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250));
    });
  }

  void _add({DateTime? from, DateTime? to}) => StayEntrySheet.add(context, c, from: from, to: to);

  void _block({DateTime? day}) => StayEntrySheet.block(context, c, day: day);

  void _day(DateTime day) => StayDaySheet.show(context, c, day, onAdd: (d) => _add(from: d, to: OwnerDates.addDays(d, 1)), onBlock: (d) => _block(day: d));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OwnerLook.stay.page,
      body: Column(
        children: [
          Obx(() {
            c.load.value;
            final name = c.listingName;
            final free = c.afterPlusSections && c.freeLook;
            return StayCalHeader(
              title: StayCalendarStrings.calendar,
              subtitle: free ? '$name${StayCalendarStrings.freeSuffix}' : name,
              trailing: StayHeaderPills(plus: c.plusPill, onPast: () => Get.toNamed(AppRoutes.stayPast)),
            );
          }),
          Expanded(
            child: Obx(() {
              final load = c.load.value;
              return OwnerStateView<CalendarMonth>(
                load: load,
                look: OwnerLook.stay,
                words: const OwnerStateWords(),
                onRetry: c.reload,
                skeleton: const _GridSkeleton(),
                data: (context, value, stale) => _Body(c: c, stale: stale, summaryKey: _summaryKey, onDay: _day),
              );
            }),
          ),
          StayCalBar(
            primary: StayCalendarStrings.addBooking,
            secondary: StayCalendarStrings.blockDays,
            onPrimary: () => _add(),
            onSecondary: () => _block(),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.c, required this.stale, required this.summaryKey, required this.onDay});

  final StayCalendarController c;
  final bool stale;
  final GlobalKey summaryKey;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) => Obx(() {
        c.load.value;
        c.monthRows.length;
        c.ownActive.length;
        c.activeBlocks.length;
        c.priceRules.length;
        return _scroll(context);
      });

  Widget _scroll(BuildContext context) {
    return RefreshIndicator(
      onRefresh: c.reload,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (stale) const SliverToBoxAdapter(child: OwnerStaleLine()),
          SliverToBoxAdapter(child: Obx(() => c.staleLine.value ? const OwnerStaleLine(text: OwnerSharedStrings.staleEdit) : const SizedBox.shrink())),
          SliverToBoxAdapter(child: _MonthPart(c: c, onDay: onDay)),
          SliverToBoxAdapter(child: _FestivalRow(c: c)),
          if (!c.afterPlusSections) ...[
            SliverToBoxAdapter(child: StayMeterTiles(entries: c.meter(StayMeterKeys.entries), blocks: c.meter(StayMeterKeys.blocks))),
            SliverToBoxAdapter(child: KeyedSubtree(key: summaryKey, child: _Summary(c: c))),
            SliverToBoxAdapter(child: Padding(padding: DS.insets(t: 10), child: StayOwnerDeps.reminderRow())),
            if (c.freeLook)
              SliverToBoxAdapter(
                child: StayAmberRow(text: StayCalendarStrings.freeWindowLine, margin: DS.insets(l: 18, t: 14, r: 18)),
              ),
            const SliverToBoxAdapter(child: StaySmallLine(text: StayCalendarStrings.tapHint)),
          ],
          ..._monthList(context),
          if (c.afterPlusSections) ..._afterPlus(context),
          SliverToBoxAdapter(child: Gap.v(24)),
        ],
      ),
    );
  }

  List<Widget> _monthList(BuildContext context) {
    final rows = c.monthRows;
    if (rows.isEmpty || c.afterPlusSections) return const [];
    return [
      SliverToBoxAdapter(
        child: StaySectionHeaderRow(
          title: StayCalendarStrings.bookingsThisMonth,
          meter: c.summaryOpen ? '${rows.length}' : StayCalendarStrings.amountsStayFree,
        ),
      ),
      SliverList.builder(
        itemCount: rows.length,
        itemBuilder: (context, i) => StayCardSegment(
          first: i == 0,
          last: i == rows.length - 1,
          child: StayEntryRows.month(rows[i]),
        ),
      ),
      if (!c.summaryOpen) const SliverToBoxAdapter(child: StaySmallLine(text: StayCalendarStrings.freeEachBookingNote)),
    ];
  }

  List<Widget> _afterPlus(BuildContext context) {
    final d = c.data;
    if (d == null) return const [];
    final own = c.ownActive;
    final blocks = c.activeBlocks;
    final rules = c.priceRules;
    final limit = c.meter(StayMeterKeys.entries)?.limit ?? own.length;
    final live = rules.where((r) => r.live || r.active).length;
    return [
      SliverToBoxAdapter(child: StaySectionHeaderRow(title: StayCalendarStrings.hiddenEntriesTitle, meter: StayCalendarStrings.shownCount(own.length, limit))),
      SliverList.builder(
        itemCount: own.length,
        itemBuilder: (context, i) => StayCardSegment(first: i == 0, last: i == own.length - 1 && d.hiddenCount == 0, child: StayEntryRows.own(own[i])),
      ),
      if (d.hiddenCount > 0)
        SliverToBoxAdapter(
          child: StayCardSegment(
            first: own.isEmpty,
            last: true,
            child: Padding(padding: DS.all(8), child: StayAmberRow(text: StayCalendarStrings.hiddenMore(d.hiddenCount), onSeePlus: PlanGate.seePlus)),
          ),
        ),
      if (blocks.isNotEmpty) ...[
        SliverToBoxAdapter(child: StaySectionHeaderRow(title: StayCalendarStrings.blockedDays, meter: StayCalendarStrings.stillBlocking(blocks.length))),
        SliverList.builder(
          itemCount: blocks.length,
          itemBuilder: (context, i) => StayCardSegment(first: i == 0, last: i == blocks.length - 1, child: StayEntryRows.blockPlain(blocks[i])),
        ),
      ],
      if (rules.isNotEmpty) ...[
        SliverToBoxAdapter(child: StaySectionHeaderRow(title: StayCalendarStrings.specialPrices, meter: StayCalendarStrings.liveCount(live))),
        SliverList.builder(
          itemCount: rules.length,
          itemBuilder: (context, i) => StayCardSegment(first: i == 0, last: i == rules.length - 1, child: StayEntryRows.rule(rules[i])),
        ),
      ],
      const SliverToBoxAdapter(child: StayNote(text: StayCalendarStrings.afterPlusNote)),
    ];
  }
}

class StaySectionHeaderRow extends StatelessWidget {
  const StaySectionHeaderRow({super.key, required this.title, this.meter});

  final String title;
  final String? meter;

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.insets(l: 22, t: 22, r: 22, b: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(child: Text(title, style: Ink3D.text(16, FontWeight.w700, Ink3D.title, letterSpacing: 0))),
            if (meter != null) ...[
              Gap.h(8),
              Flexible(child: Text(meter!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w500, Ink3D.grey, letterSpacing: 0))),
            ],
          ],
        ),
      );
}

class _MonthPart extends StatelessWidget {
  const _MonthPart({required this.c, required this.onDay});

  final StayCalendarController c;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final m = c.month.value;
      final window = c.window;
      final cells = c.grid.toList();
      final selected = c.selectedDay.value;
      return Padding(
        padding: DS.insets(l: 14, t: 12, r: 14),
        child: Column(
          children: [
            StayMonthChips(month: m, window: window, today: c.today, onMonth: c.goTo),
            MonthPager(month: m, window: window, today: c.today, onMonth: c.goTo, onLockedNext: PlanGate.seePlus),
            MonthGrid(
              cells: cells,
              weekdays: StayCalendarStrings.weekdays,
              selected: selected,
              onTap: (cell) {
                c.selectDay(cell.date);
                onDay(cell.date);
              },
            ),
            Gap.v(12),
            const _Legend(),
          ],
        ),
      );
    });
  }
}

class StayMonthChips extends StatelessWidget {
  const StayMonthChips({super.key, required this.month, required this.window, required this.today, required this.onMonth});

  final DateTime month;
  final CalendarWindow window;
  final DateTime today;
  final ValueChanged<DateTime> onMonth;

  @override
  Widget build(BuildContext context) {
    final months = window.months(today);
    if (months.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: DS.s(48),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: months.length,
        itemBuilder: (context, i) {
          final m = months[i];
          final on = m.year == month.year && m.month == month.month;
          final label = OwnerSharedStrings.monthsShort[m.month - 1];
          return Padding(
            padding: EdgeInsets.only(right: DS.gh(6)),
            child: Semantics(
              button: true,
              selected: on,
              label: OwnerSharedStrings.monthTitle(m),
              excludeSemantics: true,
              child: InkWell(
                borderRadius: DS.circular(18),
                onTap: on ? null : () => onMonth(m),
                child: Container(
                  alignment: Alignment.center,
                  margin: DS.sym(v: 6),
                  padding: DS.sym(h: 14),
                  decoration: BoxDecoration(
                    color: on ? null : DesignColors.surface,
                    gradient: on ? ListingTone.indigo.gradient : null,
                    borderRadius: DS.circular(18),
                    boxShadow: DS.shadows(ShadowTokens.elev1),
                  ),
                  child: Text(label, style: Ink3D.text(11.5, FontWeight.w700, on ? DesignColors.onPrimary : Ink3D.title, letterSpacing: 0)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label, {bool bar = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: DS.s(bar ? 12 : 6),
              height: DS.s(bar ? 4 : 6),
              decoration: BoxDecoration(color: color, borderRadius: DS.circular(3)),
            ),
            Gap.h(5),
            Text(label, style: Ink3D.text(10.5, FontWeight.w600, Ink3D.sub, letterSpacing: 0)),
          ],
        );
    return Wrap(
      spacing: DS.gh(14),
      runSpacing: DS.gv(6),
      children: [
        item(OwnerLook.appDot, StayCalendarStrings.legendFromApp),
        item(OwnerLook.ownDot, StayCalendarStrings.legendAddedByYou),
        item(OwnerLook.blockedDot, StayCalendarStrings.legendBlocked),
        item(OwnerLook.specialBand, StayCalendarStrings.legendSpecial, bar: true),
      ],
    );
  }
}

class _FestivalRow extends StatelessWidget {
  const _FestivalRow({required this.c});

  final StayCalendarController c;

  @override
  Widget build(BuildContext context) {
    final rule = c.monthRule;
    final from = rule?.dateFrom;
    final to = rule?.dateTo;
    if (rule == null || from == null || to == null) return const SizedBox.shrink();
    final lower = rule.direction == PriceDirection.lower;
    final ended = to.isBefore(c.today);
    final label = rule.label ?? StayCalendarStrings.yourDates;
    final festival = c.festivalOn(from);
    final art = festival != null && festival.name.toLowerCase().contains('diwali') || label.toLowerCase().contains('diwali') ? ListingArt.diyaLamp : ListingArt.star;
    return Container(
      margin: DS.insets(l: 18, t: 14, r: 18),
      padding: DS.sym(h: 12, v: 10),
      decoration: BoxDecoration(
        color: StayLook.amberSoft,
        borderRadius: DS.circular(14),
        border: Border.all(color: OwnerLook.amberSoft, width: DS.s(1)),
      ),
      child: Row(
        children: [
          ExcludeSemantics(child: Art3D(asset: art, size: 30)),
          Gap.h(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(StayCalendarStrings.festivalRowTitle(label, from, to), style: Ink3D.text(12, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                Text(
                  ended ? StayCalendarStrings.festivalWas(rule.percent, lower) : StayCalendarStrings.festivalNow(rule.percent, lower),
                  style: Ink3D.text(10.5, FontWeight.w500, StayLook.amberText, letterSpacing: 0),
                ),
              ],
            ),
          ),
          if (!ended) ...[
            Gap.h(8),
            Semantics(
              label: StaySpecialPriceStrings.a11yEdit(label),
              button: true,
              excludeSemantics: true,
              child: StayPill(
                label: StayCalendarStrings.edit,
                kind: StayPillKind.outline,
                onTap: () => StayOwnerDeps.openSpecialPrice(dateFrom: OwnerDates.dayText(from), dateTo: OwnerDates.dayText(to)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.c});

  final StayCalendarController c;

  static const words = MoneySummaryWords(
    title: StayCalendarStrings.thisMonth,
    sub: StayCalendarStrings.summaryLockedSub,
    booked: StayCalendarStrings.booked,
    received: StayCalendarStrings.received,
    toCollect: StayCalendarStrings.toCollect,
    lockedLine: StayCalendarStrings.summaryLockedLine,
    hiddenAmount: StayCalendarStrings.hiddenAmount,
  );

  @override
  Widget build(BuildContext context) {
    if (!c.summaryOpen) {
      return Padding(
        padding: DS.insets(l: 18, t: 14, r: 18),
        child: PlanGate.canUpgrade ? const StayLockedSummary() : MoneySummaryCard(words: words, look: OwnerLook.stay, allowed: true),
      );
    }
    return Obx(() {
      final load = c.summary.value;
      final m = c.month.value;
      return Padding(
        padding: DS.insets(l: 18, t: 14, r: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StayOpenSummary(
              month: m,
              load: load,
              plus: c.plusPill,
              onRetry: c.loadSummary,
            ),
            if (c.plusPill) StaySmallLine(text: StayCalendarStrings.plusWindowFooter, margin: DS.insets(t: 8)),
          ],
        ),
      );
    });
  }
}

class StayOpenSummary extends StatelessWidget {
  const StayOpenSummary({super.key, required this.month, required this.load, required this.plus, this.onRetry, this.showTop = true});

  final DateTime month;
  final OwnerLoad<MoneySummary> load;
  final bool plus;
  final VoidCallback? onRetry;
  final bool showTop;

  void _open() => Get.toNamed(AppRoutes.stayBalanceDue, arguments: {'month': OwnerDates.monthKey(month)});

  @override
  Widget build(BuildContext context) {
    final s = load.valueOrNull;
    final failed = load is OwnerLoadError<MoneySummary> || load is OwnerLoadOffline<MoneySummary>;
    final top = s?.top ?? const <CalendarEntry>[];
    final due = s?.dueCount ?? 0;
    return Container(
      padding: DS.all(14),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: StayLook.cardRadius(34), boxShadow: DS.shadows(ShadowTokens.elev1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(child: Art3D(asset: ListingArt.moneyBag, size: 32)),
              Gap.h(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(StayCalendarStrings.thisMonth, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                    Text(StayCalendarStrings.summaryOpenSub(month), style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                  ],
                ),
              ),
              if (plus) const StayPlusTag(),
            ],
          ),
          Gap.v(12),
          if (failed && s == null)
            StateCard.error(title: OwnerSharedStrings.couldNotLoad, kit: StayCalKit.green, actionLabel: OwnerSharedStrings.tryAgain, onAction: onRetry)
          else
            StayMoneyTiles(summary: s, onCollect: _open),
          if (showTop && top.isNotEmpty) ...[
            Gap.v(8),
            for (var i = 0; i < top.length && i < 3; i++) StayEntryRows.due(top[i], divider: true),
            Gap.v(10),
            StayPill(label: StayCalendarStrings.balanceDueButton(due), kind: StayPillKind.outline, expand: true, onTap: _open),
            Gap.v(8),
            Text(StayCalendarStrings.summaryOpenNote, style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, height: 1.4, letterSpacing: 0)),
          ],
        ],
      ),
    );
  }
}

class StayMoneyTiles extends StatelessWidget {
  const StayMoneyTiles({super.key, required this.summary, this.onCollect});

  final MoneySummary? summary;
  final VoidCallback? onCollect;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    Widget tile(String label, int? value, {bool amber = false, VoidCallback? onTap}) {
      final box = Container(
        padding: DS.sym(h: 10, v: 9),
        decoration: BoxDecoration(
          color: amber ? StayLook.amberSoft : DesignColors.surfaceAlt,
          borderRadius: DS.circular(10),
          border: amber ? Border.all(color: OwnerLook.amber.withValues(alpha: Alpha.v55), width: DS.s(1)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(10, FontWeight.w600, amber ? StayLook.amberText : Ink3D.grey, letterSpacing: 0)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: value == null
                  ? SkeletonBox(width: DS.s(56), height: DS.s(16), radius: DS.radius(6))
                  : Text(Money.exact(value), maxLines: 1, style: Ink3D.text(15, FontWeight.w800, amber ? StayLook.amberText : Ink3D.title, letterSpacing: 0)),
            ),
          ],
        ),
      );
      if (onTap == null) return box;
      return Semantics(button: true, child: InkWell(borderRadius: DS.circular(10), onTap: onTap, child: box));
    }

    return Row(
      children: [
        Expanded(child: tile(StayCalendarStrings.booked, s?.booked)),
        Gap.h(6),
        Expanded(child: tile(StayCalendarStrings.received, s?.received)),
        Gap.h(6),
        Expanded(child: tile(onCollect == null ? StayCalendarStrings.toCollect : StayCalendarStrings.toCollectOpen, s?.toCollect, amber: true, onTap: onCollect)),
      ],
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.insets(l: 14, t: 18, r: 14),
        child: Column(
          children: [
            SkeletonBox(height: DS.s(28), radius: DS.radius(10)),
            Gap.v(12),
            for (var r = 0; r < 6; r++)
              Padding(
                padding: EdgeInsets.only(bottom: DS.gv(6)),
                child: Row(
                  children: [
                    for (var i = 0; i < 7; i++) ...[if (i > 0) Gap.h(6), Expanded(child: SkeletonBox(height: DS.s(40), radius: DS.radius(12)))],
                  ],
                ),
              ),
          ],
        ),
      );
}

class StayLockedSummary extends StatelessWidget {
  const StayLockedSummary({super.key});

  @override
  Widget build(BuildContext context) {
    Widget tile(String label) => Expanded(
          child: Container(
            padding: DS.sym(h: 10, v: 9),
            decoration: BoxDecoration(color: DesignColors.surfaceAlt, borderRadius: DS.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, maxLines: 1, style: Ink3D.text(10, FontWeight.w600, Ink3D.grey, letterSpacing: 0)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(StayCalendarStrings.hiddenAmount, maxLines: 1, style: Ink3D.text(13, FontWeight.w700, Ink3D.hint, letterSpacing: 0)),
              ),
            ]),
          ),
        );
    return Container(
      key: GateKeys.softCard,
      padding: DS.all(14),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: StayLook.cardRadius(34), boxShadow: DS.shadows(ShadowTokens.elev1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          ExcludeSemantics(child: Art3D(asset: ListingArt.moneyBag, size: 34)),
          Gap.h(10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(StayCalendarStrings.thisMonth, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
              Text(StayCalendarStrings.summaryLockedSub, style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
            ]),
          ),
          Gap.h(8),
          KeyedSubtree(key: GateKeys.seePlus, child: StayPill(label: OwnerSharedStrings.seePlus, kind: StayPillKind.indigo, onTap: PlanGate.seePlus)),
        ]),
        Gap.v(12),
        Row(children: [
          tile(StayCalendarStrings.booked),
          Gap.h(6),
          tile(StayCalendarStrings.received),
          Gap.h(6),
          tile(StayCalendarStrings.toCollect),
        ]),
        Gap.v(10),
        Text(StayCalendarStrings.summaryLockedLine, style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, height: 1.4, letterSpacing: 0)),
      ]),
    );
  }
}
