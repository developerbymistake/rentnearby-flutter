import 'package:flutter/material.dart';

import '../../shared/buddy_format.dart';
import '../../shared/widgets/money_hero.dart';
import '../expense_strings.dart';
import '../models/expense_models.dart';

class ExpenseOwnerHero extends StatelessWidget {
  const ExpenseOwnerHero({super.key, required this.totals, required this.travellers, required this.empty, required this.limitReached, this.pendingSpent = 0, this.pendingShare = 0});

  final ExpenseTotals totals;
  final int travellers;
  final bool empty;
  final bool limitReached;
  final int pendingSpent;
  final int pendingShare;

  @override
  Widget build(BuildContext context) {
    final share = (BuddyFormat.rupees(totals.myShare + pendingShare), ExpenseStrings.yourShareCell);
    final cells = <(String, String)>[
      if (!empty) share,
      if (limitReached) ('${totals.expenseCount}', ExpenseStrings.expensesCell) else ('$travellers', ExpenseStrings.travellersCell),
    ];
    return MoneyHero(label: ExpenseStrings.spentSoFar, amount: BuddyFormat.rupees(totals.spent + pendingSpent), cells: cells);
  }
}
