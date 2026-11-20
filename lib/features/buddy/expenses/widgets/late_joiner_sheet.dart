import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../expense_look.dart';
import '../expense_strings.dart';
import '../models/expense_models.dart';
import 'expense_form_parts.dart';

enum LateChoice { keep, choose }

abstract final class LateJoinerSheet {
  static const Key keepKey = ValueKey('late_keep');
  static const Key chooseKey = ValueKey('late_choose');

  static Widget box(LatePrompt p, {VoidCallback? onKeep, VoidCallback? onChoose}) => Dialog3D(
        tone: BuddyLook.rose,
        art: ExpenseLook.panda,
        title: ExpenseStrings.lateTitle(p.name),
        body: ExpenseStrings.lateBody(p.name),
        tight: true,
        content: Container(
          padding: DS.sym(h: 14, v: 10),
          decoration: BoxDecoration(color: ExpenseLook.roseTint, borderRadius: ExpenseShape.corner(24)),
          alignment: Alignment.center,
          child: Text(ExpenseStrings.lateLine(p.count, p.total),
              textAlign: TextAlign.center, style: Ink3D.text(13.5, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
        ),
        actions: [
          GradientPillButton(key: keepKey, tone: BuddyLook.rose, label: ExpenseStrings.keepThem, onTap: onKeep),
          WhitePillButton(key: chooseKey, tone: BuddyLook.rose, label: ExpenseStrings.chooseExpenses, onTap: onChoose),
        ],
      );

  static Future<LateChoice?> show(BuildContext context, LatePrompt p) => Dialog3D.show<LateChoice>(
        context,
        builder: (ctx) => box(
          p,
          onKeep: () => Navigator.of(ctx).pop(LateChoice.keep),
          onChoose: () => Navigator.of(ctx).pop(LateChoice.choose),
        ),
      );
}
