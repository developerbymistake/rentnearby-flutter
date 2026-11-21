import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_args.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/gate_keys.dart';
import '../../owner_core/sheets/owner_confirm.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../calendar/models/stay_calendar_models.dart';
import '../calendar/stay_entry_rows.dart';
import '../calendar/widgets/stay_calendar_widgets.dart';
import '../strings/stay_gate_strings_calendar.dart';
import '../strings/stay_special_price_strings.dart';
import '../widgets/stay_widgets.dart';
import 'stay_special_price_sheet.dart';
import 'stay_special_prices_controller.dart';

class StaySpecialPricesScreen extends StatefulWidget {
  const StaySpecialPricesScreen({super.key, this.args = const {}, this.controller});

  final Map<String, dynamic> args;
  final StaySpecialPricesController? controller;

  @override
  State<StaySpecialPricesScreen> createState() => _StaySpecialPricesScreenState();
}

class _StaySpecialPricesScreenState extends State<StaySpecialPricesScreen> {
  late final StaySpecialPricesController c;
  late final bool _owns;

  @override
  void initState() {
    super.initState();
    final given = widget.controller;
    _owns = given == null;
    c = given ?? Get.put(StaySpecialPricesController(), tag: StaySpecialPricesController.tag);
    c.fetch().then((_) => _prefill());
  }

  @override
  void dispose() {
    if (_owns && Get.isRegistered<StaySpecialPricesController>(tag: StaySpecialPricesController.tag)) {
      Get.delete<StaySpecialPricesController>(tag: StaySpecialPricesController.tag, force: true);
    }
    super.dispose();
  }

  Future<void> _prefill() async {
    if (!mounted || c.page == null) return;
    final from = OwnerDates.day(OwnerArgs.text(widget.args, 'dateFrom'));
    final to = OwnerDates.day(OwnerArgs.text(widget.args, 'dateTo')) ?? from;
    final festival = OwnerArgs.text(widget.args, 'festivalId');
    if (from == null && festival == null) return;
    if (from != null && to != null) {
      final exact = c.ruleFor(from, to);
      if (exact != null) {
        await StaySpecialPriceSheet.open(context, c, rule: exact);
        return;
      }
      if (festival != null && c.overlapping(from, to) != null) return;
    }
    if (!mounted) return;
    await StaySpecialPriceSheet.open(context, c, from: from, to: to, festivalId: festival);
  }

  Future<void> _add() => StaySpecialPriceSheet.open(context, c);

  Future<void> _delete(SpecialPriceBand r) async {
    final ok = await OwnerConfirm.ask(
      context,
      title: StaySpecialPriceStrings.deleteTitle,
      confirm: StaySpecialPriceStrings.delete,
      cancel: StaySpecialPriceStrings.cancel,
      destructive: true,
      tone: ListingTone.forest,
      art: ListingArt.diyaLamp,
    );
    if (!ok || !mounted) return;
    final res = await c.delete(r);
    if (res is! OwnerOk<void>) AppToast.error(OwnerSharedStrings.noConnection);
  }

  Future<void> _toggle(SpecialPriceBand r) async {
    final res = await c.toggle(r);
    if (!mounted || res is OwnerOk) return;
    if (res is OwnerRefused && res.type == 'SpecialPriceSavesLimit') {
      AppToast.info(StaySpecialPriceStrings.savesLimit);
    } else if (res is OwnerRefused && res.rateLimited) {
      AppToast.info(OwnerSharedStrings.tooManyTries);
    } else {
      AppToast.error(OwnerSharedStrings.noConnection);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OwnerLook.stay.page,
      body: Column(
        children: [
          StayCalHeader(
            title: StaySpecialPriceStrings.title,
            subtitle: StaySpecialPriceStrings.sub(c.listingName),
            trailing: c.plus ? const StayPlusTag() : null,
          ),
          Expanded(
            child: Obx(() {
              final load = c.load.value;
              c.busyIds.length;
              return OwnerStateView<StaySpecialPricesPage>(
                load: load,
                look: OwnerLook.stay,
                words: const OwnerStateWords(),
                onRetry: c.fetch,
                data: (context, page, stale) => _list(page, stale),
              );
            }),
          ),
          StayCalBar(primary: StaySpecialPriceStrings.addButton, onPrimary: _add),
        ],
      ),
    );
  }

