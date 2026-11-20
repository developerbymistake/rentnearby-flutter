import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/money_hero.dart';
import '../../shared/widgets/note_banner.dart';
import '../../shared/widgets/small_pill.dart';
import '../controllers/trip_balances_controller.dart';
import '../ledger_look.dart';
import '../ledger_rules.dart';
import '../ledger_strings.dart';
import '../models/ledger_models.dart';
import '../payment_flows.dart';

class ViewerMoneyCard extends StatefulWidget {
  const ViewerMoneyCard({super.key, required this.tripId});

  final String tripId;

  static const Key paidKey = ValueKey('viewer_i_have_paid');
  static const Key notPaidKey = ValueKey('viewer_not_paid');

  @override
  State<ViewerMoneyCard> createState() => _ViewerMoneyCardState();
}

class _ViewerMoneyCardState extends State<ViewerMoneyCard> {
  late final TripBalancesController _c;

  @override
  void initState() {
    super.initState();
    _c = TripBalancesController.acquire(widget.tripId);
  }

  @override
  void dispose() {
    TripBalancesController.release(widget.tripId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final b = _c.balances.value;
        _c.busy.length;
        if (b == null || b.isOwner) return const SizedBox.shrink();
        return ViewerMoneyBody(tripId: widget.tripId, balances: b, race: _c.race.value, busy: _c.busy.isNotEmpty);
      });
}

class ViewerMoneyBody extends StatelessWidget {
  const ViewerMoneyBody({super.key, required this.tripId, required this.balances, this.race = LedgerRace.none, this.busy = false});

  final String tripId;
  final TripBalances balances;
  final LedgerRace race;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final b = balances;
    final hero = LedgerRules.viewerHero(b, race: race);
    final row = hero.row;
    final text = hero.bannerText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MoneyHero(
          label: hero.label,
          amount: BuddyFormat.rupees(hero.amount),
          cells: [(BuddyFormat.rupees(b.me.share), LedgerStrings.yourShare), (BuddyFormat.rupees(b.me.paid), LedgerStrings.youPaid)],
        ),
        if (text != null) _banner(hero.banner, text),
        if (hero.showPaid && row != null)
          Padding(
            padding: DS.insets(l: 18, t: 16, r: 18),
            child: GradientPillButton(
              key: ViewerMoneyCard.paidKey,
              tone: BuddyLook.rose,
              label: LedgerStrings.iHavePaid,
              loading: busy,
              onTap: busy
                  ? null
                  : () => PaymentFlows.sayPaid(context, tripId, row, ownerName: b.ownerName, receiver: LedgerRules.personOr(b, row.toUserId)),
            ),
          ),
        if (hero.showNotPaid && row != null)
          Padding(
            padding: DS.insets(l: 18, t: 14, r: 18),
            child: Align(
              alignment: Alignment.centerRight,
              child: IntrinsicWidth(
                child: SmallPill(
                  key: ViewerMoneyCard.notPaidKey,
                  label: LedgerStrings.notPaid,
                  kind: SmallPillKind.dangerOutline,
                  busy: busy,
                  onTap: () => PaymentFlows.withdraw(context, tripId, row, ownerName: b.ownerName),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static Widget _banner(ViewerBanner kind, String text) => switch (kind) {
        ViewerBanner.amountChanged => NoteBanner(art: LedgerLook.alarm, text: text, tone: NoteTone.danger),
        ViewerBanner.notGotIt => NoteBanner(art: LedgerLook.warning, text: text, tone: NoteTone.danger),
        ViewerBanner.nothingLeft => NoteBanner(art: LedgerLook.star, text: text, tone: NoteTone.teal),
        ViewerBanner.waiting => NoteBanner(art: LedgerLook.alarm, text: text, tone: NoteTone.amber, margin: DS.insets(l: 18, t: 20, r: 18)),
        ViewerBanner.gotIt => NoteBanner(art: LedgerLook.star, text: text, tone: NoteTone.teal),
        ViewerBanner.none => const SizedBox.shrink(),
      };
}
