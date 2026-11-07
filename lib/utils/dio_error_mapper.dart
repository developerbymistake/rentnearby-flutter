import 'package:dio/dio.dart';

/// Shared DioException-to-user-message translation, previously hand-copied as
/// `_errorMessage`/`_dioMessage` across controllers. Callers pass which
/// status codes (beyond the always-shown 400) are safe to show verbatim for their endpoint —
/// this varies per feature (e.g. chat's block/report flow treats 403 as clear,
/// user-facing messages).
class DioErrorMapper {
  const DioErrorMapper._();

  /// True for a genuine connectivity failure (timeout, dropped connection,
  /// DNS/socket-level issue reported as connectionError) — as opposed to a
  /// clean HTTP response the server chose to send (4xx/5xx). Callers that
  /// want to retry-on-transient-failure (e.g. payment verify)
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

  /// The backend's machine-readable `error.type` (e.g. `PlanLimitReached`,
  /// `ALREADY_PROCESSED`, `TabInactive`) — null if absent or the
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

  static String? serverMessage(dynamic e) {
    if (e is! DioException) return null;
    final responseData = e.response?.data;
    if (responseData is Map<String, dynamic>) {
      final error = responseData['error'];
      if (error is Map<String, dynamic>) return error['message'] as String?;
    }
    return null;
  }

  static const Set<String> _passThroughTypes = {'TooManySpotsPerDay', 'TooManySpotsForDays'};

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
        final t = responseData.trim();
        if (t.isNotEmpty && t.length <= 160 && !t.startsWith('<') && !t.startsWith('{')) message = t;
      }
      final type = errorType(e);
      final typed = type != null;
      if (message != null && _passThroughTypes.contains(type)) return message;
      if (status != null && showRawMessageForStatusCodes.contains(status) && message != null) {
        return message;
      }
      if (typed && message != null && (status == 403 || status == 409 || status == 429)) return message;
      if (status == 429) return 'Too many requests. Please wait a minute and try again.';
      if (status == 502 || status == 503 || status == 504) return 'Server is busy. Please try again in a moment.';
      if (status != null && status >= 500) {
        final ref = message == null ? null : RegExp(r'Ref ([A-Za-z0-9]{4,12})\s*$').firstMatch(message)?.group(1);
        return ref == null
            ? 'Server error. Please try again.'
            : 'Server error. Please try again. (Ref $ref)';
      }
      if (message != null) return message;
    }
    return fallback;
  }
}
