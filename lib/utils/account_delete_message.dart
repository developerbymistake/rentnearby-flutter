import 'package:dio/dio.dart';

import 'dio_error_mapper.dart';

class AccountDeleteMessage {
  const AccountDeleteMessage._();

  static const errorType = 'AccountHasActiveItems';

  static const _byCode = <String, String>{
    'ActiveTaxiBooking': 'You have an active taxi booking. You can delete your account after it ends.',
    'ActiveStayBooking': 'You have an active stay booking. You can delete your account after it ends.',
    'SelectedTaxiOffer': 'A traveller has chosen you. Confirm or decline the trip first.',
    'OpenTaxiRequest': 'You have an open taxi request. Cancel it first.',
    'OpenStayEnquiry': 'You have an open stay enquiry. Close it first.',
    'LiveListing': 'Take your listing offline first.',
  };

  static const fallback = 'You cannot delete your account right now. Finish your active items first.';

  /// Null when [e] is not a 409 AccountHasActiveItems.
  static String? from(dynamic e) => lines(e)?.join('\n');

  /// One message per blocking reason; null when [e] is not a 409 AccountHasActiveItems.
  static List<String>? lines(dynamic e) {
    if (e is! DioException || e.response?.statusCode != 409) return null;
    if (DioErrorMapper.errorType(e) != errorType) return null;
    final data = e.response?.data;
    final out = <String>[];
    final reasons = data is Map ? (data['data'] is Map ? (data['data'] as Map)['reasons'] : null) : null;
    if (reasons is List) {
      for (final r in reasons) {
        if (r is! Map) continue;
        final code = r['code'];
        final server = r['message'];
        final line = _byCode[code] ?? (server is String && server.trim().isNotEmpty ? server : null);
        if (line != null && !out.contains(line)) out.add(line);
      }
    }
    if (out.isEmpty) {
      final msg = data is Map && data['error'] is Map ? (data['error'] as Map)['message'] : null;
      return [msg is String && msg.trim().isNotEmpty ? msg : fallback];
    }
    return out;
  }
}
