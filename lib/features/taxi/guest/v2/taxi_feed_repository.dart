import '../../../../services/api_service.dart';
import '../../../nearby/data/nearby_repository_base.dart';
import '../../../nearby/models/nearby_models.dart';
import '../../models/taxi_browse_item.dart';

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

class TaxiRouteFeed {
  final NearbyHeader header;
  final List<TaxiTier> tiers;

  const TaxiRouteFeed({this.header = NearbyHeader.empty, this.tiers = const []});

  bool get isEmpty => tiers.every((t) => t.isEmpty);

  TaxiTier? tier(String key) {
    for (final t in tiers) {
      if (t.key == key) return t;
    }
    return null;
  }

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
    return TaxiRouteFeed(
      header: NearbyHeader.fromJson(header is Map ? Map<String, dynamic>.from(header) : null),
      tiers: tiers,
    );
  }
}

class TaxiFeedRepository extends NearbyRepositoryBase<TaxiFeedItem> {
  const TaxiFeedRepository();

  Future<NearbyPage<TaxiFeedItem>> local({
    required double lat,
    required double lng,
    String? pageToken,
    int pageSize = 20,
    String? category,
  }) =>
      getPage(
        '/taxis/feed',
        {
          'lat': lat,
          'lng': lng,
          'pageSize': pageSize,
          'pageToken': ?pageToken,
          'category': ?category,
        },
        TaxiFeedItem.fromJson,
      );

  Map<String, dynamic> _routeParams(double fromLat, double fromLng, double toLat, double toLng, String? category) => {
        'fromLat': fromLat,
        'fromLng': fromLng,
        'toLat': toLat,
        'toLng': toLng,
        'category': ?category,
      };

  Future<TaxiRouteFeed> route({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String? category,
  }) async =>
      TaxiRouteFeed.fromResponse(await ApiService.get('/taxis/route-feed',
          params: _routeParams(fromLat, fromLng, toLat, toLng, category)));

  // One more page of a single tier.
  Future<TaxiTier?> routeTier({
    required String tier,
    required String pageToken,
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String? category,
  }) async {
    final res = await ApiService.get('/taxis/route-feed', params: {
      ..._routeParams(fromLat, fromLng, toLat, toLng, category),
      'tier': tier,
      'pageToken': pageToken,
    });
    return TaxiRouteFeed.fromResponse(res).tier(tier);
  }
}
