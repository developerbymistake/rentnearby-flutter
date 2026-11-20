import 'package:flutter/material.dart';

import '../../shared/widgets/buddy_confirm_box.dart';
import '../expense_look.dart';
import '../expense_strings.dart';

abstract final class PaymentsMadeDialog {
  static Future<bool> ask(BuildContext context, List<String> names) => BuddyConfirmBox.ask(
        context,
        art: ExpenseLook.warning,
        title: ExpenseStrings.paymentsTitle,
        body: ExpenseStrings.paymentsBody(names),
        cancelLabel: ExpenseStrings.cancel,
        confirmLabel: ExpenseStrings.save,
        confirmKind: ConfirmKind.indigo,
      );
}
