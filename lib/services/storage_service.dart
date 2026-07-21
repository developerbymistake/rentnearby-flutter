import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';
import '../config/app_constants.dart';
import '../models/user_model.dart';

class StorageService {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
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
    try {
      await clearToken();
    } catch (_) {}
    clearUser();
    clearFcmToken();
    clearAllChatStackedLines();
  }

  static Future<void> saveFcmToken(String token) async =>
      _box.write(AppConstants.fcmTokenKey, token);

  static String? getFcmToken() =>
      _box.read<String>(AppConstants.fcmTokenKey);

  static void clearFcmToken() =>
      _box.remove(AppConstants.fcmTokenKey);

  static void saveNotifPromptDismissedAt() =>
      _box.write(AppConstants.notifPromptDismissedKey, DateTime.now().toIso8601String());

  static DateTime? getNotifPromptDismissedAt() {
    final val = _box.read<String>(AppConstants.notifPromptDismissedKey);
    if (val == null) return null;
    return DateTime.tryParse(val);
  }

  static void clearNotifPromptDismissedAt() =>
      _box.remove(AppConstants.notifPromptDismissedKey);

  static Future<void> saveSubscribedDistrictTopic(String topic) async =>
      _box.write(AppConstants.subscribedDistrictTopicKey, topic);

  static String? getSubscribedDistrictTopic() =>
      _box.read<String>(AppConstants.subscribedDistrictTopicKey);

  static void clearSubscribedDistrictTopic() =>
      _box.remove(AppConstants.subscribedDistrictTopicKey);

  // ── District-switch feature: cached reference data ─────────────────────────
  // Caches the *reference* lists (all districts, cities per district) so the
  // location picker opens instantly. Never stores the user's manually-picked
  // browsing district/city — that is in-memory only (see LocationController)
  // and is intentionally never persisted here.

  static Future<void> saveDistrictsCache(List<Map<String, dynamic>> items) async {
    await _box.write(AppConstants.districtsCacheKey, items);
    await _box.write('${AppConstants.districtsCacheKey}_savedAt', DateTime.now().toIso8601String());
  }

  static List<Map<String, dynamic>>? getDistrictsCache() {
    final raw = _box.read<List>(AppConstants.districtsCacheKey);
    return raw?.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static DateTime? getDistrictsCacheSavedAt() {
    final val = _box.read<String>('${AppConstants.districtsCacheKey}_savedAt');
    return val == null ? null : DateTime.tryParse(val);
  }

  static Future<void> saveCitiesCache(String districtId, List<Map<String, dynamic>> items) async {
    final key = '${AppConstants.citiesCacheKeyPrefix}$districtId';
    await _box.write(key, items);
    await _box.write('${key}_savedAt', DateTime.now().toIso8601String());
  }

  static List<Map<String, dynamic>>? getCitiesCache(String districtId) {
    final raw = _box.read<List>('${AppConstants.citiesCacheKeyPrefix}$districtId');
    return raw?.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static DateTime? getCitiesCacheSavedAt(String districtId) {
    final val = _box.read<String>('${AppConstants.citiesCacheKeyPrefix}${districtId}_savedAt');
    return val == null ? null : DateTime.tryParse(val);
  }

  // ── Chat notification stacking ──────────────────────────────────────────
  // See AppConstants.chatStackedLinesKeyPrefix — persists recent messages (text + the time
  // each one arrived) per conversation across separate background-isolate invocations of the
  // FCM handler. Each entry is stored as a {'text': String, 'timestamp': int (epoch ms)} map
  // so MessagingStyleInformation can render every stacked line with its own real timestamp
  // instead of stamping all of them with the notification's current display time.

  static Future<void> saveChatStackedLines(
    String conversationId,
    List<Map<String, dynamic>> messages,
  ) async =>
      _box.write('${AppConstants.chatStackedLinesKeyPrefix}$conversationId', messages);

  static List<Map<String, dynamic>> getChatStackedLines(String conversationId) =>
      _box.read<List>('${AppConstants.chatStackedLinesKeyPrefix}$conversationId')
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? <Map<String, dynamic>>[];

  static void clearChatStackedLines(String conversationId) =>
      _box.remove('${AppConstants.chatStackedLinesKeyPrefix}$conversationId');

  /// Removes every per-conversation stacked-lines buffer, not just one — called on logout so
  /// these don't accumulate indefinitely across the account's lifetime (they're otherwise only
  /// ever pruned by actually opening that specific conversation) and so a stale buffer can't
  /// leak into a notification shown after a different account logs in on the same device.
  static void clearAllChatStackedLines() {
    final keys = _box.getKeys().where(
        (k) => k is String && k.startsWith(AppConstants.chatStackedLinesKeyPrefix));
    for (final key in keys.toList()) {
      _box.remove(key as String);
    }
  }
}
