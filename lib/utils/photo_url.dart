import '../config/app_constants.dart';

abstract final class PhotoUrl {
  static String? parse(Object? raw) {
    if (raw is! String) return null;
    final u = raw.trim();
    if (u.isEmpty) return null;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    if (u.startsWith('/') && !u.startsWith('//')) return '${AppConstants.serverUrl}$u';
    return null;
  }
}
