import 'dart:convert';
import 'package:get_storage/get_storage.dart';
import '../config/app_constants.dart';
import '../models/user_model.dart';

class StorageService {
  static final _box = GetStorage();

  static String? getToken() => _box.read(AppConstants.tokenKey);

  static void saveToken(String token) => _box.write(AppConstants.tokenKey, token);

  static void clearToken() => _box.remove(AppConstants.tokenKey);

  static UserModel? getUser() {
    final data = _box.read(AppConstants.userKey);
    if (data == null) return null;
    return UserModel.fromJson(jsonDecode(data));
  }

  static void saveUser(UserModel user) =>
      _box.write(AppConstants.userKey, jsonEncode(user.toJson()));

  static void clearUser() => _box.remove(AppConstants.userKey);

  static bool get isLoggedIn => getToken() != null;

  static void clearAll() {
    _box.remove(AppConstants.tokenKey);
    _box.remove(AppConstants.userKey);
  }
}
