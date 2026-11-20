import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/buddy_bottom_bar.dart';
import '../../shared/widgets/buddy_page.dart';
import '../../shared/widgets/money_hero.dart';
import '../../shared/widgets/note_banner.dart';
import '../../shared/widgets/section_label.dart';
import '../controllers/trip_balances_controller.dart';
import '../ledger_deps.dart';
import '../ledger_look.dart';
import '../ledger_rules.dart';
import '../ledger_strings.dart';
import '../models/ledger_models.dart';
import '../widgets/balances_view.dart';
import '../widgets/ledger_menu.dart';
import '../widgets/who_pays_card.dart';

class SettleUpScreen extends StatefulWidget {
  const SettleUpScreen({super.key, required this.tripId});

  final String tripId;

  static const Key summaryKey = ValueKey('settle_trip_summary');

  @override
  State<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends State<SettleUpScreen> {
  late final TripBalancesController _c;

  @override
  void initState() {
    super.initState();
    final had = TripBalancesController.maybeOf(widget.tripId) != null;
    _c = TripBalancesController.acquire(widget.tripId);
    if (had) _c.reload();
  }

  @override
  void dispose() {
    TripBalancesController.release(widget.tripId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final b = _c.balances.value;
        _c.changed.length;
        _c.busy.length;
        final settled = b != null && LedgerRules.allSettled(b);
        return BuddyPage(
          title: LedgerStrings.settleUpTitle,
          subtitle: b == null ? null : LedgerStrings.endedLine(b.tripTitle, b.endDate),
          trailing: [
            LedgerMenu(items: [
              LedgerMenuItem(label: LedgerStrings.expensesTitle, art: LedgerLook.moneyBag, onTap: () => LedgerDeps.openExpenses(widget.tripId)),
              LedgerMenuItem(label: LedgerStrings.summaryTitle, art: LedgerLook.flag, onTap: () => LedgerDeps.openSummary(widget.tripId)),
            ]),
          ],
          scroll: false,
          body: RefreshIndicator(
            color: BuddyLook.roseEnd,
            onRefresh: _c.reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: DS.s(24)),
              children: [_content(b)],
            ),
          ),
          bottomBar: settled
              ? BuddyBottomBar(children: [
                  GradientPillButton(
                    key: SettleUpScreen.summaryKey,
                    tone: BuddyLook.rose,
                    label: LedgerStrings.summaryTitle,
                    onTap: () => LedgerDeps.openSummary(widget.tripId),
                  ),
                ])
              : null,
        );
      });

  Widget _content(TripBalances? b) {
    switch (_c.status.value) {
      case LedgerLoad.gone:
        return LedgerStateCard.gone();
      case LedgerLoad.failed:
        return LedgerStateCard.failed(_c.reload);
      default:
        break;
    }
    if (b == null) return const LedgerLoadingBox();
    return SettleUpBody(tripId: widget.tripId, balances: b);
  }
}

class SettleUpBody extends StatelessWidget {
  const SettleUpBody({super.key, required this.tripId, required this.balances});

  final String tripId;
  final TripBalances balances;

  @override
  Widget build(BuildContext context) {
    final b = balances;
    final net = b.me.net;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _banner(b),
        MoneyHero(
          label: LedgerRules.settleHeroLabel(net),
          amount: BuddyFormat.rupees(net.abs()),
          cells: [(BuddyFormat.rupees(b.me.received), LedgerStrings.receivedCell), (BuddyFormat.rupees(b.me.stillOpen), LedgerStrings.stillOpen)],
        ),
        SectionLabel(LedgerStrings.paymentsDone(b.paymentsDone, b.paymentsTotal), padding: DS.insets(l: 22, t: 20, r: 22)),
        for (final r in b.payments) WhoPaysCard(tripId: tripId, balances: b, row: r),
      ],
    );
  }

  static Widget _banner(TripBalances b) {
    if (LedgerRules.allSettled(b)) return const NoteBanner(art: LedgerLook.flag, text: LedgerStrings.allSettled);
    if (LedgerRules.reopenedNow(b)) {
      return NoteBanner(art: LedgerLook.warning, text: LedgerStrings.openAgain(LedgerRules.openAgain(b)), tone: NoteTone.amber, margin: DS.insets(l: 18, t: 20, r: 18));
    }
    return NoteBanner(art: LedgerLook.flag, text: LedgerStrings.toSettle(LedgerRules.toSettle(b)));
  }
}
