import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../../shared/strings_shared.dart';
import '../../shared/widgets/note_banner.dart';
import '../../shared/widgets/section_label.dart';
import '../controllers/trip_balances_controller.dart';
import '../ledger_look.dart';
import '../ledger_rules.dart';
import '../ledger_strings.dart';
import '../models/ledger_models.dart';
import 'balance_people_card.dart';
import 'who_pays_card.dart';

class BalancesView extends StatefulWidget {
  const BalancesView({super.key, required this.tripId});

  final String tripId;

  @override
  State<BalancesView> createState() => _BalancesViewState();
}

class _BalancesViewState extends State<BalancesView> {
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
        switch (_c.status.value) {
          case LedgerLoad.gone:
            return LedgerStateCard.gone();
          case LedgerLoad.failed:
            return LedgerStateCard.failed(_c.reload);
          case LedgerLoad.loading:
            if (b == null) return const LedgerLoadingBox();
          case LedgerLoad.ready:
            break;
        }
        if (b == null) return const LedgerLoadingBox();
        return BalancesBody(tripId: widget.tripId, balances: b);
      });
}

class BalancesBody extends StatelessWidget {
  const BalancesBody({super.key, required this.tripId, required this.balances});

  final String tripId;
  final TripBalances balances;

  @override
  Widget build(BuildContext context) {
    final b = balances;
    if (LedgerRules.nothingYet(b)) {
      return StateCard3D(
        tone: BuddyLook.rose,
        art: LedgerLook.moneyBag,
        title: LedgerStrings.nothingToSettle,
        message: LedgerStrings.nothingToSettleLine,
        layout: StateLayout.tall,
        margin: DS.insets(l: 18, t: 24, r: 18),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (LedgerRules.allSettled(b)) const NoteBanner(art: LedgerLook.flag, text: LedgerStrings.allSettled),
        if (b.isOwner) ...[
          BalancePeopleCard(people: b.people),
          SectionLabel(LedgerStrings.whoPaysWhom, padding: DS.insets(l: 22, t: 20, r: 22)),
        ],
        for (final r in b.payments) WhoPaysCard(tripId: tripId, balances: b, row: r),
      ],
    );
  }
}

class LedgerLoadingBox extends StatelessWidget {
  const LedgerLoadingBox({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.all(32),
        child: Center(child: SizedBox(width: DS.s(28), height: DS.s(28), child: CircularProgressIndicator(strokeWidth: DS.s(3), color: BuddyLook.roseEnd))),
      );
}

abstract final class LedgerStateCard {
  static Widget failed(VoidCallback onRetry) => StateCard3D(
        tone: BuddyLook.rose,
        art: LedgerLook.warning,
        title: BuddySharedStrings.couldNotLoad,
        message: BuddySharedStrings.couldNotLoadLine,
        actionLabel: BuddySharedStrings.retry,
        onAction: onRetry,
        layout: StateLayout.tall,
        margin: DS.insets(l: 18, t: 24, r: 18),
      );

  static Widget gone() => StateCard3D(
        tone: BuddyLook.indigo,
        art: LedgerLook.luggage,
        title: LedgerStrings.tripGone,
        message: LedgerStrings.tripGoneLine,
        layout: StateLayout.tall,
        margin: DS.insets(l: 18, t: 24, r: 18),
      );
}
