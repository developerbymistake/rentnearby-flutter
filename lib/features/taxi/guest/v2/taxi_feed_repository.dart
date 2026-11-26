import 'package:dio/dio.dart';
import '../../../../services/api_service.dart';
import '../../../../utils/dio_error_mapper.dart';
import '../../../nearby/data/nearby_repository_base.dart';
import '../../../nearby/models/nearby_models.dart';
import '../../models/taxi_browse_item.dart';
import 'taxi_journey_date.dart';
import 'taxi_popular_routes.dart';
import 'taxi_search_strings.dart';

class TaxiFeedItem {
  final TaxiBrowseItem item;
  final NearbyDistance? distance;
  final bool listedForRoute;

  const TaxiFeedItem({required this.item, this.distance, this.listedForRoute = false});

  String get id => item.id;

  factory TaxiFeedItem.fromJson(Map<String, dynamic> j) => TaxiFeedItem(
        item: TaxiBrowseItem.fromJson(j),
        distance: NearbyDistance.fromJson(j),
        listedForRoute: j['listedForRoute'] == true,
      );
}

abstract final class TaxiTierKey {
  static const onRoute = 'onRoute';
  static const passing = 'passing';
  static const basedNearFrom = 'basedNearFrom';
  static const inTo = 'inTo';
  static const order = [onRoute, passing, basedNearFrom, inTo];
  static const routeDrivers = [onRoute, passing];
}

class TaxiTier {
  final String key;
  final String headerKey;
  final NearbyHeader? header;
  final List<TaxiFeedItem> items;
  final bool hasMore;
  final String? nextToken;
  final bool collapsed;

  const TaxiTier({
    required this.key,
    this.headerKey = '',
    this.header,
    this.items = const [],
    this.hasMore = false,
    this.nextToken,
    this.collapsed = false,
  });

  bool get isEmpty => items.isEmpty;

  TaxiTier copyWith({List<TaxiFeedItem>? items, bool? hasMore, String? nextToken, bool? collapsed}) => TaxiTier(
        key: key,
        headerKey: headerKey,
        header: header,
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        nextToken: nextToken,
        collapsed: collapsed ?? this.collapsed,
      );

  factory TaxiTier.fromJson(Map<String, dynamic> j) {
    final token = j['nextToken'];
    final header = j['header'];
    return TaxiTier(
      key: j['key'] as String? ?? '',
      headerKey: j['headerKey'] as String? ?? '',
      header: header is Map ? NearbyHeader.fromJson(Map<String, dynamic>.from(header)) : null,
      items: NearbyRepositoryBase.parseList(j['items'], TaxiFeedItem.fromJson),
      hasMore: j['hasMore'] == true,
      nextToken: token is String && token.isNotEmpty ? token : null,
      collapsed: j['collapsed'] == true,
    );
  }
}

abstract final class TaxiRouteSort {
  static const nearest = 'nearest';
  static const cheapest = 'cheapest';
  static const all = [nearest, cheapest];
}

class TaxiRouteFeed {
  final NearbyHeader header;
  final List<TaxiTier> tiers;
  final String? date;
  final int? freeCount;

  const TaxiRouteFeed({this.header = NearbyHeader.empty, this.tiers = const [], this.date, this.freeCount});

  bool get isEmpty => tiers.every((t) => t.isEmpty);

  bool get hasRouteDrivers => tiers.any((t) => TaxiTierKey.routeDrivers.contains(t.key) && t.items.isNotEmpty);

  TaxiTier? tier(String key) {
    for (final t in tiers) {
      if (t.key == key) return t;
    }
    return null;
  }

  TaxiRouteFeed withTiers(List<TaxiTier> next) => TaxiRouteFeed(header: header, tiers: next, date: date, freeCount: freeCount);

