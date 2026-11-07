import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/module_palette.dart';
import '../../../widgets/empty_state_view.dart';
import '../../trip/trip_strings_steps_a3.dart';
import '../../trip/widgets/trip_shimmers.dart';
import '../taxi_option_sets.dart';
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
      decoration: const BoxDecoration(
        gradient: TaxiColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
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
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
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
      EmptyStateView(
        icon: Iconsax.routing_2,
        title: TripStringsA6.journeyGoneTitle,
        subtitle: TripStringsA6.journeyGoneBody,
        onRetry: feed == null ? () => Get.back() : () => TaxiWaysNavigation.replaceWithFeed(feed),
        retryLabel: feed == null ? TripStringsA6.goBack : TripStringsA6.backToWays,
        palette: ModulePalette.taxi,
      ),
    ]);
  }

  static void logInvalid(String screen, Object? raw) {
    if (kDebugMode) debugPrint('$screen: invalid arguments, ${JourneyOpenArgs.invalidReason(raw)}');
  }

  @override
  State<JourneyPlanScreen> createState() => _JourneyPlanScreenState();
}

class _JourneyPlanScreenState extends State<JourneyPlanScreen> {
  static const double _maxWidth = 720;

  JourneyPlanController? _c;
  String? _tag;
  Object? _raw;
  bool _read = false;

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
    _c = Get.put(JourneyPlanController(args), tag: _tag);
  }

  @override
  void dispose() {
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
        backgroundColor: AppColors.scaffoldBg,
        body: Column(children: [
          JourneyPlanScreen.header(context, title: TaxiWaysStrings.yourJourney),
          Expanded(child: JourneyPlanScreen.invalidBody(_raw)),
        ]),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Obx(() {
        final plan = c.plan.value;
        return Column(children: [
          _header(context, c, plan),
          Expanded(child: _content(context, c, plan)),
          if (plan.legs.isNotEmpty)
            JourneyTotalBar(
              total: plan.totalWith(c.chosen, people: c.args.people),
              askLabel: JourneyAskButton.labelFor(plan.legs.length),
              busy: c.isBusy || c.loading.value,
              onAsk: () => c.askDrivers(context),
              onSave: c.args.inTrip ? null : c.saveJourney,
              onUse: c.args.inTrip ? () => c.useForTrip(context) : null,
              useLabel: TripStringsStepsA3.useForMyTrip,
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

  Widget _chip(String text, {VoidCallback? onTap}) => Material(
        color: onTap != null ? Colors.white : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  text,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: onTap != null ? TaxiColors.accentDark : Colors.white,
                  ),
                ),
              ]),
            ),
          ),
        ),
      );

  Widget _content(BuildContext context, JourneyPlanController c, WayPlan plan) {
    if (plan.legs.isEmpty) {
      if (c.loading.value) {
        return ListView(padding: const EdgeInsets.all(16), children: [
          TripShimmers.rowBox(height: 48),
          const SizedBox(height: 12),
          TripShimmers.rowBox(height: 150),
          const SizedBox(height: 12),
          TripShimmers.rowBox(height: 150),
        ]);
      }
      if (c.notFound.value) {
        return ListView(children: [
          EmptyStateView(
            icon: Iconsax.routing_2,
            title: TripStringsA6.planGoneTitle,
            subtitle: TripStringsA6.planGoneBody,
            onRetry: () => Get.back(),
            retryLabel: TripStringsA6.backToWays,
            palette: ModulePalette.taxi,
          ),
        ]);
      }
      return ListView(children: [
        EmptyStateView(
          icon: c.offline.value ? Iconsax.wifi_square : Iconsax.routing_2,
          title: c.offline.value ? TaxiWaysStrings.offlineTitle : TripStringsA6.planEmptyTitle,
          subtitle: c.offline.value ? TaxiWaysStrings.offlineBody : TripStringsA6.planEmptyBody,
          onRetry: c.load,
          retryLabel: TaxiWaysStrings.retry,
          palette: ModulePalette.taxi,
        ),
      ]);
    }
    return RefreshIndicator(
      color: TaxiColors.accent,
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
                  const LinearProgressIndicator(minHeight: 2, color: TaxiColors.accent, backgroundColor: Colors.transparent),
                  const SizedBox(height: 10),
                ],
                if (c.offline.value) ...[
                  _offline(),
                  const SizedBox(height: 12),
                ],
                if (c.refreshFailed.value && !c.loading.value) ...[
                  _refreshFailed(c),
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

  Widget _refreshFailed(JourneyPlanController c) {
    final gone = c.notFound.value;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Iconsax.info_circle, size: 18, color: AppColors.warningText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            gone ? TripStringsA6.planGoneTitle : TripStringsA6.refreshFailedTitle,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText),
          ),
        ),
        TextButton(
          onPressed: gone ? () => Get.back() : c.load,
          style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: TaxiColors.accentDark),
          child: Text(gone ? TripStringsA6.backToWays : TaxiWaysStrings.retry,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _offline() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Iconsax.wifi_square, size: 18, color: AppColors.warningText),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              TaxiWaysStrings.offlineTitle,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText),
            ),
          ),
        ]),
      );
}
