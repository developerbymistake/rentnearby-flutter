import 'package:flutter/material.dart';

import '../../shared/widgets/buddy_stub_screen.dart';
import '../../ledger/ledger_strings.dart';

class MoneySummaryScreen extends StatelessWidget {
  const MoneySummaryScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context) => const BuddyStubScreen(title: LedgerStrings.summaryTitle);
}
