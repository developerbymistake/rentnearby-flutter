import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import '../config/app_constants.dart';
import '../config/app_routes.dart';
import '../utils/app_toast.dart';
import 'storage_service.dart';

class ApiService {
  static late Dio _dio;

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
          await StorageService.clearAll();
          AppToast.info('Session expired. Please log in again.');
          Get.offAllNamed(AppRoutes.otp);
        }
        handler.next(error);
      },
    ));
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data) async {
    final res = await _dio.post(path, data: data);
    return res.data;
  }

  static Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? params}) async {
    final res = await _dio.get(path, queryParameters: params);
    return res.data;
  }

  static Future<Map<String, dynamic>> put(String path, Map<String, dynamic> data) async {
    final res = await _dio.put(path, data: data);
    return res.data;
  }

  static Future<void> delete(String path) async {
    await _dio.delete(path);
  }

  static Future<Map<String, dynamic>> postFormData(String path, FormData data) async {
    final res = await _dio.post(path, data: data);
    return res.data;
  }
}
