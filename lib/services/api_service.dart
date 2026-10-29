import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import '../config/app_constants.dart';
import '../controllers/auth_controller.dart';
import '../controllers/tab_config_controller.dart';
import 'storage_service.dart';

class ApiService {
  static late Dio _dio;
  static Future<void>? _logoutInFlight;
  static const String skipAuthExtra = 'skipAuth';
  static const String tabInactiveType = 'TabInactive';

  static Object? _errorType(Object? data) {
    final error = data is Map ? data['error'] : null;
    return error is Map ? error['type'] : null;
  }

  // Shared single-flight guard for every logout trigger (explicit logout, account deletion, a
  // forced 401) so concurrent callers all await the exact same cleanup instead of racing —
  // whichever arrives first runs it, the rest just await the same in-flight Future.
  static Future<void> runExclusiveLogout(Future<void> Function() cleanup) {
    return _logoutInFlight ??= cleanup().whenComplete(() {
      Future.delayed(const Duration(seconds: 3), () => _logoutInFlight = null);
    });
  }

  static void init() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.extra[skipAuthExtra] != true) {
          final token = StorageService.getToken();
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        if (status == 401 && error.requestOptions.extra[skipAuthExtra] != true) {
          await runExclusiveLogout(
            () => Get.find<AuthController>().forceLogout(reason: LogoutReason.sessionExpired),
          );
        } else if (status == 403 && _errorType(error.response?.data) == tabInactiveType &&
            Get.isRegistered<TabConfigController>()) {
          TabConfigController.to.load(forceRefresh: true);
        }
        handler.next(error);
      },
    ));
  }

  // A 204 No Content response (e.g. block/unblock) has no Content-Type header, so Dio's
  // transformer doesn't treat it as JSON and decodes the empty body as "" rather than null
  // (see dio's sync_transformer.dart) — a plain `res.data ?? <String, dynamic>{}` guard misses
  // that case, since "" isn't null, and returning it against this method's non-nullable Map
  // signature throws a TypeError *after* the request already succeeded on the wire, landing
  // callers in their catch block reporting failure for an action that actually went through.
  // Checking the actual runtime type covers every non-Map body, not just null.
  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data) async {
    final res = await _dio.post(path, data: data);
    return res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? params,
    CancelToken? cancelToken,
    bool skipAuth = false,
  }) async {
    final res = await _dio.get(
      path,
      queryParameters: params,
      cancelToken: cancelToken,
      options: skipAuth ? Options(extra: {skipAuthExtra: true}) : null,
    );
    return res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> put(String path, Map<String, dynamic> data) async {
    final res = await _dio.put(path, data: data);
    return res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};
  }

  static Future<void> delete(String path) async {
    await _dio.delete(path);
  }

  static Future<Map<String, dynamic>> postFormData(
    String path,
    FormData data, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final res = await _dio.post(path, data: data, onSendProgress: onSendProgress);
    return res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};
  }
}
