import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import '../../../config/app_insets.dart';
import 'journey_plan_controller.dart';
import 'journey_plan_screen.dart';
import 'models/taxi_ways_models.dart';
import 'taxi_ways_strings.dart';
import 'trip_strings_a6.dart';
import 'widgets/journey_driver_card.dart';
import 'widgets/journey_rail.dart';
import 'widgets/journey_total_bar.dart';
import 'widgets/road_view.dart';

class JourneyRoadScreen extends StatefulWidget {
  const JourneyRoadScreen({super.key});

  @override
  State<JourneyRoadScreen> createState() => _JourneyRoadScreenState();
}

class _JourneyRoadScreenState extends State<JourneyRoadScreen> with TickerProviderStateMixin {
  static const double _maxWidth = 720;
  static const double _sheetMin = 0.22;
  static const double _sheetStart = 0.34;

  JourneyPlanController? _c;
  String? _tag;
  Object? _raw;
  bool _read = false;
  int? _selected;
  late final AnimationController _ac = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..forward();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_read) return;
    _read = true;
    final route = ModalRoute.of(context);
    _raw = route?.settings.arguments;
    final args = JourneyOpenArgs.of(_raw);
    if (args == null) {
      JourneyPlanScreen.logInvalid('JourneyRoadScreen', _raw);
      return;
    }
    _tag = 'journey-road-${identityHashCode(route)}';
    final c = Get.put(JourneyPlanController(args), tag: _tag);
    _c = c;
  }

  @override
  void dispose() {
    _ac.dispose();
    if (_tag != null) Get.delete<JourneyPlanController>(tag: _tag);
    super.dispose();
  }

  void _select(int legIndex) => setState(() => _selected = _selected == legIndex ? null : legIndex);

  void _close() {
    final c = _c;
    Get.back(result: c == null ? null : Map<int, WayDriver>.from(c.chosen));
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) {
      return Scaffold(
        backgroundColor: ListingPalette.coral.page,
        body: Column(children: [
          TemplateEntrance(animation: templateInterval(_ac, 0, 2), animationController: _ac, offset: 0, child: JourneyPlanScreen.header(context, title: TaxiWaysStrings.onTheRoad, art: ListingArt.worldMap)),
          Expanded(child: JourneyPlanScreen.invalidBody(_raw)),
        ]),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: ListingPalette.coral.page,
        body: Obx(() {
          final plan = c.plan.value;
          return Column(children: [
            TemplateEntrance(
              animation: templateInterval(_ac, 0, 2),
              animationController: _ac,
              offset: 0,
              child: JourneyPlanScreen.header(
                context,
                title: TaxiWaysStrings.onTheRoad,
                art: ListingArt.worldMap,
                subtitle: plan.legs.isEmpty
                    ? TaxiWaysStrings.subtitle(c.args.from.name, c.args.to.name)
                    : '${TaxiWaysStrings.subtitle(plan.from.name, plan.to.name)} · ${TaxiWaysStrings.carsCount(plan.carHires)}',
              ),
            ),
            Expanded(child: _body(context, c, plan)),
          ]);
        }),
      ),
    );
  }

  Widget _body(BuildContext context, JourneyPlanController c, WayPlan plan) {
    if (plan.legs.isEmpty) {
      if (c.loading.value) {
        return ListView(padding: EdgeInsets.zero, children: const [JourneyPillSkeleton(), JourneyCardSkeleton(), JourneyCardSkeleton()]);
      }
      return ListView(padding: EdgeInsets.zero, children: [
        JourneyEmpty3D(
          art: ListingArt.worldMap,
          title: c.offline.value ? TaxiWaysStrings.offlineTitle : TaxiWaysStrings.loadFailed,
          body: TaxiWaysStrings.offlineBody,
          onAction: c.load,
          actionLabel: TaxiWaysStrings.retry,
        ),
      ]);
    }
    return LayoutBuilder(builder: (context, box) {
      final reserve = box.maxHeight * _sheetMin + 16;
      return Stack(children: [
        Positioned.fill(
          child: ListView(
            padding: EdgeInsets.only(bottom: reserve),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxWidth),
                  child: Obx(() => RoadView(
                        plan: plan,
                        chosen: Map<int, WayDriver>.from(c.chosen),
                        people: c.args.people,
                        selectedLeg: _selected,
                        onSelectLeg: _select,
                      )),
                ),
              ),
            ],
          ),
        ),
        FadeTransition(
          opacity: templateInterval(_ac, 1, 2),
          child: DraggableScrollableSheet(
            initialChildSize: _sheetStart,
            minChildSize: _sheetMin,
            maxChildSize: 0.9,
            builder: (context, scroll) => _sheet(context, c, plan, scroll),
          ),
        ),
      ]);
    });
  }

  Widget _sheet(BuildContext context, JourneyPlanController c, WayPlan plan, ScrollController scroll) {
    return Container(
      decoration: const BoxDecoration(
        color: DesignColors.sheet,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        boxShadow: JourneyInk.sheetShadow,
      ),
      child: Obx(() {
        final chosen = c.chosen;
        final busy = c.isBusy;
        final legs = plan.legs;
        return ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(0, 8, 0, 16 + AppInsets.bottomViewPadding(context)),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(color: Ink3D.line, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final (i, leg) in legs.indexed)
                    if ((chosen[leg.index] ?? leg.firstDriver) != null) ..._legCard(context, c, leg, (chosen[leg.index] ?? leg.firstDriver)!, i, legs.length),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: JourneyAskButton(
                      label: JourneyAskButton.labelFor(legs.length),
                      busy: busy,
                      onPressed: () => c.askDrivers(context),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: JourneyPayLine(TaxiWaysStrings.payLine)),
                ]),
              ),
            ),
          ],
        );
      }),
    );
  }

  List<Widget> _legCard(BuildContext context, JourneyPlanController c, WayLeg leg, WayDriver d, int i, int count) {
    final seats = TripStringsA6.legSeats(leg);
    return [
      JourneySlimCard3D(
        tone: JourneyRail.toneFor(leg.index),
        art: JourneyArt.forVehicle(d.vehicleTypeName, d.seats),
        tag: count > 1 ? TaxiWaysStrings.carOf(i + 1, count) : null,
        title: d.driverName,
        subtitle: [
          JourneyDriverCard.vehicleLine(d),
          [JourneyDriverCard.fareText(d), TaxiWaysStrings.toPlace(leg.to.name)].where((e) => e.isNotEmpty).join(' · '),
          ?seats,
        ],
        picked: _selected == leg.index,
        onTap: () => _select(leg.index),
        callTooltip: TaxiWaysStrings.callName(d.driverName),
        onCall: () => JourneyDriverCard.call(d),
        semanticsLabel: '${d.driverName}, ${TaxiWaysStrings.subtitle(leg.from.name, leg.to.name)}',
      ),
      if (leg.otherCount > 0)
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: JourneyChip3D(label: '${TaxiWaysStrings.otherDrivers(leg.otherCount)} ›', onTap: () => c.changeDriver(context, leg)),
          ),
        ),
    ];
  }
}
