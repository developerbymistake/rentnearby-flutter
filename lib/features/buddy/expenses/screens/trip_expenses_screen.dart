import 'package:flutter/material.dart';

import '../../shared/widgets/buddy_stub_screen.dart';
import '../../expenses/expense_strings.dart';

class TripExpensesScreen extends StatelessWidget {
  const TripExpensesScreen({super.key, required this.tripId, this.tab, this.day, this.add = false});

  final String tripId;
  final String? tab;
  final int? day;
  final bool add;

  @override
  Widget build(BuildContext context) => const BuddyStubScreen(title: ExpenseStrings.title);
}
