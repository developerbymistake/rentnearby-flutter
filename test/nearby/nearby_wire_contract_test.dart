import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/features/jobs/v2/jobs_feed_repository.dart';
import 'package:bakhli/features/nearby/data/nearby_repository_base.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/nearby/widgets/nearby_label_text.dart';
import 'package:bakhli/features/stay/guest/v2/stay_feed_item.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_feed_repository.dart';
import 'package:bakhli/models/home_feed_model_v2.dart';

// Sample JSON mirrors the backend wire keys (RentNearBy.Tests/Nearby/NearbyWireContractTests.cs).
const _header = {
  'centreCityName': 'Haldwani',
  'centreStateName': 'Uttarakhand',
  'centreCityKm': 3.2,
  'livesIn': 'We are live in Uttarakhand and Himachal Pradesh',
  'farAway': true,
  'nearestKm': 420.1,
  'citiesUnavailable': false,
};

Map<String, dynamic> _stay() => {
      'id': '11111111-1111-1111-1111-111111111111',
      'userId': '22222222-2222-2222-2222-222222222222',
      'name': 'Lake View',
      'stayTypeId': null,
      'stayTypeName': 'Homestay',
      'thumbnailUrl': null,
      'cityName': 'Haldwani',
      'districtName': 'Nainital',
      'minPricePerNight': 1800,
      'mealsChip': 'Breakfast',
      'roomNameChip': 'Deluxe',
      'priorityRank': 1,
      'isFeatured': true,
      'createdAt': '2026-11-01T00:00:00Z',
      'stateName': 'Uttarakhand',
      'distanceKm': 420.1,
      'labelKey': 'far',
      'isNear': false,
    };

Map<String, dynamic> _taxi({int? km = 35, bool route = false}) => {
      'id': '33333333-3333-3333-3333-333333333333',
      'driverName': 'Ravi',
      'vehicleTypeName': 'Sedan',
      'vehicleCategory': 'Sedan',
      'seats': 4,
      'plateDisplay': 'UK04 AB 1234',
      'cityId': null,
      'cityName': 'Haldwani',
      'districtName': 'Nainital',
      'minFare': 900,
      'routeCount': 3,
      'localDayRate': 2500,
      'localDayKm': 80,
      'tripSeatsFit': null,
      'tripCars': null,
      'tripDayCost': null,
      'tripExtraKm': null,
      'tripPickupKm': null,
      'tripReplyLabel': 'new',
      'matchedFare': route ? 1200 : null,
      'matchedFromName': route ? 'Haldwani' : null,
      'matchedToName': route ? 'Nainital' : null,
      'matchedTripType': null,
      'matchReversed': false,
      'priorityRank': 0,
      'isFeatured': false,
      'createdAt': '2026-11-01T00:00:00Z',
      'stateName': 'Uttarakhand',
      'distanceKm': km,
      'labelKey': route ? 'onRoute' : 'far',
      'isNear': false,
      'listedForRoute': route,
    };

Map<String, dynamic> _job({String? cityName}) => {
      'id': '44444444-4444-4444-4444-444444444444',
      'stayListingId': '11111111-1111-1111-1111-111111111111',
      'stayName': 'Lake View',
      'stayTypeName': 'Homestay',
      'coverPhotoUrl': null,
      'title': 'Front desk',
      'departmentName': 'Front Office',
      'roleName': 'Receptionist',
      'jobTypeName': 'Full time',
      'shiftTypeName': 'Day',
      'salaryTypeName': 'Monthly',
      'minimumExperienceYears': 1,
      'minSalary': 12000,
      'maxSalary': 15000,
      'districtId': '55555555-5555-5555-5555-555555555555',
      'districtName': 'Nainital',
      'cityName': cityName,
      'createdAt': '2026-11-01T00:00:00Z',
      'stateName': 'Uttarakhand',
      'cityKey': 123456789012,
      'distanceKm': 420.1,
      'labelKey': 'far',
      'isNear': false,
    };

Map<String, dynamic> _page(List<Map<String, dynamic>> items, {List<Map<String, dynamic>> featured = const []}) => {
      'data': {'header': _header, 'featured': featured, 'items': items, 'hasMore': true, 'nextToken': 'abc_-123'},
      'status': '200',
    };

