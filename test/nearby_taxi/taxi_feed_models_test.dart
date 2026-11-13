import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';

Map<String, dynamic> item(String id, {int? km, String label = 'near', bool route = false}) => {
      'id': id,
      'driverName': 'Driver $id',
      'vehicleTypeName': 'Sedan',
      'plateDisplay': 'UK04',
      'routeCount': 2,
      'createdAt': '2026-11-01T00:00:00Z',
      'cityName': 'Haldwani',
      'stateName': 'Uttarakhand',
      'distanceKm': ?km,
      'labelKey': label,
      'listedForRoute': route,
      'minFare': 900,
    };

Map<String, dynamic> tier(String key, List<Map<String, dynamic>> items, {bool collapsed = false, bool more = false}) => {
      'key': key,
      'headerKey': key,
      'items': items,
      'hasMore': more,
      'nextToken': more ? 'p2' : null,
      'collapsed': collapsed,
      if (key == 'basedNearFrom' || key == 'inTo') 'header': {'centreCityName': 'Haldwani', 'farAway': false},
    };

void main() {
  test('parses four tiers in order with the collapsed flag', () {
    final res = {
      'data': {
        'header': {'centreCityName': 'Haldwani', 'farAway': false},
        'tiers': [
          tier('onRoute', [item('a', route: true)], more: true),
          tier('passing', [item('b'), item('c')]),
          tier('basedNearFrom', [item('d', km: 5)], collapsed: true),
          tier('inTo', [item('e', km: 10, label: 'far')], collapsed: true),
        ],
      },
    };
    final feed = TaxiRouteFeed.fromResponse(res);
    expect(feed.tiers.map((t) => t.key), TaxiTierKey.order);
    expect(feed.tier('onRoute')!.hasMore, isTrue);
    expect(feed.tier('onRoute')!.nextToken, 'p2');
    expect(feed.tier('onRoute')!.items.single.listedForRoute, isTrue);
    expect(feed.tier('basedNearFrom')!.collapsed, isTrue);
    expect(feed.tier('basedNearFrom')!.header!.centreCityName, 'Haldwani');
    expect(feed.tier('passing')!.collapsed, isFalse);
    expect(feed.isEmpty, isFalse);
  });

  test('tolerates missing and broken data', () {
    expect(TaxiRouteFeed.fromResponse(const {}).tiers, isEmpty);
    expect(TaxiRouteFeed.fromResponse(const {}).isEmpty, isTrue);
    final feed = TaxiRouteFeed.fromResponse({
      'data': {
        'tiers': [
          'bad',
          {
            'key': 'inTo',
            'items': [<String, dynamic>{}, item('x')],
          },
        ],
      },
    });
    expect(feed.tiers.single.items.single.id, 'x');
  });

  test('distance and label come from the item, no coordinates are read', () {
    final f = TaxiFeedItem.fromJson({...item('z', km: 20, label: 'far'), 'latitude': 1.0, 'lat': 2.0});
    expect(f.distance!.km, 20);
    expect(f.distance!.label, NearbyLabel.far);
    expect(f.distance!.city, 'Haldwani');
    expect(f.distance!.state, 'Uttarakhand');
    expect(TaxiFeedItem.fromJson(item('y')).distance, isNull);
  });

  test('a far label never reads as near', () {
    final f = TaxiFeedItem.fromJson(item('z', km: 25, label: 'near'));
    expect(f.distance!.label, NearbyLabel.far);
  });
}
