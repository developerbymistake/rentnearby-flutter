import 'package:bakhli/features/nearby/data/nearby_repository_base.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('header parses with missing fields', () {
    final h = NearbyHeader.fromJson({});
    expect(h.livesIn, '');
    expect(h.farAway, false);
    expect(h.nearestKm, isNull);
    expect(NearbyHeader.fromJson(null).citiesUnavailable, false);
  });

  test('header parses full', () {
    final h = NearbyHeader.fromJson({
      'centreCityName': 'Haldwani',
      'centreStateName': 'Uttarakhand',
      'centreCityKm': 3,
      'livesIn': 'We are live in A and B',
      'farAway': true,
      'nearestKm': 420.5,
      'citiesUnavailable': true,
    });
    expect(h.centreCityName, 'Haldwani');
    expect(h.nearestKm, 420.5);
    expect(h.farAway && h.citiesUnavailable, true);
  });

  test('label parse and unknown key', () {
    expect(NearbyLabel.parse('inCity'), NearbyLabel.inCity);
    expect(NearbyLabel.parse('far'), NearbyLabel.far);
    expect(NearbyLabel.parse('weird'), NearbyLabel.near);
    expect(NearbyLabel.parse(null), NearbyLabel.near);
  });

  test('distance label always agrees with km', () {
    expect(NearbyDistance.checked(km: 20, label: NearbyLabel.near).label, NearbyLabel.far);
    expect(NearbyDistance.checked(km: 20, label: NearbyLabel.inCity).label, NearbyLabel.far);
    expect(NearbyDistance.checked(km: 5, label: NearbyLabel.far).label, NearbyLabel.near);
    expect(NearbyDistance.checked(km: 5, label: NearbyLabel.inCity).label, NearbyLabel.inCity);
  });

  test('distance fromJson', () {
    expect(NearbyDistance.fromJson({}), isNull);
    final d = NearbyDistance.fromJson({'distanceKm': 420, 'labelKey': 'far', 'cityName': 'Haldwani', 'stateName': 'Uttarakhand'})!;
    expect(d.km, 420);
    expect(d.isFar, true);
    expect(d.state, 'Uttarakhand');
  });

  test('page parses, skips bad items and empty token', () {
    final p = NearbyRepositoryBase.pageFromResponse<String>({
      'data': {
        'header': {'livesIn': 'x'},
        'featured': [
          {'id': 'f'}
        ],
        'items': [
          {'id': 'a'},
          'junk',
          {'id': 'boom'},
          {'id': 'b'}
        ],
        'hasMore': true,
        'nextToken': '',
      }
    }, (j) {
      if (j['id'] == 'boom') throw StateError('bad');
      return j['id'] as String;
    });
    expect(p.featured, ['f']);
    expect(p.items, ['a', 'b']);
    expect(p.hasMore, true);
    expect(p.nextToken, isNull);
  });

  test('page tolerates empty response', () {
    final p = NearbyRepositoryBase.pageFromResponse<String>({}, (j) => '');
    expect(p.items, isEmpty);
    expect(p.featured, isEmpty);
    expect(p.hasMore, false);
  });
}
