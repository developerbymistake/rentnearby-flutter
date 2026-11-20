import 'package:dio/dio.dart';

import '../../../utils/dio_error_mapper.dart';
import 'buddy_json.dart';

sealed class BuddyResult<T> {
  const BuddyResult();

  T? get valueOrNull => switch (this) {
        BuddyOk<T>(:final value) => value,
        _ => null,
      };

  bool get isOk => this is BuddyOk<T>;

  static BuddyResult<T> fromError<T>(Object error) {
    if (error is! DioException) return BuddyFailed<T>(message: error.toString());
    final response = error.response;
    if (DioErrorMapper.isNetworkError(error) || response == null) return BuddyOffline<T>();
    final status = response.statusCode ?? 0;
    final body = BuddyJson.map(response.data);
    final err = BuddyJson.map(body['error']);
    if (status >= 500) return BuddyFailed<T>(message: BuddyJson.str(err['message'], 'Server error'));
    return BuddyRefused<T>(
      type: BuddyJson.strOrNull(err['type']),
      statusCode: status,
      message: BuddyJson.strOrNull(err['message']),
      data: BuddyJson.map(body['data']),
      retryAfterSeconds: status == 429 ? _retryAfter(response) : null,
    );
  }

  static int _retryAfter(Response<dynamic> response) {
    final seconds = int.tryParse(response.headers.value('retry-after')?.trim() ?? '');
    return seconds == null || seconds < 1 ? 1 : seconds;
  }
}

class BuddyOk<T> extends BuddyResult<T> {
  const BuddyOk(this.value);

  final T value;
}

class BuddyRefused<T> extends BuddyResult<T> {
  const BuddyRefused({required this.type, required this.statusCode, this.message, this.data = const {}, this.retryAfterSeconds});

  final String? type;
  final int statusCode;
  final String? message;
  final Map<String, dynamic> data;
  final int? retryAfterSeconds;

  bool get rateLimited => statusCode == 429;

  BuddyRefused<R> cast<R>() =>
      BuddyRefused<R>(type: type, statusCode: statusCode, message: message, data: data, retryAfterSeconds: retryAfterSeconds);
}

class BuddyOffline<T> extends BuddyResult<T> {
  const BuddyOffline();
}

class BuddyFailed<T> extends BuddyResult<T> {
  const BuddyFailed({required this.message});

  final String message;
}
