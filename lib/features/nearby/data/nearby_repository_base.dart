import '../../../services/api_service.dart';
import '../models/nearby_models.dart';

abstract class NearbyRepositoryBase<T> {
  const NearbyRepositoryBase();

  Future<NearbyPage<T>> getPage(String path, Map<String, dynamic> params, T Function(Map<String, dynamic>) parse) async {
    final res = await ApiService.get(path, params: params);
    return pageFromResponse<T>(res, parse);
  }

  static List<T> parseList<T>(Object? raw, T Function(Map<String, dynamic>) parse) {
    final out = <T>[];
    if (raw is! List) return out;
    for (final e in raw) {
      if (e is! Map) continue;
      try {
        out.add(parse(Map<String, dynamic>.from(e)));
      } catch (_) {}
    }
    return out;
  }

  static NearbyPage<T> pageFromResponse<T>(Map<String, dynamic> res, T Function(Map<String, dynamic>) parse) {
    final raw = res['data'];
    final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final header = data['header'];
    final token = data['nextToken'];
    return NearbyPage<T>(
      header: NearbyHeader.fromJson(header is Map ? Map<String, dynamic>.from(header) : null),
      featured: parseList(data['featured'], parse),
      items: parseList(data['items'], parse),
      hasMore: data['hasMore'] == true,
      nextToken: token is String && token.isNotEmpty ? token : null,
    );
  }
}
