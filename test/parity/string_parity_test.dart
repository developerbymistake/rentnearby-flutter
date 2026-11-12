import 'package:bakhli/features/stay/models/stay_owner_model.dart';
import 'package:bakhli/features/stay/setup/stay_owner_card.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/features/taxi/models/taxi_owner_model.dart';
import 'package:bakhli/features/taxi/setup/taxi_owner_card.dart';
import 'package:bakhli/features/taxi/taxi_option_sets.dart' show TaxiStatus;
import 'package:bakhli/features/taxi/ways/taxi_ways_strings.dart';
import 'package:bakhli/features/taxi/ways/widgets/local_taxi_rail_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget child, double width, double scale) async {
  t.view.physicalSize = Size(width, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 1600), textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Center(child: child)),
      ),
    ),
  ));
  await t.pump(const Duration(milliseconds: 600));
}

TaxiOwnerModel _owner() => TaxiOwnerModel(
      id: 'o1',
      status: TaxiStatus.approved,
      step1Done: true,
      routesDone: true,
      vehicleTypeName: 'Innova Crysta',
      seats: 7,
      plateDisplay: 'UK07 AB 1234',
      minFare: 1800,
      localDayRate: 3000,
      createdAt: DateTime(2026, 1, 1),
    );

StayOwnerModel _stay() => StayOwnerModel.fromJson({
      'id': 's1',
      'status': StayStatus.approved,
      'name': 'Riverside Homestay',
      'cityName': 'Bhimtal',
      'districtName': 'Nainital',
      'acceptingGuests': true,
      'createdAt': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      'rooms': [],
    });

TaxiBrowseItem _taxi({int? rate}) => TaxiBrowseItem(
      id: 't1',
      driverName: 'Ramesh Kumar Negi',
      vehicleTypeName: 'Innova Crysta',
      seats: 7,
      plateDisplay: 'UK07 AB 1234',
      cityName: 'Dehradun',
      minFare: 1800,
      routeCount: 2,
      localDayRate: rate,
      matchReversed: false,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  for (final w in [300.0, 360.0]) {
    for (final scale in [1.0, 1.3]) {
      final tag = '@${w.toInt()} x$scale';

      testWidgets('local taxi card with day rate keeps View & call $tag', (t) async {
        await _pump(t, SizedBox(height: 300, child: LocalTaxiRailCard(item: _taxi(rate: 3000))), w, scale);
        expect(t.takeException(), isNull);
        expect(find.text(TaxiWaysStrings.viewAndCall), findsOneWidget);
        expect(find.text('View & call'), findsOneWidget);
      });

      testWidgets('local taxi card without day rate keeps View & call $tag', (t) async {
        await _pump(t, SizedBox(height: 300, child: LocalTaxiRailCard(item: _taxi())), w, scale);
        expect(t.takeException(), isNull);
        expect(find.text('View & call'), findsOneWidget);
      });

      testWidgets('taxi owner card keeps Vehicle label $tag', (t) async {
        await _pump(t, TaxiOwnerCard(taxi: _owner()), w, scale);
        expect(t.takeException(), isNull);
        expect(find.text('VEHICLE'), findsOneWidget);
        expect(find.text('Available now'), findsOneWidget);
      });

      testWidgets('stay owner card keeps Locality label and value $tag', (t) async {
        await _pump(t, StayOwnerCard(stay: _stay()), w, scale);
        expect(t.takeException(), isNull);
        expect(find.text('LOCALITY'), findsOneWidget);
        expect(find.text('Bhimtal, Nainital'), findsOneWidget);
        expect(find.text('Accepting guests'), findsOneWidget);
      });
    }
  }
}