  Widget _list(StaySpecialPricesPage page, bool stale) {
    final rules = page.items;
    final m = c.meter;
    return RefreshIndicator(
      onRefresh: c.fetch,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (stale) const SliverToBoxAdapter(child: OwnerStaleLine()),
          SliverToBoxAdapter(child: _tiles(page, m)),
          SliverList.builder(
            itemCount: rules.length,
            itemBuilder: (context, i) => _RuleCard(
              rule: rules[i],
              rooms: page.rooms,
              busy: c.busyIds.contains(rules[i].id),
              onToggle: () => _toggle(rules[i]),
              onEdit: () => StaySpecialPriceSheet.open(context, c, rule: rules[i]),
              onDelete: () => _delete(rules[i]),
            ),
          ),
          if (c.needsG12)
            SliverToBoxAdapter(
              child: Padding(
                padding: DS.insets(l: 18, t: 14, r: 18),
                child: StayLockedAddCard(onTap: () => PlanGate.showLimit(context, StayGateStringsCalendar.g12(endsOn: c.soonestEnd))),
              ),
            ),
          const SliverToBoxAdapter(child: StayNote(text: StaySpecialPriceStrings.shieldNote)),
          SliverToBoxAdapter(child: Gap.v(24)),
        ],
      ),
    );
  }

  Widget _tiles(StaySpecialPricesPage page, Meter? m) {
    final rooms = page.rooms.take(2).toList();
    Widget tile(String big, String small) => Container(
          padding: DS.sym(h: 12, v: 10),
          decoration: BoxDecoration(color: DesignColors.surface, borderRadius: StayLook.cardRadius(22), boxShadow: DS.shadows(ShadowTokens.elev1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(big, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w800, Ink3D.title, letterSpacing: 0)),
            Text(small, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
          ]),
        );
    final used = m?.used ?? page.items.length;
    final limit = m?.limit ?? 0;
    return Padding(
      padding: DS.insets(l: 18, t: 14, r: 18, b: 4),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: PlanGate.paymentOn && limit > 0
                ? tile(StaySpecialPriceStrings.meterCount(used, limit), StaySpecialPriceStrings.meterLabel(c.plus, limit))
                : tile('$used', StaySpecialPriceStrings.meterLabelOff),
          ),
          if (rooms.isNotEmpty) ...[
            Gap.h(10),
            Expanded(
              child: tile(
                StaySpecialPriceStrings.basePrices([for (final r in rooms) r.basePrice]),
                StaySpecialPriceStrings.basePricesLabel([for (final r in rooms) r.shortName]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule, required this.rooms, required this.busy, required this.onToggle, required this.onEdit, required this.onDelete});

  final SpecialPriceBand rule;
  final List<StayPriceRoom> rooms;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final r = rule;
    final name = r.label ?? StaySpecialPriceStrings.yourDates;
    final f = r.dateFrom ?? DateTime(2000);
    final t = r.dateTo ?? f;
    final known = r.direction != PriceDirection.unknown;
    final lower = r.direction == PriceDirection.lower;
    final range = StaySpecialPriceStrings.rangeTo(f, t);
    final priceLine = StayEntryRows.priceLine(r, rooms);
    final live = !r.isPaused && !r.pausedByPlan;
    final dim = r.isPaused || r.pausedByPlan;
    return Opacity(
      opacity: dim ? Alpha.v72 : Alpha.full,
      child: Container(
        margin: DS.insets(l: 18, t: 12, r: 18),
        padding: DS.all(14),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: StayLook.cardRadius(34), boxShadow: DS.shadows(ShadowTokens.elev1)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              ExcludeSemantics(child: Art3D(asset: StayCalArt.rule(r.label), size: 34)),
              Gap.h(10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                  Text(known ? StaySpecialPriceStrings.ruleLine(range, r.percent, lower) : range, style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                ]),
              ),
              if (known)
                StaySoftChip(
                  label: lower ? StaySpecialPriceStrings.lower : StaySpecialPriceStrings.higher,
                  bg: lower ? StayLook.greenSoft : StayLook.amberSoft,
                  fg: lower ? StayLook.greenText : StayLook.amberText,
                ),
            ]),
            if (priceLine.isNotEmpty) ...[
              Gap.v(10),
              Container(
                padding: DS.sym(h: 10, v: 8),
                decoration: BoxDecoration(color: DesignColors.surfaceAlt, borderRadius: DS.circular(10)),
                child: Text(priceLine, style: Ink3D.text(10.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
              ),
            ],
            Gap.v(8),
            Row(children: [
              Semantics(
                label: StaySpecialPriceStrings.a11ySwitch(name, live),
                toggled: live,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    r.pausedByPlan ? StaySpecialPriceStrings.pausedOnFree : (live ? StaySpecialPriceStrings.live : StaySpecialPriceStrings.paused),
                    style: Ink3D.text(11.5, FontWeight.w700, Ink3D.title, letterSpacing: 0),
                  ),
                  Gap.h(8),
                  Switch3D(tone: ListingTone.indigo, value: live, onChanged: busy ? null : (_) => onToggle()),
                ]),
              ),
              const Spacer(),
              Semantics(
                label: StaySpecialPriceStrings.a11yEdit(name),
                button: true,
                excludeSemantics: true,
                child: StayPill(label: StaySpecialPriceStrings.edit, kind: StayPillKind.outline, onTap: onEdit),
              ),
              Gap.h(6),
              Semantics(
                label: StaySpecialPriceStrings.a11yDelete(name),
                button: true,
                excludeSemantics: true,
                child: StayPill(label: StaySpecialPriceStrings.delete, kind: StayPillKind.danger, busy: busy, onTap: onDelete),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class StayLockedAddCard extends StatelessWidget {
  const StayLockedAddCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!PlanGate.canUpgrade) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: '${StaySpecialPriceStrings.addSpecialPrice}, ${StaySpecialPriceStrings.plusKeeps5}',
      child: InkWell(
        key: GateKeys.softRow,
        onTap: onTap,
        borderRadius: StayLook.cardRadius(34),
        child: Container(
          padding: DS.all(14),
          decoration: BoxDecoration(color: StayLook.lockedRow, borderRadius: StayLook.cardRadius(34), boxShadow: DS.shadows(ShadowTokens.elev1)),
          child: Row(children: [
            ExcludeSemantics(child: Art3D(asset: ListingArt.locked, size: 44)),
            Gap.h(12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(StaySpecialPriceStrings.addSpecialPrice, style: Ink3D.text(13.5, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                Text(StaySpecialPriceStrings.plusKeeps5, style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
              ]),
            ),
            KeyedSubtree(key: GateKeys.seePlus, child: StayPill(label: OwnerSharedStrings.seePlus, kind: StayPillKind.indigo, onTap: onTap)),
          ]),
        ),
      ),
    );
  }
}
