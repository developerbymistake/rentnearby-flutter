import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/widgets/trip_city_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'ui_golden/golden_support.dart';

TripCityModel _city(int k, String n, {bool popular = false}) => TripCityModel(
    cityKey: k, name: n, districtName: 'D$k', stateName: 'Uttarakhand', latitude: 1, longitude: 1, isPopularDestination: popular);

class _Catalog extends TripCityCatalog {
  final list = [_city(1, 'Nainital', popular: true), _city(2, 'Almora'), _city(3, 'Mallital')];
  @override
  void warmFromDisk() {}
  @override
  bool get hasData => true;
  @override
  Future<List<TripCityModel>> load({bool force = false}) async => list;
  @override
  List<TripCityModel> search(String q) => TripCitySearch.filter(list, q);
  @override
  List<TripCityModel> popular({String? stateName}) => list.where((c) => c.isPopularDestination).toList();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });
  tearDown(Get.reset);

  testWidgets('create mode shows Atlas Popular cities and no hardcoded routes', (t) async {
    final cats = _Catalog();
    cats.list.addAll([_city(4, 'Haridwar', popular: true), _city(5, 'Badrinath', popular: true)]);
    Get.put<TripCityCatalog>(cats, permanent: true);
    setGoldenView(t, const Size(412, 900));
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: TripCitySheet())));
    await t.pumpAndSettle();
    expect(find.text('POPULAR ROUTES'), findsNothing);
    expect(find.text('Haridwar then Badrinath'), findsNothing);
    expect(find.text('POPULAR CITIES'), findsOneWidget);
    expect(find.text('ALL CITIES'), findsOneWidget);
    expect(find.text('Haridwar'), findsOneWidget);
    expect(find.text('Almora'), findsOneWidget);
  });

  testWidgets('add mode shows no Popular next stops', (t) async {
    final cats = _Catalog();
    cats.list.addAll([_city(4, 'Haridwar', popular: true), _city(5, 'Badrinath', popular: true)]);
    Get.put<TripCityCatalog>(cats, permanent: true);
    setGoldenView(t, const Size(412, 900));
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: TripCitySheet(mode: TripCitySheetMode.add, afterCity: 'Haridwar', inTrip: {4})),
    ));
    await t.pumpAndSettle();
    expect(find.text('POPULAR NEXT STOPS'), findsNothing);
    expect(find.text('Taxis go from Haridwar'), findsNothing);
    expect(find.text('POPULAR'), findsOneWidget);
    expect(find.text('Badrinath'), findsOneWidget);
  });

  testWidgets('no popular cities shows one plain list without headers', (t) async {
    final cats = _Catalog();
    cats.list[0] = _city(1, 'Nainital');
    Get.put<TripCityCatalog>(cats, permanent: true);
    setGoldenView(t, const Size(412, 900));
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: TripCitySheet())));
    await t.pumpAndSettle();
    expect(find.text('ALL CITIES'), findsNothing);
    expect(find.text('Nainital'), findsOneWidget);
    expect(find.text('Almora'), findsOneWidget);
  });

  testWidgets('search with no match shows the no-match state', (t) async {
    Get.put<TripCityCatalog>(_Catalog(), permanent: true);
    setGoldenView(t, const Size(412, 900));
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: TripCitySheet())));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Goa');
    await t.pumpAndSettle();
    expect(find.textContaining('Goa'), findsWidgets);
    expect(find.text('Nainital'), findsNothing);
  });

  for (final w in [300.0, 360.0, 412.0, 560.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('plain match search @${w.toInt()} x$scale', (t) async {
        Get.put<TripCityCatalog>(_Catalog(), permanent: true);
        setGoldenView(t, Size(w, 900));
        await t.pumpWidget(MaterialApp(
          theme: ThemeData(fontFamily: 'WorkSans'),
          home: MediaQuery(
            data: MediaQueryData(size: Size(w, 900), textScaler: TextScaler.linear(scale)),
            child: const Scaffold(body: TripCitySheet()),
          ),
        ));
        await t.pumpAndSettle();
        expect(find.text('Nainital'), findsWidgets);
        await t.enterText(find.byType(TextField).first, 'alm');
        await t.pumpAndSettle();
        expect(find.text('Almora'), findsOneWidget);
        expect(find.text('Mallital'), findsNothing);
        expect(t.takeException(), isNull);
      });
    }
  }
}
