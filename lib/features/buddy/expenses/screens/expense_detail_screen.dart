import 'package:flutter/material.dart';

import '../../shared/widgets/buddy_stub_screen.dart';
import '../../expenses/expense_strings.dart';

class ExpenseDetailScreen extends StatelessWidget {
  const ExpenseDetailScreen({super.key, required this.tripId, required this.expenseId});

  final String tripId;
  final String expenseId;

  @override
  Widget build(BuildContext context) => const BuddyStubScreen(title: ExpenseStrings.title);
}
