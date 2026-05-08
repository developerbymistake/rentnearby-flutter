import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';
import '../config/app_constants.dart';
import '../models/user_model.dart';

class StorageService {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static final _box = GetStorage();
  static String? _cachedToken;

  static Future<void> init() async {
    _cachedToken = await _secureStorage.read(key: AppConstants.tokenKey);
  }

  static String? getToken() => _cachedToken;

  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _secureStorage.write(key: AppConstants.tokenKey, value: token);
  }

  static Future<void> clearToken() async {
    _cachedToken = null;
    await _secureStorage.delete(key: AppConstants.tokenKey);
  }

  static UserModel? getUser() {
    final data = _box.read(AppConstants.userKey);
    if (data == null) return null;
    return UserModel.fromJson(jsonDecode(data));
  }

  static void saveUser(UserModel user) =>
      _box.write(AppConstants.userKey, jsonEncode(user.toJson()));

  static void clearUser() => _box.remove(AppConstants.userKey);

  static bool get isLoggedIn => _cachedToken != null;

  static Future<void> clearAll() async {
    await clearToken();
    clearUser();
  }
}
