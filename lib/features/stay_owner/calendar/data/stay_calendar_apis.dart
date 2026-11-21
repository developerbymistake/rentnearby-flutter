import '../../../owner_core/calendar/models/calendar_models.dart';
import '../../../owner_core/data/owner_api.dart';
import '../../../owner_core/data/owner_cache.dart';
import '../../../owner_core/data/owner_result.dart';
import '../../../owner_core/json/owner_dates.dart';
import '../models/stay_calendar_models.dart';

class StayBlockApi {
  const StayBlockApi();

  static const String prefix = '/stays/me/blocked-ranges';

  Future<OwnerResult<StayBlockList>> list() => OwnerApi.get(prefix, StayBlockList.fromJson);

  Future<OwnerResult<StayBlockWrite>> create(StayBlockDraft d, {bool confirm = false}) =>
      OwnerApi.post(confirm ? '$prefix?confirm=true' : prefix, d.toJson(), StayBlockWrite.fromJson);

  Future<OwnerResult<StayBlockWrite>> update(StayBlockDraft d, {bool confirm = false}) =>
      OwnerApi.put(confirm ? '$prefix/${d.id}?confirm=true' : '$prefix/${d.id}', d.toJson(), StayBlockWrite.fromJson);

  Future<OwnerResult<void>> delete(String id) => OwnerApi.delete('$prefix/$id');
}

class StaySpecialPriceApi {
  const StaySpecialPriceApi();

  static const String prefix = '/stays/me/special-prices';
  static const Duration festivalTtl = Duration(hours: 1);

  Future<OwnerResult<StaySpecialPricesPage>> list() => OwnerApi.get(prefix, StaySpecialPricesPage.fromJson);

  Future<OwnerResult<Map<String, dynamic>>> create(StaySpecialPriceDraft d) => OwnerApi.post(prefix, d.toJson(), (j) => j);

  Future<OwnerResult<Map<String, dynamic>>> update(StaySpecialPriceDraft d) => OwnerApi.put('$prefix/${d.id}', d.toJson(), (j) => j);

  Future<OwnerResult<void>> delete(String id) => OwnerApi.delete('$prefix/$id');

  Future<OwnerResult<Map<String, dynamic>>> pause(String id, {required bool paused, required int version}) =>
      OwnerApi.put('$prefix/$id/pause', {'paused': paused, 'version': version}, (j) => j);

  Future<OwnerResult<Map<String, dynamic>>> live(String id, {required int version}) =>
      OwnerApi.put('$prefix/$id/live', {'version': version}, (j) => j);

  Future<List<FestivalRow>> festivals({String? userId, String? stateName, required DateTime from, required DateTime to}) async {
    final key = OwnerCacheKeys.festivals(stateName ?? 'all');
    final saved = OwnerCache.read(userId, key);
    final at = saved?['savedAt'];
    final savedAt = DateTime.tryParse(at is String ? at : '');
    if (saved != null && savedAt != null && DateTime.now().difference(savedAt) < festivalTtl) {
      return FestivalRow.listOf(saved['items']);
    }
    final r = await OwnerApi.get(
      '/festivals',
      (j) => j,
      params: {'stateName': stateName, 'from': OwnerDates.dayText(from), 'to': OwnerDates.dayText(to)},
    );
    if (r is OwnerOk<Map<String, dynamic>>) {
      final raw = r.value['items'];
      OwnerCache.write(userId, key, {'savedAt': DateTime.now().toIso8601String(), 'items': raw is List ? raw : const []});
      return FestivalRow.listOf(raw);
    }
    return saved == null ? const [] : FestivalRow.listOf(saved['items']);
  }
}

class StayPlanVisibleApi {
  const StayPlanVisibleApi();

  Future<OwnerResult<Map<String, dynamic>>> load() => OwnerApi.get('/stays/me', (j) => j);

  Future<OwnerResult<Map<String, dynamic>>> save({required List<String> photoIds, required List<String> roomIds}) =>
      OwnerApi.put('/stays/me/plan-visible', {'photoIds': photoIds, 'roomIds': roomIds}, (j) => j);
}
