import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/widgets/trip_city_tile.dart';
import 'package:bakhli/features/trip/widgets/trip_popular_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/real_phone.dart';

const _names = ['Nainital', 'Mussoorie', 'Manali', 'Dharamshala', 'Very long city name', 'Rishikesh'];

class _FakeCatalog extends TripCityCatalog {
  @override
  void warmFromDisk() {}

  @override
  Future<List<TripCityModel>> load({bool force = false}) async => popular();

  @override
  List<TripCityModel> popular({String? stateName}) => [
        for (var i = 0; i < 4; i++)
          TripCityModel(
            cityKey: i,
            name: _names[i],
            stateName: 'Uttarakhand',
            latitude: 1,
            longitude: 1,
            spotCount: 18 + i,
            isPopularDestination: true,
            status: i == 3 ? TripCityStatus.notReady : TripCityStatus.ready,
          ),
      ];
}

Widget _menu() => SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(color: DesignColors.surface, shape: BoxShape.circle, boxShadow: Ink3D.whiteBtn),
          child: const Icon(Icons.more_vert_rounded),
        ),
      ),
    );

Widget _page() => Scaffold(
      backgroundColor: DesignColors.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 40, bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TripPopularRail(),
            MealsGrid(
              count: 4,
              cardBuilder: (c, i, w) => TripCityTile(
                index: i,
                width: w,
                onTap: () {},
                city: TripCityModel(
                  cityKey: 10 + i,
                  name: _names[i + 2],
                  stateName: 'Himachal Pradesh',
                  districtName: 'Kangra',
                  latitude: 1,
                  longitude: 1,
                  spotCount: 12 + i,
                ),
              ),
            ),
            const SizedBox(height: 20),
            WideCard(
              tone: ListingTone.indigo,
              kind: WideKind.slim,
              art: ListingArt.mountain,
              title: 'Dharamshala',
              subtitle: 'Day 1 - 3 · Fri 14 Nov - Sun 16 Nov\n4 places · 2 nights',
              trailingWidth: 48,
              trailing: _menu(),
            ),
            WideCard(
              tone: ListingTone.forest,
              tag: 'Homestay',
              title: 'Pine View Homestay',
              subtitle: 'Mall Road',
              number: '2,400',
              unit: '/ night',
              priceCaption: 'FROM',
              label: '1.2 km away',
              actions: [
                WideAction(icon: Icons.call_rounded, label: 'Call', onTap: () {}),
                WideAction(icon: Icons.add_rounded, label: 'Shortlist', onTap: () {}),
              ],
            ),
            WideCard(
              tone: ListingTone.coral,
              tag: 'Hotel',
              title: 'Hill Top Stay',
              subtitle: 'Camel Back Road',
              number: '3,100',
              unit: '/ night',
              actions: [
                WideAction(icon: Icons.call_rounded, label: 'Call', onTap: () {}),
                WideAction(icon: Icons.check_rounded, label: 'Shortlisted', onTap: () {}, selected: true),
              ],
            ),
          ],
        ),
      ),
    );

void main() {
  shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\cards_kit';
  tearDown(Get.reset);
  for (final (w, s) in <(double, double)>[(360, 1.0), (360, 1.3), (300, 1.0), (300, 1.3)]) {
    testWidgets('cards kit $w $s', (t) async {
      Get.put<TripCityCatalog>(_FakeCatalog(), permanent: true);
      await pumpPhone(t, _page(), size: Size(w, 2000), textScale: s);
      await settlePhone(t);
      expect(t.takeException(), isNull);
      await shot(t, 'cards_${w.toInt()}_$s');
    });
  }
}
