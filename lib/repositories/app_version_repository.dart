import 'dart:async';
import 'package:dio/dio.dart';
import '../config/app_constants.dart';
import '../models/app_version_config_model.dart';
import '../services/api_service.dart';

/// GET /config/app-version — anonymous, sent without a Bearer token. No caching
/// here; AppVersionController owns persistence and throttling.
class AppVersionRepository {
  /// Throws on timeout, transport/HTTP errors and malformed envelopes.
  Future<AppVersionConfigModel> fetch({required String platform, required int installedBuild}) async {
    final cancelToken = CancelToken();
    try {
      final res = await ApiService.get(
        '/config/app-version',
        params: {
          'platform': platform,
          if (installedBuild > 0) 'build': installedBuild,
        },
        cancelToken: cancelToken,
        skipAuth: true,
      ).timeout(AppConstants.appVersionCheckTimeout);
      final data = res['data'];
      if (data is! Map) throw const FormatException('app-version: missing "data"');
      return AppVersionConfigModel.fromJson(Map<String, dynamic>.from(data), fetchedAt: DateTime.now());
    } on TimeoutException {
      cancelToken.cancel('app-version check timed out');
      rethrow;
    }
  }

  /// A 404 means the route itself is gone (rollback/rename), treated as an
  /// explicit "no update config" verdict rather than a transient failure.
  static bool isNoConfigResponse(Object error) =>
      error is DioException && error.response?.statusCode == 404;
}
