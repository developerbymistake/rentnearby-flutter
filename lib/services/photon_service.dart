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

  // Server-side filter: only real settlements/localities (OSM `place` key),
  // minus place values that aren't a useful pinpoint-on-map result for a
  // property search (administrative rollups, uninhabited/geographic values).
  // Single choke point if the allow/deny list needs to change later.
  //
  // `landuse:residential` is a separate allow rule, independent of the
  // `place:*` excludes above — some planned-city sectors (e.g. Noida/Greater
  // Noida "Sector 135") are mapped as a named `landuse=residential` polygon
  // instead of a `place=*` node, so they're invisible without this. It does
  // not reopen individual houses/buildings: those use `building`/`amenity`
  // keys, never `landuse`, so they stay excluded exactly as before.
  static const _osmTagFilter = [
    'place',
    'landuse:residential',
    '!place:county',
    '!place:state',
    '!place:country',
    '!place:region',
    '!place:province',
    '!place:island',
    '!place:islet',
    '!place:archipelago',
    '!place:polder',
    '!place:allotments',
    '!place:farm',
    '!place:isolated_dwelling',
    '!place:house',
    '!place:district',
  ];

  static Future<List<PlaceResult>> search(String query, {LatLng? bias, int limit = 8}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final params = <String, dynamic>{
      'q': trimmed,
      'limit': limit,
      'osm_tag': _osmTagFilter,
    };
    if (bias != null) {
      params['lat'] = bias.latitude;
      params['lon'] = bias.longitude;
    }

    final res = await _photonDio.get<Map<String, dynamic>>('/api', queryParameters: params);
    final features = (res.data?['features'] as List?) ?? [];

    return features.cast<Map<String, dynamic>>().map(PlaceResult.fromFeature).toList();
  }
}
