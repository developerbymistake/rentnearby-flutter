import 'expense_models.dart';

class ExpenseDraft {
  const ExpenseDraft({required this.tripId, required this.expenseId, required this.body, this.shown});

  final String tripId;
  final String expenseId;
  final ExpenseWriteRequest body;
  final ExpenseItem? shown;

  String get opId => body.opId;
  int get baseVersion => body.baseVersion;
  bool get isCreate => body.isCreate;
}
