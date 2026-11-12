import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/design/extra/ways_kit.dart';
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
  static const double _sheetStart = 0.4;

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
        backgroundColor: DesignColors.scaffold,
        body: Column(children: [
          WaysTopBar(
            animation: WaysKit.topBar(_ac),
            child: JourneyPlanScreen.header(context, title: TaxiWaysStrings.onTheRoad),
          ),
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
        backgroundColor: DesignColors.scaffold,
        body: Obx(() {
          final plan = c.plan.value;
          return Column(children: [
            WaysTopBar(
              animation: WaysKit.topBar(_ac),
              child: JourneyPlanScreen.header(
                context,
                title: TaxiWaysStrings.onTheRoad,
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
        return ListView(padding: const EdgeInsets.all(16), children: [
          _skel(60),
          const SizedBox(height: 12),
          _skel(120),
          const SizedBox(height: 12),
          _skel(120),
        ]);
      }
      return ListView(children: [
        TripPlanEmpty(
          image: c.offline.value ? TravelIcon.map : TravelIcon.route,
          title: c.offline.value ? TaxiWaysStrings.offlineTitle : TaxiWaysStrings.loadFailed,
          subtitle: TaxiWaysStrings.offlineBody,
          onRetry: c.load,
          retryLabel: TaxiWaysStrings.retry,
        ),
      ]);
    }
    return LayoutBuilder(builder: (context, box) {
      final reserve = box.maxHeight * _sheetMin + 16;
      return Stack(children: [
        Positioned.fill(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, reserve),
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
        color: DesignColors.surface,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        boxShadow: WaysKit.topShadow,
      ),
      child: Obx(() {
        final chosen = c.chosen;
        final busy = c.isBusy;
        return ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + AppInsets.bottomViewPadding(context)),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: DesignColors.textMuted.withValues(alpha: Alpha.half), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final leg in plan.legs)
                    if ((chosen[leg.index] ?? leg.firstDriver) != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: JourneyDriverCard(
                          driver: (chosen[leg.index] ?? leg.firstDriver)!,
                          color: JourneyRail.colorFor(leg.index),
                          caption: '${TaxiWaysStrings.subtitle(leg.from.name, leg.to.name)} · '
                              '${JourneyDriverCard.vehicleLine((chosen[leg.index] ?? leg.firstDriver)!)}',
                          selected: _selected == leg.index,
                          onTap: () => _select(leg.index),
                          otherCount: leg.otherCount,
                          seatsNote: TripStringsA6.legSeats(leg),
                          onChange: () => c.changeDriver(context, leg),
                        ),
                      ),
                  const SizedBox(height: 4),
                  JourneyAskButton(
                    label: JourneyAskButton.labelFor(plan.legs.length),
                    busy: busy,
                    onPressed: () => c.askDrivers(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    TaxiWaysStrings.payLine,
                    textAlign: TextAlign.center,
                    style: FitnessAppTheme.caption.copyWith(fontSize: 11),
                  ),
                ]),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _skel(double h) => Container(
        decoration: TripLook.card(),
        padding: const EdgeInsets.all(12),
        child: TemplatePlaceholder(height: h - 24, radius: 14),
      );
}
