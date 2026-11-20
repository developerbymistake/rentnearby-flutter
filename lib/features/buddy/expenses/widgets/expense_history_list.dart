import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../expense_look.dart';
import '../expense_rules.dart';
import '../expense_strings.dart';
import '../models/expense_models.dart';
import 'expense_form_parts.dart';

class ExpenseHistoryList extends StatelessWidget {
  const ExpenseHistoryList({super.key, required this.history, required this.nameOf});

  final List<ExpenseHistoryLine> history;
  final String Function(String? userId) nameOf;

  @override
  Widget build(BuildContext context) {
    final lines = [for (final h in history) ...ExpenseHistoryCopy.lines(h, nameOf)];
    return Container(
      margin: DS.insets(l: 18, t: 16, r: 18),
      padding: DS.sym(h: 16, v: 14),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: ExpenseShape.corner(40), boxShadow: ExpenseShape.card()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: DS.insets(b: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Semantics(header: true, child: Text(ExpenseStrings.history, style: Ink3D.text(15, FontWeight.w700, Ink3D.title, letterSpacing: 0)))),
                Text(ExpenseStrings.historyLine, style: Ink3D.text(12.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
              ],
            ),
          ),
          for (var i = 0; i < lines.length; i++) _Line(text: lines[i], newest: i == 0, last: i == lines.length - 1),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.text, required this.newest, required this.last});

  final ExpenseHistoryText text;
  final bool newest;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final detail = text.detail;
    final em = text.emphasis;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: DS.s(14),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (!last) Positioned(left: DS.s(6), top: DS.s(26), bottom: -DS.s(8), child: Container(width: DS.s(2), color: ExpenseLook.roseDash)),
                Positioned(
                  top: DS.s(16),
                  child: Container(
                    width: DS.s(14),
                    height: DS.s(14),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: newest ? ExpenseLook.roseDot : ExpenseLook.greyDot),
                  ),
                ),
              ],
            ),
          ),
          Gap.h(14),
          Expanded(
            child: Padding(
              padding: DS.sym(v: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text.time, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                  Text(text.sentence, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                  if (detail != null)
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: detail),
                        if (em != null) TextSpan(text: em, style: Ink3D.text(13, FontWeight.w700, BuddyLook.roseEnd, letterSpacing: 0)),
                      ]),
                      style: Ink3D.text(13, FontWeight.w400, BuddyLook.subText, letterSpacing: 0),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
