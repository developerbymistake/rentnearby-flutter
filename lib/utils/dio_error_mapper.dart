import 'package:dio/dio.dart';

/// Shared DioException-to-user-message translation, previously hand-copied as
/// `_errorMessage`/`_dioMessage` across listing/plot/wallet/chat controllers. Callers pass which
/// status codes (beyond the always-shown 400) are safe to show verbatim for their endpoint —
/// this varies per feature (e.g. wallet's redeem-code flow also treats 404/409 as clear,
/// user-facing messages; chat's block/report flow treats 403 the same way).
class DioErrorMapper {
  const DioErrorMapper._();

  static String toMessage(
    dynamic e,
    String fallback, {
    Set<int> showRawMessageForStatusCodes = const {400},
  }) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your network.';
      }
      final status = e.response?.statusCode;
      String? message;
      final responseData = e.response?.data;
      if (responseData is Map<String, dynamic>) {
        message = responseData['error']?['message'] as String? ??
            responseData['message'] as String?;
      } else if (responseData is String) {
        message = responseData;
      }
      if (status != null && showRawMessageForStatusCodes.contains(status) && message != null) {
        return message;
      }
      if (status == 429) return 'Too many attempts. Please try again later.';
      if (status != null && status >= 500) return 'Server error. Please try again.';
      if (message != null) return message;
    }
    return fallback;
  }
}