void main() {
  test('stays feed page parses header, items, featured and token', () {
    final p = NearbyRepositoryBase.pageFromResponse(_page([_stay()], featured: [_stay()]), StayFeedItem.fromJson);
    expect(p.header.livesIn, startsWith('We are live in'));
    expect(p.header.farAway, isTrue);
    expect(p.header.nearestKm, 420.1);
    expect(p.header.centreCityKm, 3.2);
    expect(p.header.citiesUnavailable, isFalse);
    expect(p.hasMore, isTrue);
    expect(p.nextToken, 'abc_-123');
    expect(p.featured, hasLength(1));
    final i = p.items.single;
    expect(i.item.title, 'Lake View');
    expect(i.distance.km, 420.1);
    expect(i.distance.label, NearbyLabel.far);
    expect(i.distance.state, 'Uttarakhand');
    expect(NearbyLabelText.textFor(i.distance), contains('Haldwani, Uttarakhand. About 42'));
  });

  test('taxi feed item parses int km, label and listedForRoute; route item has no distance', () {
    final local = TaxiFeedItem.fromJson(_taxi());
    expect(local.distance!.km, 35);
    expect(local.distance!.label, NearbyLabel.far);
    expect(local.listedForRoute, isFalse);
    expect(local.item.localDayRate, 2500);
    final route = TaxiFeedItem.fromJson(_taxi(km: null, route: true));
    expect(route.distance, isNull);
    expect(route.listedForRoute, isTrue);
    expect(route.item.matchedFare, 1200);
  });

  test('taxi route feed parses four tiers with tier header and token', () {
    Map<String, dynamic> tier(String k, List<Map<String, dynamic>> items, {bool withHeader = false}) => {
          'key': k,
          'headerKey': k,
          'header': withHeader ? _header : null,
          'items': items,
          'hasMore': k == 'onRoute',
          'nextToken': k == 'onRoute' ? 'p2' : null,
          'collapsed': withHeader,
        };
    final feed = TaxiRouteFeed.fromResponse({
      'data': {
        'header': _header,
        'tiers': [
          tier('onRoute', [_taxi(km: null, route: true)]),
          tier('passing', [_taxi(km: null, route: true)]),
          tier('basedNearFrom', [_taxi()], withHeader: true),
          tier('inTo', [_taxi()], withHeader: true),
        ],
      },
    });
    expect(feed.tiers.map((t) => t.key), TaxiTierKey.order);
    expect(feed.tier('onRoute')!.nextToken, 'p2');
    expect(feed.tier('passing')!.header, isNull);
    expect(feed.tier('inTo')!.header!.farAway, isTrue);
    expect(feed.tier('basedNearFrom')!.collapsed, isTrue);
    expect(feed.tier('basedNearFrom')!.items.single.distance!.km, 35);
  });

  test('jobs feed item parses distance and state', () {
    final p = NearbyRepositoryBase.pageFromResponse(_page([_job(cityName: 'Haldwani')]), JobFeedItem.fromJson);
    final j = p.items.single;
    expect(j.job.cityName, 'Haldwani');
    expect(j.distance!.state, 'Uttarakhand');
    expect(j.distance!.label, NearbyLabel.far);
  });

  test('jobs feed item without a city labels with the district, never without a place', () {
    final j = JobFeedItem.fromJson(_job());
    expect(j.job.cityName, isNull);
    expect(NearbyLabelText.textFor(j.distance!), startsWith('Nainital, Uttarakhand. About 42'));
  });

  test('home nearby feed parses as the old shape plus honest labels', () {
    final m = HomeFeedModelV2.fromJson({
      'tabs': {'stays': true, 'jobs': false, 'taxi': true},
      'header': _header,
      'stays': [_stay()],
      'taxis': [_taxi()],
      'recentStays': [_stay()],
    });
    expect(m.tabs['jobs'], isFalse);
    expect(m.stays!.single.item.locationLabel, contains('About'));
    expect(m.taxis!.single.cityName, contains('About'));
    expect(m.recentStays, hasLength(1));
  });

  test('home feed with off sections as null stays null', () {
    final m = HomeFeedModelV2.fromJson({
      'tabs': {'stays': false, 'jobs': true, 'taxi': false},
      'header': null,
      'stays': null,
      'taxis': null,
      'recentStays': null,
    });
    expect(m.stays, isNull);
    expect(m.taxis, isNull);
    expect(m.isSectionTabOff('stays'), isTrue);
  });

  test('missing optional header fields never crash', () {
    final p = NearbyRepositoryBase.pageFromResponse({
      'data': {'header': {}, 'items': []}
    }, StayFeedItem.fromJson);
    expect(p.header.livesIn, '');
    expect(p.items, isEmpty);
    expect(p.hasMore, isFalse);
    expect(p.nextToken, isNull);
  });
}
