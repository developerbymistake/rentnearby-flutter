import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_journey_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/widgets/trip_journey_compact.dart';
import 'package:bakhli/features/trip/widgets/trip_popular_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../golden_support.dart';

class _FakeCatalog extends TripCityCatalog {
  @override
  void warmFromDisk() {}

  @override
  Future<List<TripCityModel>> load({bool force = false}) async => popular();

  @override
  List<TripCityModel> popular({String? stateName}) => [
        for (var i = 0; i < 6; i++)
          TripCityModel(
              cityKey: i,
              name: 'Mussoorie and a very long destination name $i',
              stateName: 'Uttarakhand',
              latitude: 1,
              longitude: 1,
              isPopularDestination: true,
              status: i == 2 ? TripCityStatus.notReady : TripCityStatus.ready),
      ];
}

Widget _host(Widget child, {required double width, required double scale, bool reduce = false}) => MaterialApp(
      theme: ThemeData(fontFamily: 'WorkSans'),
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 900), textScaler: TextScaler.linear(scale), disableAnimations: reduce),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

double _opacityOf(Finder f) {
  var v = 1.0;
  for (final e in find.ancestor(of: f, matching: find.byType(Opacity)).evaluate()) {
    v *= (e.widget as Opacity).opacity;
  }
  return v;
}

double _scaled(double scale, double v) => TextScaler.linear(scale).scale(v);

const _leg = TripJourneyLeg(
    legIndex: 1, fromName: 'Delhi', toName: 'Nainital', taxiId: 't', driverName: 'Ramesh Kumar Negi', listedFare: 5200, phone: '9876543210');
const _leg2 = TripJourneyLeg(
    legIndex: 2, fromName: 'Nainital', toName: 'Mussoorie', taxiId: 't2', driverName: 'Suresh', driverAvailable: false, listedFare: 3100);

TripJourney _journey(List<TripJourneyLeg> legs) => TripJourney(
    id: 'j', role: TripStepRole.gettingThere, fromName: 'Delhi', toName: legs.last.toName, date: DateTime(2026, 12, 1), legs: legs);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });
  tearDown(Get.reset);

  for (final reduce in [true, false]) {
    testWidgets('RailReveal ends fully visible reduce=$reduce', (t) async {
      setGoldenView(t);
      const card = Key('c');
      await t.pumpWidget(_host(
          SizedBox(
              height: 80,
              child: RailReveal(itemCount: 3, itemBuilder: (_, i) => SizedBox(key: i == 0 ? card : null, width: 100, height: 40))),
          width: 360,
          scale: 1,
          reduce: reduce));
      await t.pumpAndSettle();
      expect(_opacityOf(find.byKey(card)), 1.0);
      expect(t.takeException(), isNull);
    });

    testWidgets('KitRouteReveal settles and keeps child reduce=$reduce', (t) async {
      setGoldenView(t);
      await t.pumpWidget(_host(const KitRouteReveal(child: Text('route')), width: 360, scale: 1, reduce: reduce));
      await t.pumpAndSettle();
      expect(find.text('route'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  for (final w in [300.0, 360.0, 412.0, 560.0]) {
    for (final scale in [1.0, 1.3]) {
      final tag = '@${w.toInt()} x$scale';
      testWidgets('TripPopularRail $tag', (t) async {
        Get.put<TripCityCatalog>(_FakeCatalog(), permanent: true);
        setGoldenView(t, Size(w, 900));
        await t.pumpWidget(_host(const TripPopularRail(), width: w, scale: scale));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.textContaining('Mussoorie'), findsWidgets);
        expect(_opacityOf(find.textContaining('Mussoorie').first), 1.0);
      });

      testWidgets('spots filter row and chain chips $tag', (t) async {
        setGoldenView(t, Size(w, 900));
        await t.pumpWidget(_host(
            Column(children: [
              FixedFilterBar(
                height: _scaled(scale, 60),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 8, KitMetrics.gutter, 8),
                  children: [
                    for (final l in ['All', 'Lakes', 'Temples', 'Markets'])
                      Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: KitChoiceChip(label: l, selected: l == 'All', onTap: () {}, tone: KitTone.trip)),
                  ],
                ),
              ),
              SizedBox(
                height: _scaled(scale, 52),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 12, KitMetrics.gutter, 4),
                  children: const [
                    KitChainChip(label: 'Nainital (3 spots)', number: 1, current: false, done: true, onTap: null, tone: KitTone.trip),
                    SizedBox(width: 8),
                    KitChainChip(label: 'Mussoorie', number: 2, current: true, done: false, onTap: null, tone: KitTone.trip),
                    SizedBox(width: 8),
                    KitChainChip(label: 'Rishikesh', number: 3, current: false, done: false, onTap: null, tone: KitTone.trip),
                  ],
                ),
              ),
            ]),
            width: w,
            scale: scale));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        for (final c in find.byType(KitChainChip).evaluate()) {
          expect((c.renderObject as RenderBox).size.height, lessThanOrEqualTo(_scaled(scale, 52) - 16));
        }
      });

      for (final legs in [
        [_leg],
        [_leg, _leg2],
      ]) {
        testWidgets('TripJourneyCompact ${legs.length} legs $tag', (t) async {
          setGoldenView(t, Size(w, 1200));
          for (final dense in [false, true]) {
            await t.pumpWidget(_host(
                Padding(padding: const EdgeInsets.all(20), child: TripJourneyCompact(journey: _journey(legs), dense: dense)),
                width: w,
                scale: scale));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            expect(find.textContaining('Delhi'), findsWidgets);
          }
        });
      }
    }
  }
}
