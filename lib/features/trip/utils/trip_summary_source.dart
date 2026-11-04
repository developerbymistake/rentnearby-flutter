import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../utils/network_retry.dart';
import '../data/trip_repository.dart';
import '../models/trip_summary_model.dart';

class TripSummarySnapshot {
  final TripSummaryRecord record;
  final DateTime? cachedAt;

  const TripSummarySnapshot(this.record, {this.cachedAt});

  bool get fromCache => cachedAt != null;
}

class TripSummarySource {
  static const String _savedKey = 'cachedAt';

  static bool isGone(Object e) {
    if (DioErrorMapper.errorType(e) == TripErrorTypes.tripNotFound) return true;
    if (e is! DioException) return false;
    final code = e.response?.statusCode;
    return code == 404 || code == 403;
  }

  static Map<String, dynamic> _data(Map<String, dynamic> res) {
    final data = res['data'];
    return data is Map<String, dynamic> ? data : const {};
  }

  static TripSummarySnapshot? cached(String tripId) {
    final json = StorageService.getTripSummaryCache(tripId);
    if (json == null) return null;
    try {
      return TripSummarySnapshot(
        TripSummaryRecord.fromJson(json),
        cachedAt: DateTime.tryParse(json[_savedKey] as String? ?? '') ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<TripSummarySnapshot> load(String tripId) async {
    final path = '/trips/$tripId/summary';
    final saved = cached(tripId);
    try {
      final data = _data(saved == null ? await withRetry(() => ApiService.get(path)) : await ApiService.get(path));
      final record = TripSummaryRecord.fromJson(data);
      StorageService.saveTripSummaryCache(tripId, {...data, _savedKey: DateTime.now().toIso8601String()});
      return TripSummarySnapshot(record);
    } catch (e) {
      if (saved != null && DioErrorMapper.isNetworkError(e)) return saved;
      rethrow;
    }
  }
}
