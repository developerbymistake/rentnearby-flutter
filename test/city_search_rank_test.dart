import 'package:bakhli/models/city_model.dart';
import 'package:bakhli/utils/city_search_rank.dart';
import 'package:bakhli/utils/place_search_rank.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Place = ({String name, String? state, String? type});

List<String> places(List<Place> rows, String q, {String? prefer}) => PlaceSearchRank.rank<Place>(
      rows,
      q,
      name: (p) => p.name,
      state: (p) => p.state,
      type: (p) => p.type,
      preferState: prefer,
    ).map((p) => '${p.name}/${p.type}').toList();

void main() {
  test('city switch sheet: prefix before contains (Kullu, "man")', () {
    final names = ['Kamand', 'Manali', 'Manihar', 'Manikaran', 'Mansari', 'Nirmand', 'Old Manali', 'Raman'];
    final cities = [for (final n in names) CityModel(id: n, districtId: 'kullu', name: n)];
    final r = CitySearchRank.rank<CityModel>(cities, 'man', name: (c) => c.name).map((c) => c.name);
    expect(r, ['Manali', 'Manihar', 'Manikaran', 'Mansari', 'Old Manali', 'Kamand', 'Nirmand', 'Raman']);
  });

  test('tiers', () {
    expect(CitySearchRank.tier('manali', 'manali'), CitySearchRank.exact);
    expect(CitySearchRank.tier('manali', 'man'), CitySearchRank.prefix);
    expect(CitySearchRank.tier('old manali', 'man'), CitySearchRank.wordPrefix);
    expect(CitySearchRank.tier('kamand', 'man'), CitySearchRank.contains);
    expect(CitySearchRank.tier('bhimtal', 'naini', 'nainital'), CitySearchRank.district);
    expect(CitySearchRank.tier('bhimtal', 'utt', 'nainital'), CitySearchRank.none);
    expect(CitySearchRank.tier('bhimtal', ''), CitySearchRank.none);
  });

  test('ties: popular, then more spots, then name, then input order', () {
    final items = [
      (n: 'Manb', pop: false, spots: 1),
      (n: 'Manc', pop: false, spots: 9),
      (n: 'Mand', pop: true, spots: 0),
      (n: 'Mana', pop: false, spots: 1),
    ];
    final r = CitySearchRank.rank<_Row>(items.map((e) => _Row(e.n, e.pop, e.spots)), 'man',
            name: (c) => c.name, popular: (c) => c.popular, weight: (c) => c.spots)
        .map((c) => c.name);
    expect(r, ['Mand', 'Manc', 'Mana', 'Manb']);
  });

  test('blank query keeps the list as is; accents fold', () {
    final cities = [CityModel(id: '1', districtId: 'd', name: 'Dwārāhāt'), CityModel(id: '2', districtId: 'd', name: 'Almora')];
    expect(CitySearchRank.rank<CityModel>(cities, ' ', name: (c) => c.name).length, 2);
    expect(CitySearchRank.rank<CityModel>(cities, 'dwar', name: (c) => c.name).single.id, '1');
  });

  test('Photon: exact name beats a fuzzy town (Sattal)', () {
    final rows = <Place>[
      (name: 'Sattal', state: 'Uttarakhand', type: 'village'),
      (name: 'Satpuli', state: 'Uttarakhand', type: 'town'),
    ];
    expect(places(rows, 'Sattal', prefer: 'Uttarakhand'), ['Sattal/village', 'Satpuli/town']);
  });

  test('Photon: order kept inside a tier, type only between equal names', () {
    final rows = <Place>[
      (name: 'Kainchi Dham', state: 'Uttarakhand', type: 'place_of_worship'),
      (name: 'Kainchi', state: 'Uttarakhand', type: 'village'),
      (name: 'Kainchi', state: 'Uttarakhand', type: 'town'),
    ];
    expect(places(rows, 'kainchi'), ['Kainchi/town', 'Kainchi/village', 'Kainchi Dham/place_of_worship']);
    expect(places(rows, 'kainchi dham'), ['Kainchi Dham/place_of_worship', 'Kainchi/town', 'Kainchi/village']);
  });

  test('Photon: preferred state first', () {
    final rows = <Place>[
      (name: 'Rampur', state: 'Uttar Pradesh', type: 'city'),
      (name: 'Rampur', state: 'Himachal Pradesh', type: 'village'),
    ];
    expect(places(rows, 'rampur', prefer: 'Himachal Pradesh'), ['Rampur/village', 'Rampur/city']);
    expect(places(const [], 'x'), isEmpty);
  });
}

class _Row {
  final String name;
  final bool popular;
  final int spots;
  _Row(this.name, this.popular, this.spots);
}