  factory TaxiRouteFeed.fromResponse(Map<String, dynamic> res) {
    final raw = res['data'];
    final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final header = data['header'];
    final tiers = <TaxiTier>[];
    final list = data['tiers'];
    if (list is List) {
      for (final e in list) {
        if (e is! Map) continue;
        try {
          tiers.add(TaxiTier.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {}
      }
    }
    final date = data['date'];
    final free = data['freeCount'];
    return TaxiRouteFeed(
      header: NearbyHeader.fromJson(header is Map ? Map<String, dynamic>.from(header) : null),
      tiers: tiers,
      date: date is String && TaxiJourneyDate.parse(date) != null ? date.trim() : null,
      freeCount: free is num && free.isFinite && free >= 0 ? free.toInt() : null,
    );
  }
}

class TaxiLocalPage extends NearbyPage<TaxiFeedItem> {
  final Map<String, dynamic>? raw;

  const TaxiLocalPage({
    super.header,
    super.featured,
    super.items,
    super.hasMore,
    super.nextToken,
    this.raw,
  });

  static TaxiLocalPage fromData(Map<String, dynamic> data) {
    final page = NearbyRepositoryBase.pageFromResponse<TaxiFeedItem>({'data': data}, TaxiFeedItem.fromJson);
    return TaxiLocalPage(
      header: page.header,
      featured: page.featured,
      items: page.items,
      hasMore: page.hasMore,
      nextToken: page.nextToken,
      raw: data,
    );
  }
}

class TaxiFeedRepository extends NearbyRepositoryBase<TaxiFeedItem> {
  const TaxiFeedRepository();

  static Future<Map<String, dynamic>> _get(String path, Map<String, dynamic> params) async {
    try {
      return await ApiService.get(path, params: params);
    } on DioException catch (e) {
      if (DioErrorMapper.errorType(e) == TaxiSearchErrors.invalidDate) throw const TaxiInvalidDateError();
      rethrow;
    }
  }

  Future<NearbyPage<TaxiFeedItem>> local({
    required double lat,
    required double lng,
    String? pageToken,
    int pageSize = 20,
    String? category,
    String? date,
  }) async {
    final res = await _get('/taxis/feed', {
      'lat': lat,
      'lng': lng,
      'pageSize': pageSize,
      'pageToken': ?pageToken,
      'category': ?category,
      'date': ?date,
    });
    final raw = res['data'];
    return TaxiLocalPage.fromData(raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
  }

  Map<String, dynamic> _routeParams(double fromLat, double fromLng, double toLat, double toLng, String? category, String? date, String sort, TaxiCityPair? cities) => {
        'fromLat': fromLat,
        'fromLng': fromLng,
        'toLat': toLat,
        'toLng': toLng,
        ...?cities?.toParams(),
        'category': ?category,
        'date': ?date,
        'sort': TaxiRouteSort.all.contains(sort) ? sort : TaxiRouteSort.nearest,
      };

  Future<TaxiRouteFeed> route({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String? category,
    String? date,
    String sort = TaxiRouteSort.nearest,
    TaxiCityPair? cities,
  }) async =>
      TaxiRouteFeed.fromResponse(await _get('/taxis/route-feed', _routeParams(fromLat, fromLng, toLat, toLng, category, date, sort, cities)));

  // One more page of a single tier.
  Future<TaxiTier?> routeTier({
    required String tier,
    required String pageToken,
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String? category,
    String? date,
    String sort = TaxiRouteSort.nearest,
    TaxiCityPair? cities,
  }) async {
    final res = await _get('/taxis/route-feed', {
      ..._routeParams(fromLat, fromLng, toLat, toLng, category, date, sort, cities),
      'tier': tier,
      'pageToken': pageToken,
    });
    return TaxiRouteFeed.fromResponse(res).tier(tier);
  }

  Future<List<TaxiPopularRoute>> popularRoutes() async {
    final res = await ApiService.get('/taxis/popular-routes');
    final raw = res['data'];
    return TaxiPopularRoute.listFrom(raw is Map ? raw['items'] : null);
  }
}
