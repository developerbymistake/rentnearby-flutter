import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../trip/widgets/trip_plan_header.dart';
import '../../ledger/widgets/balances_view.dart';
import '../../ledger/widgets/expense_state_banner.dart';
import '../../ledger/widgets/viewer_money_card.dart';
import '../../offline/queue_rules.dart';
import '../../offline/widgets/expense_sync_banner.dart';
import '../../offline/widgets/pending_row_extras.dart';
import '../../shared/buddy_look.dart';
import '../../shared/strings_shared.dart';
import '../../shared/widgets/buddy_bottom_bar.dart';
import '../../shared/widgets/buddy_page.dart';
import '../../shared/widgets/buddy_snack.dart';
import '../../shared/widgets/segment_tabs.dart';
import '../../shared/widgets/small_pill.dart';
import '../../shared/widgets/view_only_chip.dart';
import '../controllers/expense_sheet_controller.dart';
import '../controllers/share_earlier_controller.dart';
import '../controllers/trip_expenses_controller.dart';
import '../data/expense_write_gateway.dart';
import '../expense_deps.dart';
import '../expense_look.dart';
import '../expense_strings.dart';
import '../models/expense_models.dart';
import '../widgets/expense_day_list.dart';
import '../widgets/expense_owner_hero.dart';
import '../widgets/expense_sheet.dart';
import '../widgets/expense_suggestion_card.dart';
import '../widgets/late_joiner_sheet.dart';
import '../widgets/share_earlier_sheet.dart';

class TripExpensesScreen extends StatefulWidget {
  const TripExpensesScreen({super.key, required this.tripId, this.tab, this.day, this.add = false, this.initial});

  static const Key addKey = ValueKey('expenses_add');
  static const Key menuKey = ValueKey('expenses_menu');
  static const Key retryKey = ValueKey('expenses_retry');

  final String tripId;
  final String? tab;
  final int? day;
  final bool add;
  final ExpenseList? initial;

  @override
  State<TripExpensesScreen> createState() => _TripExpensesScreenState();
}

class _TripExpensesScreenState extends State<TripExpensesScreen> {
  late final TripExpensesController c;
  Worker? _ready;
  bool _addHandled = false;

  @override
  void initState() {
    super.initState();
    c = Get.put(TripExpensesController(widget.tripId, initial: widget.initial), tag: widget.tripId);
    if (widget.tab == 'balances') c.tab.value = 1;
    _ready = ever<ExpenseList?>(c.list, (_) => _afterLoad());
    if (widget.initial != null) WidgetsBinding.instance.addPostFrameCallback((_) => _afterLoad());
    c.reload();
  }

  @override
  void dispose() {
    _ready?.dispose();
    Get.delete<TripExpensesController>(tag: widget.tripId);
    super.dispose();
  }

  Future<void> _afterLoad() async {
    final l = c.list.value;
    if (l == null || !mounted) return;
    if (l.isFormer && !c.formerHandled) {
      c.formerHandled = true;
      ExpenseDeps.openMyShare(widget.tripId);
      return;
    }
    if (widget.add && !_addHandled && c.canAdd && !l.limitReached) {
      _addHandled = true;
      await _openAdd(day: widget.day);
      return;
    }
    final late = l.latePrompt;
    if (late != null && c.canAdd && !c.latePromptHandled) {
      c.latePromptHandled = true;
      await _late(late);
    }
  }

  void _snack(String text) => BuddySnack.show(context, text, bottom: 104);

  Future<void> _openAdd({ExpenseSuggestion? suggestion, int? day}) async {
    final l = c.list.value;
    if (l == null || !c.canAdd || l.limitReached) return;
    final end = await ExpenseSheet.show(context, ExpenseSheetSetup.fromList(l, day: day, suggestion: suggestion));
    if (!mounted || end == null) return;
    switch (end) {
      case SheetSaveEnd.saved:
        _snack(ExpenseStrings.added);
      case SheetSaveEnd.closeFrozen:
        ExpenseDeps.toast(ExpenseStrings.frozenToast);
      default:
        break;
    }
    await c.reload();
  }

