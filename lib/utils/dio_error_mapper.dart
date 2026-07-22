import 'package:dio/dio.dart';

/// Shared DioException-to-user-message translation, previously hand-copied as
/// `_errorMessage`/`_dioMessage` across listing/plot/wallet/chat controllers. Callers pass which
/// status codes (beyond the always-shown 400) are safe to show verbatim for their endpoint —
/// this varies per feature (e.g. wallet's redeem-code flow also treats 404/409 as clear,
/// user-facing messages; chat's block/report flow treats 403 the same way).
class DioErrorMapper {
  const DioErrorMapper._();

  /// True for a genuine connectivity failure (timeout, dropped connection,
  /// DNS/socket-level issue reported as connectionError) — as opposed to a
  /// clean HTTP response the server chose to send (4xx/5xx). Callers that
  /// want to retry-on-transient-failure (e.g. coin-pack verify-payment)
  /// should gate on this, not on "any exception at all" — retrying a clean
  /// rejection (bad signature, etc.) wastes calls without helping. Does NOT
  /// include sendTimeout in the original 3-type check this was extracted
  /// from — added here since a slow upload during checkout is the same kind
  /// of transient failure as the others.
  static bool isNetworkError(dynamic e) {
    if (e is! DioException) return false;
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  /// The backend's machine-readable `error.type` (e.g. `INSUFFICIENT_BALANCE`,
  /// `ALREADY_PROCESSED`, `RECENT_PURCHASE_DETECTED`) — null if absent or the
  /// response isn't in the expected `ApiResponse` envelope shape.
  static String? errorType(dynamic e) {
    if (e is! DioException) return null;
    final responseData = e.response?.data;
    if (responseData is Map<String, dynamic>) {
      final error = responseData['error'];
      if (error is Map<String, dynamic>) return error['type'] as String?;
    }
    return null;
  }

  static String toMessage(
    dynamic e,
    String fallback, {
    Set<int> showRawMessageForStatusCodes = const {400},
  }) {
    if (e is DioException) {
      if (isNetworkError(e)) {
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
