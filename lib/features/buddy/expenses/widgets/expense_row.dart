import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/buddy_badge.dart';
import '../expense_look.dart';
import '../expense_strings.dart';
import '../models/expense_models.dart';
import 'expense_form_parts.dart';

class ExpenseRow extends StatelessWidget {
  const ExpenseRow({super.key, required this.item, required this.payerLabel, this.onTap, this.extras, this.first = false});

  final ExpenseItem item;
  final String payerLabel;
  final VoidCallback? onTap;
  final Widget? extras;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final tags = [
      if (item.edited) ExpenseStrings.tagEdited,
      if (item.bookingCancelled) ExpenseStrings.tagBookingCancelled,
    ];
    final mine = item.myShare > 0;
    final row = Container(
      constraints: BoxConstraints(minHeight: DS.s(72)),
      padding: DS.sym(h: 16, v: 12),
      decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: BuddyLook.hairline, width: DS.s(1)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExpenseArtTile(asset: ExpenseLook.categoryArt(item.category)),
              Gap.h(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14.5, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                    Text(ExpenseStrings.paidShared(payerLabel, item.sharedBy),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                    if (tags.isNotEmpty)
                      Padding(
                        padding: DS.insets(t: 3),
                        child: Wrap(spacing: DS.s(6), runSpacing: DS.s(4), children: [for (final t in tags) BuddyBadge(t)]),
                      ),
                  ],
                ),
              ),
              Gap.h(12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(BuddyFormat.rupees(item.amount), style: Ink3D.text(15, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                  Text(ExpenseStrings.yourShare(item.myShare),
                      style: Ink3D.text(11.5, mine ? FontWeight.w600 : FontWeight.w400, mine ? BuddyLook.roseEnd : Ink3D.grey, letterSpacing: 0)),
                ],
              ),
            ],
          ),
          ?extras,
        ],
      ),
    );
    return Tap3D(tapKey: ValueKey('expense_row_${item.id}'), onTap: onTap, label: item.title, child: row);
  }
}
