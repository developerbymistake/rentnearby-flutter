import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../utils/dio_error_mapper.dart';
import 'models/ask_models.dart';
import 'taxi_ways_strings.dart';
import 'trip_strings_a6.dart';

class TaxiWaysAskRepository {
  const TaxiWaysAskRepository();

  Future<AskResult> ask(AskDriversRequest request) async {
    final res = await ApiService.post('/taxis/ways/ask', request.toJson());
    final data = res['data'];
    return AskResult.fromJson(data is Map<String, dynamic> ? data : const {});
  }

  static String limitMessage(DioException e) {
    final headers = e.response?.headers;
    final seconds = int.tryParse(headers?.value('retry-after') ?? '') ?? 60;
    final minutes = ((seconds <= 0 ? 60 : seconds) + 59) ~/ 60;
    final left = int.tryParse(headers?.value('x-trip-asks-left') ?? '');
    final body = '${TripStringsA6.askLimitTitle}. ${TripStringsA6.askLimitBody(minutes)}';
    return left == null || left <= 0 ? body : '$body ${TripStringsA6.asksLeft(left)}.';
  }

  static String errorMessage(Object e) {
    if (e is DioException) {
      if (DioErrorMapper.isNetworkError(e)) return TaxiWaysStrings.offlineTitle;
      final status = e.response?.statusCode;
      final type = DioErrorMapper.errorType(e);
      if (status == 429) return limitMessage(e);
      if (status == 403 && type == 'TripExecutionDisabled') return TaxiWaysStrings.askPaused;
      if (status == 403 && type == 'TabInactive') return TaxiWaysStrings.taxisOff;
    }
    return DioErrorMapper.toMessage(e, TaxiWaysStrings.askFailed);
  }
}
