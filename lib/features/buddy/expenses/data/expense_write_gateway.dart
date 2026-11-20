import 'package:get/get.dart';

import '../../shared/buddy_result.dart';
import '../models/expense_draft.dart';
import '../models/expense_models.dart';
import 'expenses_api.dart';

sealed class ExpenseWriteOutcome {
  const ExpenseWriteOutcome();
}

class ExpenseSaved extends ExpenseWriteOutcome {
  const ExpenseSaved({required this.expense, required this.balancesVersion});

  final ExpenseDetail expense;
  final int balancesVersion;
}

class ExpenseDeleted extends ExpenseWriteOutcome {
  const ExpenseDeleted({required this.balancesVersion});

  final int balancesVersion;
}

class ExpenseQueued extends ExpenseWriteOutcome {
  const ExpenseQueued({required this.opId});

  final String opId;
}

class ExpenseRefused extends ExpenseWriteOutcome {
  const ExpenseRefused({required this.error});

  final BuddyRefused<Object?> error;
}

class ExpenseWriteFailed extends ExpenseWriteOutcome {
  const ExpenseWriteFailed({required this.message});

  static const String offline = 'offline';

  final String message;

  bool get isOffline => message == offline;
}

abstract class ExpenseWriteGateway {
  static ExpenseWriteGateway get to => Get.isRegistered<ExpenseWriteGateway>() ? Get.find<ExpenseWriteGateway>() : const OnlineExpenseGateway();

  Future<ExpenseWriteOutcome> save(ExpenseDraft draft);

  Future<ExpenseWriteOutcome> delete({
    required String tripId,
    required String expenseId,
    required int baseVersion,
    required String opId,
    bool paymentsAcknowledged = false,
    required ExpenseItem shown,
  });
}

class OnlineExpenseGateway implements ExpenseWriteGateway {
  const OnlineExpenseGateway({this.api = const ExpensesApi()});

  final ExpensesApi api;

  @override
  Future<ExpenseWriteOutcome> save(ExpenseDraft draft) async {
    final result = await api.save(draft.tripId, draft.expenseId, draft.body);
    return switch (result) {
      BuddyOk(:final value) => ExpenseSaved(expense: value.expense, balancesVersion: value.balancesVersion),
      BuddyRefused() => ExpenseRefused(error: result.cast<Object?>()),
      BuddyOffline() => const ExpenseWriteFailed(message: ExpenseWriteFailed.offline),
      BuddyFailed(:final message) => ExpenseWriteFailed(message: message),
    };
  }

  @override
  Future<ExpenseWriteOutcome> delete({
    required String tripId,
    required String expenseId,
    required int baseVersion,
    required String opId,
    bool paymentsAcknowledged = false,
    required ExpenseItem shown,
  }) async {
    final result = await api.delete(tripId, expenseId, baseVersion: baseVersion, opId: opId, paymentsAcknowledged: paymentsAcknowledged);
    return switch (result) {
      BuddyOk(:final value) => ExpenseDeleted(balancesVersion: value),
      BuddyRefused() => ExpenseRefused(error: result.cast<Object?>()),
      BuddyOffline() => const ExpenseWriteFailed(message: ExpenseWriteFailed.offline),
      BuddyFailed(:final message) => ExpenseWriteFailed(message: message),
    };
  }
}

enum PendingKind { create, edit, delete }

enum PendingState { waiting, notSaved }

enum PendingAction { refresh, edit, remove }

class PendingExpense {
  const PendingExpense({
    required this.opId,
    required this.tripId,
    required this.expenseId,
    required this.kind,
    required this.state,
    required this.shown,
    this.draft,
    this.line,
    this.action,
  });

  final String opId;
  final String tripId;
  final String expenseId;
  final PendingKind kind;
  final PendingState state;
  final ExpenseItem shown;
  final ExpenseDraft? draft;
  final String? line;
  final PendingAction? action;
}

abstract class ExpensePendingSource {
  static ExpensePendingSource get to =>
      Get.isRegistered<ExpensePendingSource>() ? Get.find<ExpensePendingSource>() : const NoPendingExpenses();

  RxInt get version;

  List<PendingExpense> forTrip(String tripId);
}

class NoPendingExpenses implements ExpensePendingSource {
  const NoPendingExpenses();

  static final RxInt _version = 0.obs;

  @override
  RxInt get version => _version;

  @override
  List<PendingExpense> forTrip(String tripId) => const [];
}
