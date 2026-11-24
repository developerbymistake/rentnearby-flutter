import 'package:flutter/material.dart';

import '../../../trip/widgets/trip_hero_card.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../models/sharing_models.dart';
import '../sharing_strings.dart';

class OverviewExpensesCard extends StatelessWidget {
  const OverviewExpensesCard({super.key, required this.expenses, required this.tripEnded, required this.onAdd, required this.onView});

  final TripExpenseCard expenses;
  final bool tripEnded;
  final VoidCallback onAdd;
  final VoidCallback onView;

  static bool isSettled(TripExpenseCard e) => e.settled && e.openPayments == 0;

  static String? chipOf(TripExpenseCard e, {required bool tripEnded}) {
    if (!e.hasExpenses) return null;
    final d = e.dayToday;
    if (d != null) return SharingStrings.day(d);
    return tripEnded && isSettled(e) ? SharingStrings.settled : null;
  }

  static String lineOf(TripExpenseCard e, {required bool tripEnded}) {
    if (!e.hasExpenses) return SharingStrings.noExpensesYet;
    final spent = BuddyFormat.rupees(e.spent);
    if (tripEnded && e.openPayments > 0) return SharingStrings.spentOpen(spent, e.openPayments);
    if (tripEnded && isSettled(e)) return SharingStrings.spentSettled(spent);
    return SharingStrings.spentShare(spent, BuddyFormat.rupees(e.myShare));
  }

  @override
  Widget build(BuildContext context) {
    final has = expenses.hasExpenses;
    return TripHeroCard(
      key: const ValueKey('overview_expenses_card'),
      tone: BuddyLook.rose,
      asset: BuddyArt.moneyBag,
      title: SharingStrings.expensesTitle,
      chip: chipOf(expenses, tripEnded: tripEnded),
      line: lineOf(expenses, tripEnded: tripEnded),
      button: has ? SharingStrings.view : SharingStrings.addExpense,
      onTap: has ? onView : onAdd,
      wholeCard: true,
    );
  }
}
