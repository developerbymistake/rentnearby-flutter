import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import '../../trip/trip_strings_steps_a3.dart';
import 'journey_plan_controller.dart';
import 'models/taxi_ways_models.dart';
import 'taxi_ways_navigation.dart';
import 'taxi_ways_strings.dart';
import 'trip_strings_a6.dart';
import 'widgets/journey_rail.dart';
import 'widgets/journey_total_bar.dart';

class JourneyPlanScreen extends StatefulWidget {
  const JourneyPlanScreen({super.key});

  static Widget header(BuildContext context, {required String title, String? subtitle, Widget? below, String art = JourneyArt.automobile}) =>
      JourneyHeader3D(title: title, subtitle: subtitle, art: art, bottom: below);

  static Widget invalidBody(Object? raw) {
    final feed = JourneyOpenArgs.feedOf(raw);
    return ListView(padding: EdgeInsets.zero, children: [
      JourneyEmpty3D(
        art: ListingArt.compass,
        title: TripStringsA6.journeyGoneTitle,
        body: TripStringsA6.journeyGoneBody,
        onAction: feed == null ? () => Get.back() : () => TaxiWaysNavigation.replaceWithFeed(feed),
        actionLabel: feed == null ? TripStringsA6.goBack : TripStringsA6.backToWays,
      ),
    ]);
  }

  static void logInvalid(String screen, Object? raw) {
    if (kDebugMode) debugPrint('$screen: invalid arguments, ${JourneyOpenArgs.invalidReason(raw)}');
  }

  @override
  State<JourneyPlanScreen> createState() => _JourneyPlanScreenState();
}

class _JourneyPlanScreenState extends State<JourneyPlanScreen> with TickerProviderStateMixin {
  static const double _maxWidth = 720;

  JourneyPlanController? _c;
  String? _tag;
  Object? _raw;
  bool _read = false;
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
      JourneyPlanScreen.logInvalid('JourneyPlanScreen', _raw);
      return;
    }
    _tag = 'journey-plan-${identityHashCode(route)}';
    final c = Get.put(JourneyPlanController(args), tag: _tag);
    _c = c;
  }

  @override
  void dispose() {
    _ac.dispose();
    if (_tag != null) Get.delete<JourneyPlanController>(tag: _tag);
    super.dispose();
  }

  Future<void> _openRoad(JourneyPlanController c) async {
    final r = await TaxiWaysNavigation.openRoad(c.currentArgs);
    if (r is Map<int, WayDriver>) c.setChosen(r);
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) {
      return Scaffold(
        backgroundColor: ListingPalette.coral.page,
        body: Column(children: [
          TemplateEntrance(animation: templateInterval(_ac, 0, 2), animationController: _ac, offset: 0, child: JourneyPlanScreen.header(context, title: TaxiWaysStrings.yourJourney)),
          Expanded(child: JourneyPlanScreen.invalidBody(_raw)),
        ]),
      );
    }
    return Scaffold(
      backgroundColor: ListingPalette.coral.page,
      body: Obx(() {
        final plan = c.plan.value;
        return Column(children: [
          if (plan.legs.isEmpty) TemplateEntrance(animation: templateInterval(_ac, 0, 3), animationController: _ac, offset: 0, child: _header(context, c, plan)),
          Expanded(child: _content(context, c, plan)),
          if (plan.legs.isNotEmpty)
            TemplateEntrance(
              animation: templateInterval(_ac, 2, 3),
              animationController: _ac,
              offset: -30,
              child: JourneyTotalBar(
                total: plan.totalWith(c.chosen, people: c.args.people),
                askLabel: JourneyAskButton.labelFor(plan.legs.length),
                busy: c.isBusy || c.loading.value,
                onAsk: () => c.askDrivers(context),
                onSave: c.args.inTrip ? null : c.saveJourney,
                onUse: c.args.inTrip ? () => c.useForTrip(context) : null,
                useLabel: TripStringsStepsA3.useForMyTrip,
              ),
            ),
        ]);
      }),
    );
  }

  Widget _header(BuildContext context, JourneyPlanController c, WayPlan plan) {
    final a = c.args;
    final from = wayNameOr(plan.legs.isEmpty || plan.from.name.trim().isEmpty ? a.from.name : plan.from.name,
        a.from.key, start: true, end: false);
    final to = wayNameOr(plan.legs.isEmpty || plan.to.name.trim().isEmpty ? a.to.name : plan.to.name,
        a.to.key, start: false, end: true);
    return JourneyPlanScreen.header(
      context,
      title: TaxiWaysStrings.yourJourney,
      subtitle: '${TaxiWaysStrings.subtitle(from, to)} · ${TaxiWaysStrings.dateChip(a.date)}',
      below: plan.legs.isEmpty
          ? null
          : Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              JourneyChip3D(label: JourneyPlanController.carsChip(plan, c.chosen, a.people)),
              JourneyChip3D(label: '${TaxiWaysStrings.viewOnRoad} ›', filled: true, onTap: () => _openRoad(c)),
            ]),
    );
  }

  Widget _content(BuildContext context, JourneyPlanController c, WayPlan plan) {
    if (plan.legs.isEmpty) {
      if (c.loading.value) {
        return ListView(padding: EdgeInsets.zero, children: const [JourneyPillSkeleton(), JourneyCardSkeleton(), JourneyCardSkeleton()]);
      }
      if (c.notFound.value) {
        return ListView(padding: EdgeInsets.zero, children: [
          JourneyEmpty3D(
            art: ListingArt.compass,
            title: TripStringsA6.planGoneTitle,
            body: TripStringsA6.planGoneBody,
            onAction: () => Get.back(),
            actionLabel: TripStringsA6.backToWays,
          ),
        ]);
      }
      return ListView(padding: EdgeInsets.zero, children: [
        JourneyEmpty3D(
          art: c.offline.value ? ListingArt.worldMap : ListingArt.clipboard,
          title: c.offline.value ? TaxiWaysStrings.offlineTitle : TripStringsA6.planEmptyTitle,
          body: c.offline.value ? TaxiWaysStrings.offlineBody : TripStringsA6.planEmptyBody,
          onAction: c.load,
          actionLabel: TaxiWaysStrings.retry,
        ),
      ]);
    }
    return RefreshIndicator(
      color: ListingPalette.coral.g2,
      onRefresh: c.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          TemplateEntrance(animation: templateInterval(_ac, 0, 3), animationController: _ac, offset: 0, child: _header(context, c, plan)),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (c.loading.value)
                  LinearProgressIndicator(minHeight: 2, color: ListingPalette.coral.g2, backgroundColor: Colors.transparent),
                if (c.offline.value) _enter(1, const JourneyBanner3D(error: true, art: ListingArt.worldMap, text: TaxiWaysStrings.offlineTitle)),
                if (c.refreshFailed.value && !c.loading.value) _enter(1, _refreshFailed(c)),
                JourneyRail(
                  plan: plan,
                  chosen: c.chosen,
                  date: c.args.date,
                  onChangeDriver: (leg) => c.changeDriver(context, leg),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _enter(int i, Widget child) => TemplateEntrance(
        animation: templateInterval(_ac, i, 3),
        animationController: _ac,
        child: child,
      );

  Widget _refreshFailed(JourneyPlanController c) {
    final gone = c.notFound.value;
    return JourneyBanner3D(
      art: ListingArt.clipboard,
      text: gone ? TripStringsA6.planGoneTitle : TripStringsA6.refreshFailedTitle,
      linkLabel: gone ? TripStringsA6.backToWays : TaxiWaysStrings.retry,
      onLink: gone ? () => Get.back() : c.load,
    );
  }
}
