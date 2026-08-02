import 'dio_error_mapper.dart';

Future<T> withRetry<T>(Future<T> Function() request) async {
  const backoff = [Duration(seconds: 2), Duration(seconds: 5)];
  for (final delay in backoff) {
    try {
      return await request();
    } catch (e) {
      if (!DioErrorMapper.isNetworkError(e)) rethrow;
      await Future.delayed(delay);
    }
  }
  return request();
}
