import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../shared/widgets/small_pill.dart';
import '../expense_look.dart';
import '../expense_strings.dart';
import '../models/expense_models.dart';
import 'expense_form_parts.dart';

class ExpenseSuggestionCard extends StatelessWidget {
  const ExpenseSuggestionCard({super.key, required this.suggestion, required this.onSkip, required this.onAdd, this.busy = false});

  static const Key skipKey = ValueKey('expense_suggestion_skip');
  static const Key addKey = ValueKey('expense_suggestion_add');

  final ExpenseSuggestion suggestion;
  final VoidCallback onSkip;
  final VoidCallback onAdd;
  final bool busy;

  @override
  Widget build(BuildContext context) => Container(
        margin: DS.insets(l: 18, t: 20, r: 18),
        padding: DS.sym(h: 16, v: 14),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: ExpenseShape.corner(40),
          border: Border.all(color: ExpenseLook.roseBorder, width: DS.s(2)),
          boxShadow: ExpenseShape.card(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(child: Art3D(asset: ExpenseLook.categoryArt(ExpenseCategory.stay), size: 52, shadowBlur: 3, shadowOffset: const Offset(2, 4))),
                Gap.h(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ExpenseStrings.suggestionTitle(suggestion.name, suggestion.amount),
                          style: Ink3D.text(15, FontWeight.w700, Ink3D.title, height: 1.35, letterSpacing: 0)),
                      Text(ExpenseStrings.suggestionLine, style: Ink3D.text(12.5, FontWeight.w400, ExpenseLook.copy, letterSpacing: 0)),
                    ],
                  ),
                ),
              ],
            ),
            Gap.v(12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SmallPill(key: skipKey, label: ExpenseStrings.skip, onTap: onSkip, busy: busy),
                Gap.h(10),
                SmallPill(key: addKey, label: ExpenseStrings.add, onTap: onAdd, kind: SmallPillKind.rose),
              ],
            ),
          ],
        ),
      );
}
