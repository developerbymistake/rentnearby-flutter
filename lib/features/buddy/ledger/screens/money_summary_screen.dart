import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/buddy_page.dart';
import '../../shared/widgets/money_hero.dart';
import '../../shared/widgets/note_banner.dart';
import '../../shared/widgets/small_pill.dart';
import '../controllers/money_summary_controller.dart';
import '../controllers/trip_balances_controller.dart';
import '../ledger_deps.dart';
import '../ledger_look.dart';
import '../ledger_strings.dart';
import '../models/ledger_models.dart';
import '../widgets/balances_view.dart';
import '../widgets/ledger_menu.dart';

class MoneySummaryScreen extends StatefulWidget {
  const MoneySummaryScreen({super.key, required this.tripId});

  final String tripId;

  static const Key settleKey = ValueKey('summary_settle_up');
  static const Key planKey = ValueKey('summary_plan_next');

  @override
  State<MoneySummaryScreen> createState() => _MoneySummaryScreenState();
}

class _MoneySummaryScreenState extends State<MoneySummaryScreen> {
  late final MoneySummaryController _c;

  @override
  void initState() {
    super.initState();
    final had = Get.isRegistered<MoneySummaryController>(tag: 'summary:${widget.tripId}');
    _c = MoneySummaryController.acquire(widget.tripId);
    if (had) _c.reload();
  }

  @override
  void dispose() {
    MoneySummaryController.release(widget.tripId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final s = _c.summary.value;
    return BuddyPage(
      title: LedgerStrings.summaryTitle,
      subtitle: s == null ? null : LedgerStrings.summaryLine(BuddyFormat.dateRange(s.startDate, s.endDate), s.dayCount, s.travellerCount),
      trailing: [
        LedgerMenu(
          items: [LedgerMenuItem(label: LedgerStrings.expensesTitle, art: LedgerLook.moneyBag, onTap: () => LedgerDeps.openExpenses(widget.tripId))],
        ),
      ],
      scroll: false,
      body: RefreshIndicator(
        color: BuddyLook.roseEnd,
        onRefresh: _c.reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: DS.s(24)),
          children: [_content(s)],
        ),
      ),
    );
  });

  Widget _content(ExpenseSummary? s) {
    switch (_c.status.value) {
      case LedgerLoad.gone:
        return LedgerStateCard.gone();
      case LedgerLoad.failed:
        return LedgerStateCard.failed(_c.reload);
      default:
        break;
    }
    if (s == null) return const LedgerLoadingBox();
    return MoneySummaryBody(tripId: widget.tripId, summary: s);
  }
}

class MoneySummaryBody extends StatelessWidget {
  const MoneySummaryBody({super.key, required this.tripId, required this.summary});

  final String tripId;
  final ExpenseSummary summary;

  static BorderRadius get _cardRadius => DS.br(
    CardRadius.tile,
  );

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final cells = [for (final p in s.perPerson) (BuddyFormat.rupees(p.share), p.person.isDeleted ? BuddyFormat.deletedName : p.person.name)];
    final first = cells.take(3).toList();
    final rest = cells.skip(3).toList();
    final cats = [...s.byCategory.where((c) => c.amount > 0)]..sort((a, b) => b.amount.compareTo(a.amount));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _top(s),
        MoneyHero(label: LedgerStrings.totalSpent, amount: BuddyFormat.rupees(s.total), cells: first, footer: rest.isEmpty ? null : _moreCells(rest)),
        if (cats.isNotEmpty) _categories(cats),
        Tap3D(
          tapKey: MoneySummaryScreen.planKey,
          onTap: () => LedgerDeps.openPlanATrip(),
          label: LedgerStrings.planNext,
          exclude: true,
          child: const NoteBanner(art: LedgerLook.luggage, text: LedgerStrings.planNext),
        ),
      ],
    );
  }

  Widget _top(ExpenseSummary s) {
    final settled = s.settled && s.openPayments == 0;
    return Padding(
      padding: DS.insets(l: 24, t: 22, r: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Art3D(asset: LedgerLook.flag, size: 92, shadowBlur: 7, shadowOffset: Offset(6, 9)),
          Gap.v(8),
          Text(
            settled ? LedgerStrings.allSettled : LedgerStrings.paymentsOpen(s.openPayments),
            textAlign: TextAlign.center,
            style: Ink3D.text(24, FontWeight.w700, Ink3D.title, letterSpacing: 0),
          ),
          Gap.v(2),
          if (settled)
            Text(LedgerStrings.noPaymentsLeft, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w400, LedgerLook.heroSub, letterSpacing: 0))
          else
            Padding(
              padding: EdgeInsets.only(top: DS.s(8)),
              child: IntrinsicWidth(
                child: SmallPill(
                  key: MoneySummaryScreen.settleKey,
                  label: LedgerStrings.settleUpTitle,
                  kind: SmallPillKind.rose,
                  onTap: () => LedgerDeps.openSettleUp(tripId),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _moreCells(List<(String, String)> rest) {
    final rows = <List<(String, String)>>[];
    for (var i = 0; i < rest.length; i += 3) {
      rows.add(rest.sublist(i, i + 3 > rest.length ? rest.length : i + 3));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) Gap.v(10),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[if (i > 0) Gap.h(10), Expanded(child: i < rows[r].length ? _cell(rows[r][i]) : const SizedBox.shrink())],
            ],
          ),
        ],
      ],
    );
  }

  static Widget _cell((String, String) c) => Container(
    padding: DS.sym(h: 12, v: 8),
    decoration: BoxDecoration(color: DesignColors.surface, borderRadius: MoneyHero.cellRadius),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(c.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w700, BuddyLook.roseEnd, letterSpacing: 0)),
        Text(c.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w600, BuddyLook.subText, letterSpacing: 0)),
      ],
    ),
  );

  Widget _categories(List<CategoryTotal> cats) {
    final top = cats.first.amount;
    final rowStyle = Ink3D.text(13, FontWeight.w600, Ink3D.title, letterSpacing: 0);
    return Container(
      margin: DS.insets(l: 18, t: 16, r: 18),
      padding: DS.sym(h: 16, v: 14),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: _cardRadius, boxShadow: BuddyLook.cardShadows(DS.size)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: DS.s(4)),
            child: Text(LedgerStrings.byCategory, style: Ink3D.text(15, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
          ),
          for (final c in cats)
            Padding(
              padding: DS.sym(v: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: DS.s(64),
                    child: Text(c.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: rowStyle),
                  ),
                  Gap.h(10),
                  Expanded(child: _bar(c.amount / top, LedgerLook.barOf(c.category))),
                  Gap.h(10),
                  SizedBox(
                    width: DS.s(70),
                    child: Text(
                      BuddyFormat.rupees(c.amount),
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: rowStyle.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static Widget _bar(double fraction, List<Color> colors) => ClipRRect(
    borderRadius: DS.circular(4),
    child: Container(
      height: DS.s(8),
      color: LedgerLook.barTrack,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction.clamp(0.0, 1.0),
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: DS.circular(4),
          ),
        ),
      ),
    ),
  );
}
