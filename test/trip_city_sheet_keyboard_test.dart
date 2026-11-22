import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/widgets/trip_city_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/owner_sizes.dart';
import 'support/real_phone.dart';

// FX-08: the city sheet with 2 picked cities and the keyboard open keeps Continue above the keyboard
// and a usable list, on every size, at text scale 1.0 and 1.3, and after a rotation.
TripCityModel _city(int k, String n, {bool popular = false}) => TripCityModel(
    cityKey: k, name: n, districtName: 'D$k', stateName: 'Uttarakhand', latitude: 1, longitude: 1, isPopularDestination: popular);

class _Catalog extends TripCityCatalog {
  final list = [
    _city(1, 'Nainital', popular: true),
    _city(2, 'Almora'),
    _city(3, 'Mallital'),
    for (var i = 4; i < 16; i++) _city(i, 'Town $i'),
  ];
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

Widget _opener() => Scaffold(
      body: Builder(
        builder: (ctx) => Center(child: TextButton(onPressed: () => TripCitySheet.pick(ctx), child: const Text('open'))),
      ),
    );

Future<void> _openAndPick(WidgetTester t) async {
  await t.tap(find.text('open'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
  for (final name in ['Nainital', 'Almora']) {
    final f = find.text(name);
    await t.ensureVisible(f);
    await t.pump();
    await t.tap(f, warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 300));
  }
}

void _checkLayout(WidgetTester t, Size size) {
  final kb = t.view.viewInsets.bottom / t.view.devicePixelRatio;
  final cont = find.textContaining('Continue (2');
  expect(cont, findsOneWidget);
  final r = t.getRect(cont);
  expect(r.bottom, lessThanOrEqualTo(size.height - kb + 0.5), reason: 'Continue above the keyboard');
  final list = t.getRect(find.descendant(of: find.byType(TripCitySheet), matching: find.byType(CustomScrollView)).first);
  expect(list.height, greaterThanOrEqualTo(DS.s(120)), reason: 'the list keeps a usable viewport');
}

void main() {
  setUp(() {
    Get.reset();
    Get.put<TripCityCatalog>(_Catalog(), permanent: true);
  });
  tearDown(Get.reset);

  testOwnerMatrix(
    'city sheet, 2 picked',
    _opener,
    keyboard: true,
    arrange: _openAndPick,
    check: (t, size, scale, kb) async => _checkLayout(t, size),
  );

  testWidgets('rotation while open resizes the sheet (no stored first height)', (t) async {
    await pumpPhone(t, _opener(), size: const Size(411, 891));
    await _openAndPick(t);
    t.view.physicalSize = const Size(891, 411) * t.view.devicePixelRatio;
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    _checkLayout(t, const Size(891, 411));
    final sheet = t.getRect(find.byType(TripCitySheet));
    expect(sheet.height, lessThanOrEqualTo(411));
  });
}
