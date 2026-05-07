import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show Color;
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import '../config/app_constants.dart';
import '../config/app_routes.dart';
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
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          StorageService.clearAll();
          Get.snackbar(
            'Session Expired',
            'Another device signed in with your account.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: const Color(0xFF1E3A8A),
            colorText: const Color(0xFFFFFFFF),
            duration: const Duration(seconds: 3),
          );
          Future.delayed(const Duration(milliseconds: 600), () {
            Get.offAllNamed(AppRoutes.otp);
          });
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
