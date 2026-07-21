import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import '../config/app_constants.dart';
import '../controllers/auth_controller.dart';
import 'storage_service.dart';

class ApiService {
  static late Dio _dio;
  static late Dio _nominatimDio;
  static Future<void>? _logoutInFlight;

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
        final token = StorageService.getToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await runExclusiveLogout(
            () => Get.find<AuthController>().forceLogout(reason: LogoutReason.sessionExpired),
          );
        }
        handler.next(error);
      },
    ));

    _nominatimDio = Dio(BaseOptions(
      baseUrl: AppConstants.nominatimUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 8),
      headers: {'User-Agent': 'Bakhli/1.0 (support@bakhli.in)'},
    ));
  }

  static Future<Map<String, dynamic>?> reverseGeocode(double lat, double lng) async {
    final res = await _nominatimDio.get<Map<String, dynamic>>(
      '/reverse',
      queryParameters: {
        'format': 'jsonv2',
        'lat': lat.toStringAsFixed(6),
        'lon': lng.toStringAsFixed(6),
      },
    );
    return res.data;
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

  static Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? params}) async {
    final res = await _dio.get(path, queryParameters: params);
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
