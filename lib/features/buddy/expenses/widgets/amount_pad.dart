import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../controllers/expense_sheet_controller.dart';
import '../expense_look.dart';
import '../expense_strings.dart';

class AmountPad extends StatelessWidget {
  const AmountPad({super.key, required this.onKey});

  static Key keyOf(String k) => ValueKey('amount_pad_$k');

  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) => Container(
        color: ExpenseLook.padBg,
        padding: DS.insets(l: 8, t: 8, r: 8, b: 14).copyWith(bottom: DS.s(14) + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < 4; r++) ...[
              if (r > 0) SizedBox(height: DS.s(7)),
              Row(
                children: [
                  for (var c = 0; c < 3; c++) ...[
                    if (c > 0) SizedBox(width: DS.s(7)),
                    Expanded(child: _Key(label: AmountKeys.grid[r * 3 + c], onKey: onKey)),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onKey});

  final String label;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return SizedBox(height: DS.s(50));
    final back = label == AmountKeys.back;
    return Tap3D(
      tapKey: AmountPad.keyOf(label),
      onTap: () => onKey(label),
      label: back ? ExpenseStrings.backspace : label,
      exclude: true,
      child: Container(
        height: DS.s(50),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: back ? ExpenseLook.padKeyDark : DesignColors.surface,
          borderRadius: DS.circular(8),
          boxShadow: [BoxShadow(color: DesignColors.textStrong.withValues(alpha: Alpha.v25), offset: DS.shadowOffset(const Offset(0, 1)))],
        ),
        child: back
            ? Icon(Icons.backspace_outlined, size: DS.s(20), color: Ink3D.title)
            : Text(label, style: Ink3D.text(22, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
      ),
    );
  }
}