  Future<void> _late(LatePrompt p) async {
    final choice = await LateJoinerSheet.show(context, p);
    if (!mounted || choice == null) return;
    if (choice == LateChoice.keep) {
      await c.keepLate(p.userId);
      return;
    }
    final end = await ShareEarlierSheet.show(context, tripId: widget.tripId, prompt: p, travellers: c.travellers);
    if (!mounted || end == null) return;
    if (end == ShareEnd.shared) _snack(ExpenseStrings.sharedWithSnack(p.name));
    if (end == ShareEnd.frozen) ExpenseDeps.toast(ExpenseStrings.frozenToast);
    await c.reload();
  }

  Future<void> _openRow(ExpenseItem item) async {
    final pending = ExpensePendingSource.to.forTrip(widget.tripId).firstWhereOrNull((p) => p.expenseId == item.id);
    if (pending != null) return PendingRowExtras.onTap(context, pending);
    await ExpenseDeps.openExpense(widget.tripId, item.id);
    if (mounted) await c.reload();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final l = c.list.value;
        final status = c.status.value;
        if (l == null) {
          return BuddyPage(
            title: ExpenseStrings.title,
            scroll: false,
            body: switch (status) {
              ExpenseLoad.gone => _state(ExpenseStrings.tripGone, ExpenseStrings.tripGoneLine),
              ExpenseLoad.failed => _state(BuddySharedStrings.couldNotLoad, BuddySharedStrings.couldNotLoadLine, retry: true),
              _ => const Center(child: CircularProgressIndicator()),
            },
          );
        }
        if (status == ExpenseLoad.gone) {
          return BuddyPage(title: ExpenseStrings.title, scroll: false, body: _state(ExpenseStrings.tripGone, ExpenseStrings.tripGoneLine));
        }
        return BuddyPage(
          title: ExpenseStrings.title,
          subtitle: c.headerLine(),
          trailing: [l.isOwner ? _menu(l) : const ViewOnlyChip()],
          scroll: false,
          body: RefreshIndicator(
            onRefresh: c.reload,
            child: ListView(
              padding: DS.insets(b: 20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: _content(l),
            ),
          ),
          bottomBar: c.canAdd ? _bar(l) : null,
        );
      });

