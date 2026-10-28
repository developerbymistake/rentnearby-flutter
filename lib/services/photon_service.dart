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
    'landuse:residential',
    'amenity',
    'tourism',
    'railway:station',
    'man_made:tower',
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
    '!amenity:bench',
    '!amenity:parking',
    '!amenity:parking_space',
    '!amenity:parking_entrance',
    '!amenity:bicycle_parking',
    '!amenity:motorcycle_parking',
    '!amenity:toilets',
    '!amenity:waste_basket',
    '!amenity:waste_disposal',
    '!amenity:recycling',
    '!amenity:drinking_water',
    '!amenity:vending_machine',
    '!amenity:atm',
    '!amenity:shelter',
    '!amenity:telephone',
    '!amenity:post_box',
    '!amenity:charging_station',
    '!amenity:grit_bin',
    '!amenity:bbq',
    '!amenity:hunting_stand',
    '!tourism:information',
    '!tourism:artwork',
    '!tourism:picnic_site',
  ];

  static const _bbox = '77.5,28.7,81.1,31.5';

  static Future<List<PlaceResult>> search(String query, {LatLng? bias, int limit = 8}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final params = <String, dynamic>{
      'q': trimmed,
      'limit': limit,
      'osm_tag': _osmTagFilter,
      'bbox': _bbox,
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
