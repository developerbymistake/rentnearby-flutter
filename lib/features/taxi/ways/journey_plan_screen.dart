import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/design/extra/ways_kit.dart';
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

  static Widget header(BuildContext context, {required String title, String? subtitle, Widget? below}) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32)),
        boxShadow: DesignShadows.card,
      ),
      padding: EdgeInsets.fromLTRB(8, top + 6, 16, 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: DesignColors.textStrong, size: 18),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FitnessAppTheme.headline.copyWith(fontSize: 20, letterSpacing: 0.27),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: FitnessAppTheme.caption.copyWith(fontSize: 12),
                    ),
                ]),
              ),
            ]),
            ?below,
          ]),
        ),
      ),
    );
  }

  static Widget invalidBody(Object? raw) {
    final feed = JourneyOpenArgs.feedOf(raw);
    return ListView(children: [
      TripPlanEmpty(
        image: TravelIcon.route,
        title: TripStringsA6.journeyGoneTitle,
        subtitle: TripStringsA6.journeyGoneBody,
        onRetry: feed == null ? () => Get.back() : () => TaxiWaysNavigation.replaceWithFeed(feed),
        retryLabel: feed == null ? TripStringsA6.goBack : TripStringsA6.backToWays,
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
        backgroundColor: DesignColors.scaffold,
        body: Column(children: [
          WaysTopBar(
            animation: WaysKit.topBar(_ac),
            child: JourneyPlanScreen.header(context, title: TaxiWaysStrings.yourJourney),
          ),
          Expanded(child: JourneyPlanScreen.invalidBody(_raw)),
        ]),
      );
    }
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Obx(() {
        final plan = c.plan.value;
        return Column(children: [
          WaysTopBar(animation: WaysKit.topBar(_ac), child: _header(context, c, plan)),
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
          : Padding(
              padding: const EdgeInsets.only(left: 10, top: 10),
              child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                _chip(JourneyPlanController.carsChip(plan, c.chosen, a.people)),
                _chip('${TaxiWaysStrings.viewOnRoad} ›', onTap: () => _openRoad(c)),
              ]),
            ),
    );
  }

  Widget _chip(String text, {VoidCallback? onTap}) {
    if (onTap != null) {
      return PickChip(
        label: text,
        selected: true,
        onTap: onTap,
        activeColor: PickKit.trip,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      );
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(color: DesignColors.scaffold, borderRadius: WaysKit.pillRadius),
      child: Text(text, style: FitnessAppTheme.subtitle.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: DesignColors.textGrey)),
    );
  }

  Widget _content(BuildContext context, JourneyPlanController c, WayPlan plan) {
    if (plan.legs.isEmpty) {
      if (c.loading.value) {
        return ListView(padding: const EdgeInsets.all(16), children: [
          _skel(48),
          const SizedBox(height: 12),
          _skel(150),
          const SizedBox(height: 12),
          _skel(150),
        ]);
      }
      if (c.notFound.value) {
        return ListView(children: [
          TripPlanEmpty(
            image: TravelIcon.route,
            title: TripStringsA6.planGoneTitle,
            subtitle: TripStringsA6.planGoneBody,
            onRetry: () => Get.back(),
            retryLabel: TripStringsA6.backToWays,
          ),
        ]);
      }
      return ListView(children: [
        TripPlanEmpty(
          image: c.offline.value ? TravelIcon.map : TravelIcon.route,
          title: c.offline.value ? TaxiWaysStrings.offlineTitle : TripStringsA6.planEmptyTitle,
          subtitle: c.offline.value ? TaxiWaysStrings.offlineBody : TripStringsA6.planEmptyBody,
          onRetry: c.load,
          retryLabel: TaxiWaysStrings.retry,
        ),
      ]);
    }
    return RefreshIndicator(
      color: DesignColors.primary,
      onRefresh: c.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (c.loading.value) ...[
                  const LinearProgressIndicator(minHeight: 2, color: DesignColors.primary, backgroundColor: Colors.transparent),
                  const SizedBox(height: 10),
                ],
                if (c.offline.value) ...[
                  _enter(1, _offline()),
                  const SizedBox(height: 12),
                ],
                if (c.refreshFailed.value && !c.loading.value) ...[
                  _enter(1, _refreshFailed(c)),
                  const SizedBox(height: 12),
                ],
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

  Widget _skel(double h) => Container(
        decoration: TripLook.card(),
        padding: const EdgeInsets.all(12),
        child: TemplatePlaceholder(height: h - 24 < 8 ? 8 : h - 24, radius: 14),
      );

  Widget _refreshFailed(JourneyPlanController c) {
    final gone = c.notFound.value;
    return WaysBanner(
      icon: Icons.info_outline_rounded,
      text: gone ? TripStringsA6.planGoneTitle : TripStringsA6.refreshFailedTitle,
      trailing: InkWell(
        onTap: gone ? () => Get.back() : c.load,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Center(
            heightFactor: 1,
            child: Text(gone ? TripStringsA6.backToWays : TaxiWaysStrings.retry,
                style: FitnessAppTheme.title.copyWith(fontSize: 12, color: DesignColors.primary)),
          ),
        ),
      ),
    );
  }

  Widget _offline() => const WaysBanner(icon: Icons.wifi_off_rounded, text: TaxiWaysStrings.offlineTitle);
}
