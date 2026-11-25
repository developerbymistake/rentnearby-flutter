import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/sheet_close_button.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/widgets/trip_city_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/five_sizes.dart';
import 'ui_golden/golden_support.dart';

const _hp = 'Himachal Pradesh';
const _longState = 'The Very Long Hill State Name Of The North';

TripCityModel _city(int k, String n, {bool popular = false, String state = 'Uttarakhand'}) => TripCityModel(
    cityKey: k, name: n, districtName: 'D$k', stateName: state, latitude: 1, longitude: 1, isPopularDestination: popular);

class _Catalog extends TripCityCatalog {
  _Catalog([List<TripCityModel> extra = const []]) {
    list.addAll(extra);
  }
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

  TripCityModel empty(int k, String n) => TripCityModel(
      cityKey: k, name: n, districtName: 'D$k', stateName: 'Uttarakhand', latitude: 1, longitude: 1, status: TripCityStatus.notReady);

  for (final mode in TripCitySheetMode.values) {
    testWidgets('${mode.name} mode never lists a city with no places', (t) async {
      Get.put<TripCityCatalog>(_Catalog([empty(30, 'Haldwani'), empty(31, 'Kathgodam')]), permanent: true);
      setGoldenView(t, const Size(412, 900));
      await t.pumpWidget(MaterialApp(home: Scaffold(body: TripCitySheet(mode: mode, inTrip: const {1}))));
      await t.pumpAndSettle();
      expect(find.text('Haldwani'), findsNothing);
      expect(find.text('Kathgodam'), findsNothing);
      expect(find.textContaining('No places yet'), findsNothing);
      expect(find.text('Almora'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, 'hald');
      await t.pumpAndSettle();
      expect(find.text('Haldwani'), findsNothing);
    });
  }

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

  group('add a city lists only the trip state', () {
    final himachal = [_city(10, 'Shimla', state: _hp, popular: true), _city(11, 'Manali', state: _hp)];

    Future<void> pumpAdd(WidgetTester t, Set<int> inTrip, {List<TripCityModel>? extra}) async {
      Get.put<TripCityCatalog>(_Catalog(extra ?? himachal), permanent: true);
      setGoldenView(t, const Size(412, 900));
      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: TripCitySheet(mode: TripCitySheetMode.add, afterCity: 'Nainital', inTrip: inTrip)),
      ));
      await t.pumpAndSettle();
    }

    bool luggageArt(WidgetTester t) => t.widgetList<Art3D>(find.byType(Art3D)).any((a) => a.asset == ListingArt.luggage);

    testWidgets('one state: only its cities, compact header, in-trip row greyed', (t) async {
      await pumpAdd(t, {1});
      expect(find.text('Add a city'), findsOneWidget);
      expect(find.text('Cities in Uttarakhand · After Nainital'), findsOneWidget);
      expect(find.text('Shimla'), findsNothing);
      expect(find.text('Manali'), findsNothing);
      expect(find.text('Almora'), findsOneWidget);
      expect(find.text('Nainital'), findsOneWidget);
      expect(find.text('In this trip'), findsOneWidget);
      expect(luggageArt(t), isFalse);
      expect(find.textContaining('another state'), findsNothing);
      expect(find.textContaining('separate trip'), findsNothing);
    });

    testWidgets('search inside the state, no match names the state', (t) async {
      await pumpAdd(t, {1});
      await t.enterText(find.byType(TextField).first, 'manali');
      await t.pumpAndSettle();
      expect(find.text('No city in Uttarakhand matches "manali"'), findsOneWidget);
      expect(find.text('Manali'), findsNothing);
      await t.enterText(find.byType(TextField).first, 'alm');
      await t.pumpAndSettle();
      expect(find.text('Almora'), findsOneWidget);
      expect(find.text('Shimla'), findsNothing);
    });

    testWidgets('old trip with two states lists both', (t) async {
      await pumpAdd(t, {1, 10});
      expect(find.text('Cities in Uttarakhand and Himachal Pradesh · After Nainital'), findsOneWidget);
      expect(find.text('Manali'), findsOneWidget);
      expect(find.text('Almora'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, 'goa');
      await t.pumpAndSettle();
      expect(find.text('No city matches "goa"'), findsOneWidget);
    });

    testWidgets('trip city unknown to the catalog lists every state', (t) async {
      await pumpAdd(t, {99});
      expect(find.text('After Nainital'), findsOneWidget);
      expect(find.text('Shimla'), findsOneWidget);
      expect(find.text('Almora'), findsOneWidget);
    });

    testWidgets('start mode is not filtered', (t) async {
      Get.put<TripCityCatalog>(_Catalog(himachal), permanent: true);
      setGoldenView(t, const Size(412, 900));
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: TripCitySheet(inTrip: {1}))));
      await t.pumpAndSettle();
      expect(find.text('Shimla'), findsOneWidget);
      expect(luggageArt(t), isTrue);
    });

    for (final size in fiveSizes) {
      testWidgets('add sheet at ${sizeLabel(size)}', (t) async {
        Get.put<TripCityCatalog>(_Catalog([...himachal, _city(20, 'Longtown', state: _longState)]), permanent: true);
        for (final inTrip in [
          {1},
          {20},
        ]) {
          await pumpAtSize(t, Scaffold(body: TripCitySheet(mode: TripCitySheetMode.add, afterCity: 'Nainital', inTrip: inTrip)), size);
          await t.pump(const Duration(milliseconds: 500));
          expect(t.takeException(), isNull, reason: '${sizeLabel(size)} $inTrip');
          final sub = find.textContaining('Cities in');
          expect(sub, findsOneWidget);
          expect(t.widget<Text>(sub).maxLines, 1);
          expect(find.text('Shimla'), findsNothing);
          final title = t.getRect(find.text('Add a city'));
          final close = t.getRect(find.byType(SheetCloseButton));
          final sheet = t.getRect(find.byType(TripCitySheet));
          expect(close.right, closeTo(sheet.right - DS.s(4), 0.5));
          final band = t.getRect(find.ancestor(of: find.text('Add a city'), matching: find.byType(Container)).first);
          expect(band.width, closeTo(sheet.width, 0.5), reason: 'header band spans the sheet');
          expect(close.bottom, lessThanOrEqualTo(band.bottom + 0.5));
          expect(t.getRect(sub).right, lessThanOrEqualTo(close.left + 0.5));
          expect(title.right, lessThanOrEqualTo(close.left + 0.5));
          expect(t.getRect(find.byType(TextField).first).top, greaterThan(t.getRect(sub).bottom));
          expect(t.getRect(find.byType(TextField).first).top - sheet.top, lessThan(size.height * 0.2), reason: 'compact header');
          await t.enterText(find.byType(TextField).first, 'manali');
          await t.pump(const Duration(milliseconds: 500));
          expect(t.takeException(), isNull, reason: '${sizeLabel(size)} no match');
        }
      });
    }
  });
}
