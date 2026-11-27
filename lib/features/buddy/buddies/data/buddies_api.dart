import '../../../../services/api_service.dart';
import '../../shared/buddy_api_base.dart';
import '../../shared/buddy_json.dart';
import '../../shared/buddy_result.dart';
import '../models/buddy_models.dart';

class BuddiesApi {
  const BuddiesApi();

  static List<ReportReason>? _reasons;

  Future<BuddyResult<FindResult>> find(String query, {required String source}) => BuddyApiBase.run(
      () async => FindResult.fromJson(BuddyApiBase.dataOf(await ApiService.post('/buddies/find', {'query': query, 'source': source}))));

  Future<BuddyResult<BuddyList>> buddies({String? cursor, int limit = 50, String? forTripId}) => BuddyApiBase.run(() async => BuddyList.fromJson(
      BuddyApiBase.dataOf(await BuddyApiBase.read(
          () => ApiService.get('/buddies', params: BuddyApiBase.query({'cursor': cursor, 'limit': limit, 'forTripId': forTripId}))))));

  Future<BuddyResult<void>> remove(String userId) => BuddyApiBase.run(() async => ApiService.deleteJson('/buddies/$userId'));

  Future<BuddyResult<BuddySummary>> summary() => BuddyApiBase.run(
      () async => BuddySummary.fromJson(BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('/buddies/summary')))));

  Future<BuddyResult<void>> block(String userId, {ReportInput? alsoReport, String? context}) => BuddyApiBase.run(
      () async => ApiService.post('/users/$userId/block', {'alsoReport': alsoReport?.toJson(), 'context': context}));

  Future<BuddyResult<void>> unblock(String userId) => BuddyApiBase.run(() async => ApiService.post('/users/$userId/unblock', const {}));

  Future<BuddyResult<BlockedList>> blocks({String? cursor}) => BuddyApiBase.run(() async => BlockedList.fromJson(BuddyApiBase.dataOf(
      await BuddyApiBase.read(() => ApiService.get('/users/me/blocks', params: BuddyApiBase.query({'cursor': cursor}))))));

  Future<BuddyResult<void>> report(String userId, {required String reasonId, String? note, required bool alsoBlock, required String context}) =>
      BuddyApiBase.run(() async => ApiService.post(
          '/users/$userId/report', {'reasonId': reasonId, 'note': note, 'alsoBlock': alsoBlock, 'context': context}));

  Future<BuddyResult<List<ReportReason>>> reportReasons() async {
    final cached = _reasons;
    if (cached != null) return BuddyOk(cached);
    final result = await BuddyApiBase.run(() async => [
          for (final r in BuddyApiBase.listOf(await BuddyApiBase.read(() => ApiService.get('/report-reasons', params: {'scope': 'User'}))))
            if (r is Map) ReportReason.fromJson(BuddyJson.map(r)),
        ]);
    if (result is BuddyOk<List<ReportReason>>) _reasons = result.value;
    return result;
  }

  Future<BuddyResult<BlockContext>> blockContext(String userId) => BuddyApiBase.run(() async =>
      BlockContext.fromJson(BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('/users/$userId/block-context')))));

  static void clearSessionCache() => _reasons = null;
}
