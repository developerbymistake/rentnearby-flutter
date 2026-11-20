import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../buddy_navigation.dart';
import '../expenses/controllers/expense_sheet_controller.dart';
import '../expenses/controllers/trip_expenses_controller.dart';
import '../expenses/data/expense_list_cache.dart';
import '../expenses/data/expense_write_gateway.dart';
import '../expenses/models/expense_models.dart';
import '../expenses/widgets/expense_sheet.dart';
import '../shared/models/person_models.dart';
import 'expense_queue_service.dart';
import 'queued_expense_gateway.dart';

Future<void> registerOfflineQueue() async {
  OfflineHooks.onTripGone = _closeExpenses;
  OfflineHooks.logout = _logout;
  OfflineHooks.travellers = _travellers;
  OfflineHooks.openEdit = openPendingEdit;
  final ExpenseQueueService queue = ExpenseQueueService.maybe ?? Get.put(ExpenseQueueService(userSource: _userSource()));
  if (!Get.isRegistered<ExpenseWriteGateway>()) Get.put<ExpenseWriteGateway>(QueuedExpenseGateway(queue));
  if (!Get.isRegistered<ExpensePendingSource>()) Get.put<ExpensePendingSource>(queue);
  await queue.ready;
}

Rx<String?>? _userSource() {
  if (!Get.isRegistered<AuthController>()) return null;
  final auth = Get.find<AuthController>();
  final rx = Rx<String?>(auth.user.value?.id);
  ever(auth.user, (u) => rx.value = u?.id);
  return rx;
}

void _closeExpenses(String tripId) {
  final args = Get.arguments;
  if (Get.currentRoute == AppRoutes.tripExpenses && args is Map && args['tripId'] == tripId) BuddyNavigation.backToMyTrips();
}

Future<void> _logout() async {
  if (Get.isRegistered<AuthController>()) await Get.find<AuthController>().logout();
}

List<MoneyPerson> _travellers(String tripId) => TripExpensesController.maybeOf(tripId)?.travellers ?? ExpenseListCache.read(tripId)?.travellers ?? const [];

Future<bool> openPendingEdit(BuildContext context, PendingExpense pending) async {
  final draft = pending.draft;
  final list = TripExpensesController.maybeOf(pending.tripId)?.list.value ?? ExpenseListCache.read(pending.tripId);
  if (draft == null || list == null) return false;
  final b = draft.body;
  final each = b.sharers.isEmpty ? 0 : b.amount ~/ b.sharers.length;
  final detail = ExpenseDetail(
    id: draft.expenseId,
    tripId: pending.tripId,
    title: b.title,
    category: b.category,
    amount: b.amount,
    dayNumber: b.dayNumber,
    link: b.link,
    paidByUserId: b.paidByUserId,
    splitMode: b.splitMode,
    note: b.note,
    version: b.baseVersion,
    editedTimes: 0,
    deleted: false,
    shares: b.shares.isNotEmpty ? b.shares : [for (final id in b.sharers) ExpenseShare(userId: id, share: each)],
  );
  final end = await ExpenseSheet.show(context, ExpenseSheetSetup.fromList(list, edit: detail));
  return end == SheetSaveEnd.saved || end == SheetSaveEnd.queued;
}
