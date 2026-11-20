import '../../../../services/api_service.dart';
import '../../shared/buddy_api_base.dart';
import '../../shared/buddy_result.dart';
import '../models/ledger_models.dart';

class LedgerApi {
  const LedgerApi();

  Future<BuddyResult<TripBalances>> balances(String tripId) => BuddyApiBase.run(() async =>
      TripBalances.fromJson(BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('/trips/$tripId/balances')))));

  Future<BuddyResult<PaymentWriteResponse>> saidPaid(String tripId, {required String opId, required String toUserId, required int amount}) =>
      _write(() => ApiService.post('/trips/$tripId/payments/said-paid', {'opId': opId, 'toUserId': toUserId, 'amount': amount}));

  Future<BuddyResult<PaymentWriteResponse>> received(String tripId, String paymentId) =>
      _write(() => ApiService.post('/trips/$tripId/payments/$paymentId/received', const {}));

  Future<BuddyResult<void>> remind(String tripId, String fromUserId) =>
      BuddyApiBase.run(() async => ApiService.post('/trips/$tripId/payments/remind', {'fromUserId': fromUserId}));

  Future<BuddyResult<ExpenseSummary>> summary(String tripId) => BuddyApiBase.run(() async =>
      ExpenseSummary.fromJson(BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('/trips/$tripId/expenses/summary')))));

  Future<BuddyResult<PaymentWriteResponse>> withdraw(String tripId, String paymentId) =>
      _write(() => ApiService.post('/trips/$tripId/payments/$paymentId/withdraw', const {}));

  Future<BuddyResult<PaymentWriteResponse>> notReceived(String tripId, String paymentId) =>
      _write(() => ApiService.post('/trips/$tripId/payments/$paymentId/not-received', const {}));

  Future<BuddyResult<PaymentWriteResponse>> _write(Future<Map<String, dynamic>> Function() call) =>
      BuddyApiBase.run(() async => PaymentWriteResponse.fromJson(BuddyApiBase.dataOf(await call())));
}
