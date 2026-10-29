import 'package:dio/dio.dart';
import '../utils/dio_error_mapper.dart';

sealed class GoLiveResult {
  const GoLiveResult();

  static GoLiveResult fromData(Map<String, dynamic> data) {
    final limits = data['limits'] as Map<String, dynamic>? ?? const {};
    final limit = (limits['listingLimit'] as num?)?.toInt() ?? 1;
    final live = (limits['live'] as num?)?.toInt() ?? 0;
    if (data['liveRequestStatus'] == 'Pending') return GoLiveSubmittedForReview(limit: limit, live: live);
    return GoLiveSuccess(
      validUntil: data['validUntil'] != null ? DateTime.tryParse(data['validUntil'] as String) : null,
      limit: limit,
      live: live,
    );
  }

  static GoLiveResult fromError(DioException e, {required String noun}) {
    final status = e.response?.statusCode;
    final type = DioErrorMapper.errorType(e);
    final body = e.response?.data;
    final message = DioErrorMapper.toMessage(e, 'Could not go live. Try again.',
        showRawMessageForStatusCodes: const {400, 403, 409});
    if (status == 409 && type == 'PlanLimitReached') {
      final d = body is Map<String, dynamic> ? body['data'] as Map<String, dynamic>? : null;
      return GoLiveLimitReached(
        limit: (d?['limit'] as num?)?.toInt() ?? 1,
        live: (d?['live'] as num?)?.toInt() ?? 1,
      );
    }
    if (status == 403 && type == 'ListingPausedByAdmin') return GoLivePausedByAdmin(message);
    if (status == 409 && type == 'CONCURRENT_UPDATE') {
      return GoLiveConcurrentUpdate('This $noun was just changed. Please retry.');
    }
    return GoLiveFailure(message);
  }
}

class GoLiveSuccess extends GoLiveResult {
  final DateTime? validUntil;
  final int limit;
  final int live;
  const GoLiveSuccess({required this.validUntil, required this.limit, required this.live});
}

class GoLiveSubmittedForReview extends GoLiveResult {
  final int limit;
  final int live;
  const GoLiveSubmittedForReview({required this.limit, required this.live});
}

class GoLiveLimitReached extends GoLiveResult {
  final int limit;
  final int live;
  const GoLiveLimitReached({required this.limit, required this.live});
}

class GoLivePausedByAdmin extends GoLiveResult {
  final String message;
  const GoLivePausedByAdmin(this.message);
}

class GoLiveConcurrentUpdate extends GoLiveResult {
  final String message;
  const GoLiveConcurrentUpdate(this.message);
}

class GoLiveFailure extends GoLiveResult {
  final String message;
  const GoLiveFailure(this.message);
}
