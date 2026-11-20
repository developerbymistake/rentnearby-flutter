import '../../../../services/api_service.dart';
import '../../shared/buddy_api_base.dart';
import '../../shared/buddy_json.dart';
import '../../shared/buddy_result.dart';
import '../models/expense_models.dart';

class ExpensesApi {
  const ExpensesApi();

  Future<BuddyResult<ExpenseList>> list(String tripId, {String? cursor, int limit = 100}) => BuddyApiBase.run(() async => ExpenseList.fromJson(
      BuddyApiBase.dataOf(await BuddyApiBase.read(
          () => ApiService.get('/trips/$tripId/expenses', params: BuddyApiBase.query({'cursor': cursor, 'limit': limit}))))));

  Future<BuddyResult<ExpenseWriteResponse>> save(String tripId, String expenseId, ExpenseWriteRequest body) => BuddyApiBase.run(
      () async => ExpenseWriteResponse.fromJson(BuddyApiBase.dataOf(await ApiService.put('/trips/$tripId/expenses/$expenseId', body.toJson()))));

  Future<BuddyResult<int>> delete(String tripId, String expenseId,
          {required int baseVersion, required String opId, bool paymentsAcknowledged = false}) =>
      BuddyApiBase.run(() async => BuddyJson.integer(BuddyApiBase.dataOf(await ApiService.deleteJson('/trips/$tripId/expenses/$expenseId',
          params: {'baseVersion': baseVersion, 'opId': opId, 'paymentsAcknowledged': paymentsAcknowledged}))['balancesVersion']));

  Future<BuddyResult<ExpenseDetailPage>> detail(String tripId, String expenseId) => BuddyApiBase.run(() async => ExpenseDetailPage.fromJson(
      BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('/trips/$tripId/expenses/$expenseId')))));

  Future<BuddyResult<void>> skipSuggestion(String tripId, {required String kind, required String sourceId}) => BuddyApiBase.run(
      () async => ApiService.post('/trips/$tripId/expenses/suggestions/skip', {'kind': kind, 'sourceId': sourceId}));

  Future<BuddyResult<void>> keepLateJoin(String tripId, String userId) =>
      BuddyApiBase.run(() async => ApiService.post('/trips/$tripId/expenses/late-join/$userId/keep', const {}));

  Future<BuddyResult<ShareWithResponse>> shareWith(String tripId, ShareWithRequest body) => BuddyApiBase.run(() async =>
      ShareWithResponse.fromJson(BuddyApiBase.dataOf(await ApiService.post('/trips/$tripId/expenses/share-with', body.toJson()))));
}