  Widget _menu(ExpenseList l) => PopupMenuButton<int>(
        key: TripExpensesScreen.menuKey,
        tooltip: ExpenseStrings.moreOptions,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: DS.circular(12)),
        color: DesignColors.surface,
        onSelected: (v) => v == 0 ? ExpenseDeps.openSettleUp(widget.tripId) : ExpenseDeps.openSummary(widget.tripId),
        itemBuilder: (_) => [
          if (l.tripEnded) PopupMenuItem<int>(value: 0, child: Text(ExpenseStrings.settleUp, style: Ink3D.text(13, FontWeight.w600, Ink3D.title))),
          PopupMenuItem<int>(value: 1, child: Text(ExpenseStrings.tripSummary, style: Ink3D.text(13, FontWeight.w600, Ink3D.title))),
        ],
        child: TripMenuDots.box(),
      );

  List<Widget> _content(ExpenseList l) {
    final pendingSource = ExpensePendingSource.to;
    pendingSource.version.value;
    final pending = pendingSource.forTrip(widget.tripId);
    final waitingCreates = pending.where((p) => p.kind == PendingKind.create && p.state == PendingState.waiting && !c.items.any((i) => i.id == p.expenseId));
    final items = c.items.toList();
    final editDiff = QueueRules.totals(pending.where((p) => p.kind == PendingKind.edit), items);
    final empty = items.isEmpty && pending.isEmpty && l.totals.expenseCount == 0;
    final tab = c.tab.value;
    final suggestion = c.suggestion;
    return [
      ExpenseSyncBanner(tripId: widget.tripId),
      ExpenseStateBanner(tripId: widget.tripId),
      if (l.isOwner)
        ExpenseOwnerHero(
          totals: l.totals,
          travellers: c.currentTravellers,
          empty: empty,
          limitReached: l.limitReached,
          pendingSpent: waitingCreates.fold(0, (a, p) => a + p.shown.amount) + editDiff.spent,
          pendingShare: waitingCreates.fold(0, (a, p) => a + p.shown.myShare) + editDiff.myShare,
        )
      else
        ViewerMoneyCard(tripId: widget.tripId),
      if (!empty)
        SegmentTabs(
          labels: const [ExpenseStrings.tabByDay, ExpenseStrings.tabBalances],
          selected: tab,
          onTap: (i) => c.tab.value = i,
          tone: BuddyLook.rose,
        ),
      if (tab == 1 && !empty)
        BalancesView(tripId: widget.tripId)
      else ...[
        if (suggestion != null)
          ExpenseSuggestionCard(
            suggestion: suggestion,
            busy: c.skipping.value,
            onSkip: () => c.skipSuggestion(suggestion),
            onAdd: () => _openAdd(suggestion: suggestion),
          ),
        if (empty)
          _empty(l)
        else
          ExpenseDayList(
            days: l.days,
            items: items,
            travellers: l.travellers,
            callerIsOwner: l.isOwner,
            fold: l.isOwner,
            expanded: c.expanded.value,
            onShowAll: c.showAll,
            onTap: _openRow,
            pending: pending,
            rowExtras: PendingRowExtras.of,
            startDate: l.startDate,
          ),
        if (c.loadingMore.value) Padding(padding: DS.all(16), child: const Center(child: CircularProgressIndicator())),
      ],
    ];
  }

  Widget _empty(ExpenseList l) => Padding(
        padding: DS.sym(h: 16, v: 20),
        child: Column(
          children: [
            ExcludeSemantics(child: Art3D(asset: ExpenseLook.moneyBag, size: 56, shadowBlur: 3, shadowOffset: const Offset(2, 4))),
            Gap.v(8),
            Text(ExpenseStrings.emptyTitle, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
            Gap.v(4),
            Text(l.isOwner ? ExpenseStrings.emptyLine : ExpenseStrings.emptyViewer(l.ownerName),
                textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, ExpenseLook.copy, letterSpacing: 0)),
          ],
        ),
      );

  Widget _state(String title, String line, {bool retry = false}) => Center(
        child: Padding(
          padding: DS.sym(h: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: Art3D(asset: ExpenseLook.moneyBag, size: 72, shadowBlur: 3, shadowOffset: const Offset(2, 4))),
              Gap.v(12),
              Text(title, textAlign: TextAlign.center, style: Ink3D.text(16, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
              Gap.v(4),
              Text(line, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w400, ExpenseLook.copy, letterSpacing: 0)),
              if (retry) ...[Gap.v(14), SmallPill(key: TripExpensesScreen.retryKey, label: BuddySharedStrings.retry, onTap: c.reload)],
            ],
          ),
        ),
      );

  Widget _bar(ExpenseList l) {
    final pill = GradientPillButton(
      key: TripExpensesScreen.addKey,
      tone: BuddyLook.rose,
      label: ExpenseStrings.addExpense,
      enabled: !l.limitReached,
      offColor: ExpenseLook.pillDisabled,
      onTap: () => _openAdd(),
    );
    if (!l.limitReached) return BuddyBottomBar(children: [pill]);
    return BuddyBottomBar(children: [
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: DS.insets(l: 2, r: 2, b: 10),
            child: Row(
              children: [
                Image.asset(ExpenseLook.dividers, width: DS.s(30)),
                Gap.h(10),
                Expanded(child: Text(ExpenseStrings.limitLine, style: Ink3D.text(12.5, FontWeight.w600, BuddyLook.subText, height: 1.4, letterSpacing: 0))),
              ],
            ),
          ),
          pill,
        ],
      ),
    ]);
  }
}
