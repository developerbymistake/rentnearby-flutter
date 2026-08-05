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
    pruneStaleChatStackedLines();
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

  static void saveInstallReferrerConsumed() =>
      _box.write(AppConstants.installReferrerConsumedKey, true);

  static bool getInstallReferrerConsumed() =>
      _box.read<bool>(AppConstants.installReferrerConsumedKey) ?? false;

  // Generic pair, not one method per tour — tour_registry.dart already carries
  // each tour's storage key as data, so a hand-written getter/setter per tour
  // here would just relocate that duplication rather than remove it.
  static bool getTourSeen(String key) => _box.read<bool>(key) ?? false;

  static void saveTourSeen(String key) => _box.write(key, true);

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
    // Same unconstrained-`getKeys<T>()`-into-chained-generics hazard documented in detail on
    // pruneStaleChatStackedLines below (AOT-only, invisible in debug) — pin T explicitly and use a
    // plain typed loop instead of piping the bare call into `.where()`.
    final prefix = AppConstants.chatStackedLinesKeyPrefix;
    final Iterable rawKeys = _box.getKeys<Iterable>();
    final List<String> keys = [];
    for (final k in rawKeys) {
      if (k is String && k.startsWith(prefix)) keys.add(k);
    }
    for (final key in keys) {
      _box.remove(key);
    }
  }

  /// Bounds the chat-stacked-lines buffers so a long-lived login session cannot accumulate one entry per
  /// distinct conversation forever for conversations that receive pushes but are never opened (the only
  /// other removal paths are opening that conversation, or logout). Two layers: age (a conversation gone
  /// quiet for a week has nothing useful left to stack) and a hard count cap as a backstop. Called once per
  /// cold start from init() -- this is a slow-accumulation problem across app lifetime, not a within-session
  /// one, so a per-launch sweep is enough.
  static void pruneStaleChatStackedLines() {
    final prefix = AppConstants.chatStackedLinesKeyPrefix;

    // GetStorage's `getKeys<T>()` is `T getKeys<T>() => subject.value.keys as T;` — an unconstrained
    // generic with an internal unsafe cast. Call it with no explicit type argument (as a bare
    // `_box.getKeys()` piped straight into `.where()`) and Dart can't find a concrete T from context,
    // so the whole call — and every `.where()`/`.map()`/`.toList()` chained onto it — resolves via
    // dynamic dispatch instead of a statically-known Iterable<String>. That's invisible in debug/JIT,
    // but AOT release compilation reifies the chain's actual result as List<dynamic> regardless of
    // the closures' own return types, so assigning it to a declared List<String> throws instead of
    // silently coercing. Pinning T explicitly to Iterable up front, then building the list with a
    // plain typed loop instead of chained generics, removes every inference step AOT could get wrong.
    final Iterable rawKeys = _box.getKeys<Iterable>();
    final List<String> keys = [];
    for (final k in rawKeys) {
      if (k is String && k.startsWith(prefix)) keys.add(k);
    }
    final List<MapEntry<String, int>> entries = keys.map((key) {
      final messages = _box.read<List>(key) ?? const [];
      final newest = messages.fold<int>(0, (acc, e) {
        final ts = (Map<String, dynamic>.from(e as Map)['timestamp'] as num?)?.toInt() ?? 0;
        return ts > acc ? ts : acc;
      });
      return MapEntry<String, int>(key, newest);
    }).toList();

    final cutoff = DateTime.now().subtract(AppConstants.chatStackedLinesMaxAge).millisecondsSinceEpoch;
    final stale = entries.where((MapEntry<String, int> e) => e.value < cutoff).map((e) => e.key);
    for (final key in stale) {
      _box.remove(key);
    }

    final remaining = entries.where((MapEntry<String, int> e) => e.value >= cutoff).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (remaining.length > AppConstants.chatStackedLinesMaxConversations) {
      for (final e in remaining.skip(AppConstants.chatStackedLinesMaxConversations)) {
        _box.remove(e.key);
      }
    }
  }
}
