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

  // Excludes must use the `!key:value` form; `key:!value` is not Photon syntax.
  static const _osmTagFilter = [
    'place',
    'tourism',
    'railway:station',
    'amenity:place_of_worship',
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
    '!place:hamlet',
    '!place:locality',
    '!tourism:information',
    '!tourism:artwork',
    '!tourism:picnic_site',
    '!tourism:hotel',
    '!tourism:guest_house',
    '!tourism:hostel',
    '!tourism:motel',
    '!tourism:apartment',
    '!tourism:chalet',
    '!tourism:camp_site',
  ];

  static int _typeRank(String? osmValue) => switch (osmValue) {
        'city' => 0,
        'town' => 1,
        'suburb' => 2,
        'village' => 3,
        _ => 4,
      };

  static List<PlaceResult> _rank(List<PlaceResult> results, String? preferState) {
    final prefer = preferState?.trim().toLowerCase();
    int stateRank(PlaceResult r) =>
        prefer == null || prefer.isEmpty || r.state?.toLowerCase() == prefer ? 0 : 1;
    final indexed = results.indexed.toList()
      ..sort((a, b) {
        var c = stateRank(a.$2).compareTo(stateRank(b.$2));
        if (c == 0) c = _typeRank(a.$2.osmValue).compareTo(_typeRank(b.$2.osmValue));
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    return [for (final e in indexed) e.$2];
  }

  static Future<List<PlaceResult>> search(String query,
      {LatLng? bias, int limit = 8, String? preferState}) async {
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

    final results = features.cast<Map<String, dynamic>>().map(PlaceResult.fromFeature).toList();
    return _rank(results, preferState);
  }
}
