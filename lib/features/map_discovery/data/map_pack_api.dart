import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../config/app_constants.dart';
import '../../../services/api_service.dart';
import '../pack/map_pack_models.dart';

typedef MapPackGet = Future<Response<dynamic>> Function(String path, Map<String, String>? headers);

typedef MapPackFetchResult = ({bool notModified, String? body});

class MapPackApi {
  final MapPackGet _get;
  final String baseUrl;

  MapPackApi({MapPackGet? get, this.baseUrl = AppConstants.baseUrl})
      : _get = get ?? _defaultGet;

  static Future<Response<dynamic>> _defaultGet(String path, Map<String, String>? headers) =>
      ApiService.getRaw(path, headers: headers, responseType: ResponseType.plain);

  static const MapPackFetchResult failed = (notModified: false, body: null);

  Future<MapPackFetchResult> fetch(MapPackRef ref, {String? etag}) async {
    final path = requestPath(ref.path, baseUrl);
    if (path == null) return failed;
    final tag = etag?.trim() ?? '';
    final res = await _get(path, tag.isEmpty ? null : {'If-None-Match': '"$tag"'});
    if (res.statusCode == 304) return (notModified: true, body: null);
    if (res.statusCode != 200) return failed;
    final body = bodyOf(res.data);
    return body == null ? failed : (notModified: false, body: body);
  }

  static String? bodyOf(Object? data) {
    if (data is String) return data.trim().isEmpty ? null : data;
    if (data is Map || data is List) {
      try {
        return jsonEncode(data);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String? requestPath(String path, String baseUrl) {
    final p = path.trim();
    if (p.isEmpty || p.contains('\\')) return null;
    final lower = p.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final uri = Uri.tryParse(p);
      final base = Uri.tryParse(baseUrl);
      if (uri == null || base == null || uri.host.isEmpty) return null;
      final same = uri.scheme == base.scheme && uri.host.toLowerCase() == base.host.toLowerCase() && uri.port == base.port;
      return same && uri.userInfo.isEmpty ? p : null;
    }
    if (p.startsWith('//') || p.contains('://')) return null;
    return p.startsWith('/') ? p : '/$p';
  }
}
