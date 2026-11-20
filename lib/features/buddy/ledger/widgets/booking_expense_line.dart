import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../controllers/money_summary_controller.dart';
import '../ledger_look.dart';
import '../ledger_strings.dart';

class BookingExpenseLine extends StatefulWidget {
  const BookingExpenseLine({super.key, required this.tripId, required this.kind, required this.id, this.margin});

  final String tripId;
  final String kind;
  final String id;
  final EdgeInsets? margin;

  @override
  State<BookingExpenseLine> createState() => _BookingExpenseLineState();
}

class _BookingExpenseLineState extends State<BookingExpenseLine> {
  MoneySummaryController? _c;

  static BorderRadius get _radius =>
      DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(18), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)));

  @override
  void initState() {
    super.initState();
    if (widget.tripId.isNotEmpty && widget.id.isNotEmpty) _c = MoneySummaryController.acquire(widget.tripId);
  }

  @override
  void dispose() {
    if (_c != null) MoneySummaryController.release(widget.tripId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return const SizedBox.shrink();
    return Obx(() {
      final total = c.summary.value?.linkTotal(widget.kind, widget.id) ?? 0;
      if (total <= 0) return const SizedBox.shrink();
      return Container(
        margin: widget.margin ?? EdgeInsets.only(top: DS.s(12)),
        padding: DS.sym(h: 12, v: 8),
        decoration: BoxDecoration(color: LedgerLook.expenseTint, borderRadius: _radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(LedgerStrings.inExpenses, style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
            Text(BuddyFormat.rupees(total), style: Ink3D.text(15, FontWeight.w700, BuddyLook.roseEnd, letterSpacing: 0)),
          ],
        ),
      );
    });
  }
}
