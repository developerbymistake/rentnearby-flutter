import '../config/app_constants.dart';

class AppVersionConfigModel {
  final String platform;
  final bool enabled;
  final int minBuild;
  final String minVersionName;
  final int latestBuild;
  final String latestVersionName;
  final String? storeUrl;
  final String? message;
  final Duration forceCacheMaxAge;
  final DateTime fetchedAt;

  const AppVersionConfigModel({
    required this.platform,
    required this.enabled,
    required this.minBuild,
    required this.minVersionName,
    required this.latestBuild,
    required this.latestVersionName,
    required this.storeUrl,
    required this.message,
    required this.forceCacheMaxAge,
    required this.fetchedAt,
  });

  /// Strict: throws [FormatException] when `enabled` is not a bool, or when an
  /// enabled config lacks integer build numbers. [fetchedAt] overrides the
  /// persisted `fetchedAt` (pass it for a fresh network response).
  factory AppVersionConfigModel.fromJson(Map<String, dynamic> j, {DateTime? fetchedAt}) {
    final enabled = j['enabled'];
    if (enabled is! bool) {
      throw const FormatException('app-version: "enabled" must be a bool');
    }
    final minBuild = j['minBuildNumber'];
    final latestBuild = j['latestBuildNumber'];
    if (enabled && (minBuild is! int || latestBuild is! int)) {
      throw const FormatException('app-version: build numbers must be integers');
    }
    final rawFetchedAt = j['fetchedAt'];
    return AppVersionConfigModel(
      platform: _string(j['platform']),
      enabled: enabled,
      minBuild: minBuild is int ? minBuild : 0,
      minVersionName: _string(j['minVersionName']),
      latestBuild: latestBuild is int ? latestBuild : 0,
      latestVersionName: _string(j['latestVersionName']),
      storeUrl: _optionalString(j['storeUrl']),
      message: _optionalString(j['message']),
      forceCacheMaxAge: _maxAge(j['forceCacheMaxAgeHours']),
      fetchedAt: fetchedAt ??
          (rawFetchedAt is String ? DateTime.tryParse(rawFetchedAt) : null) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'enabled': enabled,
        'minBuildNumber': minBuild,
        'minVersionName': minVersionName,
        'latestBuildNumber': latestBuild,
        'latestVersionName': latestVersionName,
        'storeUrl': storeUrl,
        'message': message,
        'forceCacheMaxAgeHours': forceCacheMaxAge.inHours,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  /// Whether a FORCE verdict derived from this config may still be enforced
  /// without a fresh server response.
  bool isForceEnforceableAt(DateTime now) {
    if (fetchedAt.isAfter(now.add(const Duration(days: 1)))) return false;
    return now.difference(fetchedAt) < forceCacheMaxAge;
  }

  static String _string(Object? v) => v is String ? v.trim() : '';

  static String? _optionalString(Object? v) {
    if (v is! String) return null;
    final trimmed = v.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Duration _maxAge(Object? hours) {
    if (hours is! int || hours <= 0) return AppConstants.defaultForceCacheMaxAge;
    final age = Duration(hours: hours);
    return age > AppConstants.maxForceCacheMaxAge ? AppConstants.maxForceCacheMaxAge : age;
  }
}
