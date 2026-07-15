import 'package:dio/dio.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../config/app_constants.dart';
import '../models/place_result_model.dart';

/// Self-hosted Photon (autocomplete geocoder) client. Deliberately isolated
/// from [ApiService] — its own Dio instance, no auth, no shared bootstrap
/// ordering, no debounce/error-handling (the caller owns both). A single
/// stateless call: query in, place list out.
class PhotonService {
  static final Dio _photonDio = Dio(BaseOptions(
    baseUrl: AppConstants.photonUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 8),
    headers: {'User-Agent': 'Bakhli/1.0 (support@bakhli.in)'},
  ));

  // Road/footpath/terrain noise — not useful results for an area/locality
  // search. Single choke point if more noise types show up later.
  static const _excludedOsmKeys = {'highway', 'natural', 'waterway', 'railway'};

  static Future<List<PlaceResult>> search(String query, {LatLng? bias, int limit = 8}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final params = <String, dynamic>{'q': trimmed, 'limit': limit};
    if (bias != null) {
      params['lat'] = bias.latitude;
      params['lon'] = bias.longitude;
    }

    final res = await _photonDio.get<Map<String, dynamic>>('/api', queryParameters: params);
    final features = (res.data?['features'] as List?) ?? [];

    return features
        .cast<Map<String, dynamic>>()
        .where((f) {
          final key = f['properties']?['osm_key'] as String?;
          return key == null || !_excludedOsmKeys.contains(key);
        })
        .map(PlaceResult.fromFeature)
        .toList();
  }
}
