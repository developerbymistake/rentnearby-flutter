import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../shared/widgets/note_banner.dart';
import '../controllers/trip_balances_controller.dart';
import '../ledger_look.dart';
import '../ledger_strings.dart';

class ExpenseStateBanner extends StatefulWidget {
  const ExpenseStateBanner({super.key, required this.tripId});

  final String tripId;

  @override
  State<ExpenseStateBanner> createState() => _ExpenseStateBannerState();
}

class _ExpenseStateBannerState extends State<ExpenseStateBanner> {
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
        if (b == null || !b.frozen) return const SizedBox.shrink();
        return const NoteBanner(art: LedgerLook.locked, text: LedgerStrings.closedForChanges);
      });
}
