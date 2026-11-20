import '../../../utils/network_retry.dart';
import 'buddy_json.dart';
import 'buddy_result.dart';
import 'models/person_models.dart';

abstract final class BuddyApiBase {
  static Future<BuddyResult<T>> run<T>(Future<T> Function() call) async {
    try {
      return BuddyOk<T>(await call());
    } catch (e) {
      return BuddyResult.fromError<T>(e);
    }
  }

  static Future<T> read<T>(Future<T> Function() call) => withRetry(call);

  static Map<String, dynamic> dataOf(Map<String, dynamic> res) => BuddyJson.map(res['data']);

  static List<dynamic> listOf(Map<String, dynamic> res) {
    final d = res['data'];
    return d is List ? d : const [];
  }

  static BuddyCursorPage<T> pageOf<T>(Map<String, dynamic> res, T Function(Map<String, dynamic>) parse) =>
      BuddyCursorPage.fromJson(dataOf(res), parse);

  static Map<String, dynamic> query(Map<String, Object?> params) =>
      {for (final e in params.entries) if (e.value != null) e.key: e.value};
}
