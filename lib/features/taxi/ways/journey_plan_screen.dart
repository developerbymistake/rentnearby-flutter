import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/module_palette.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../widgets/empty_state_view.dart';
import '../../trip/widgets/trip_shimmers.dart';
import '../taxi_option_sets.dart';
import 'change_driver_sheet.dart';
import 'models/taxi_ways_models.dart';
import 'taxi_ways_controller.dart';
import 'taxi_ways_navigation.dart';
import 'taxi_ways_strings.dart';
import '../../trip/trip_strings_steps_a3.dart';
import 'trip_strings_a6.dart';
import 'trip_strings_mcb_a2.dart';
import 'widgets/journey_rail.dart';
import 'widgets/journey_total_bar.dart';

class JourneyPlanScreen extends StatefulWidget {
  const JourneyPlanScreen({super.key});

  @override
  State<JourneyPlanScreen> createState() => _JourneyPlanScreenState();
}

class JourneyPlanLoader {
  final TaxiWaysController c;
  final String planKey;
  final String tag;
  bool loading = false;
  bool failed = false;
  bool offline = false;
  bool refreshFailed = false;
  WayPlan? plan;

  JourneyPlanLoader(this.c, this.planKey, this.tag) : plan = c.planByKey(planKey);

  static JourneyPlanLoader? fromArgs(Object? args) {
    final a = TaxiWaysNavigation.planArgs(args);
    if (a == null || !Get.isRegistered<TaxiWaysController>(tag: a.tag)) return null;
    return JourneyPlanLoader(Get.find<TaxiWaysController>(tag: a.tag), a.planKey, a.tag);
  }

  Future<void> load(VoidCallback onChange) async {
    loading = true;
    failed = false;
    offline = false;
    refreshFailed = false;
    onChange();
    try {
      final d = await c.openPlan(planKey);
      if (d != null) plan = d;
    } catch (e) {
      failed = plan == null;
      offline = DioErrorMapper.isNetworkError(e);
      refreshFailed = plan != null && !offline;
    } finally {
      loading = false;
      onChange();
    }
  }

  static String carsChip(WayPlan p, Map<int, WayDriver> chosen, int people) {
    final total = p.totalWith(chosen, people: people);
    return p.cars <= 1 ? TaxiWaysStrings.oneCarTotal(total) : TaxiWaysStrings.carsAbout(p.cars, total);
  }

  Future<void> changeDriver(BuildContext context, WayLeg leg) async {
    final current = c.chosenFor(planKey, leg.index);
    final picked = await ChangeDriverSheet.show(context, leg: leg, people: c.people.value, current: current);
    if (picked != null) c.choose(planKey, leg.index, picked);
  }
}

class _JourneyPlanScreenState extends State<JourneyPlanScreen> {
  static const double _maxWidth = 720;
  JourneyPlanLoader? _l;

  @override
  void initState() {
    super.initState();
    _l = JourneyPlanLoader.fromArgs(Get.arguments);
    _l?.load(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    if (l == null) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        appBar: AppBar(title: const Text(TaxiWaysStrings.yourJourney)),
        body: ListView(children: [
          EmptyStateView(
            icon: Iconsax.routing_2,
            title: TripStringsA6.journeyGoneTitle,
            subtitle: TripStringsA6.journeyGoneBody,
            onRetry: () => Get.back(),
            retryLabel: TripStringsA6.goBack,
            palette: ModulePalette.taxi,
          ),
        ]),
      );
    }
    final c = l.c;
    final plan = l.plan;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(children: [
        _header(context, l, plan),
        Expanded(child: _content(context, l, plan)),
        if (plan != null && plan.legs.isNotEmpty)
          Obx(() {
            final chosen = c.chosenOf(plan.planKey);
            return JourneyTotalBar(
              total: plan.totalWith(chosen, people: c.people.value),
              askLabel: JourneyAskButton.labelFor(plan.legs.length),
              busy: c.busyPlans.contains(plan.planKey),
              onAsk: () => c.askDrivers(context, plan),
              onSave: () => c.saveJourney(plan),
              onUse: c.forTrip || c.forSegment ? () => c.useForTrip(plan, context: context) : null,
              useLabel: c.forSegment ? TripStringsMcbA2.saveToTrip : TripStringsStepsA3.useForMyTrip,
            );
          }),
      ]),
    );
  }

  Widget _header(BuildContext context, JourneyPlanLoader l, WayPlan? plan) {
    final top = MediaQuery.paddingOf(context).top;
    final c = l.c;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: TaxiColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(8, top + 6, 16, 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text(
                    TaxiWaysStrings.yourJourney,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  if (plan != null)
                    Text(
                      '${TaxiWaysStrings.subtitle(plan.from.name, plan.to.name)} · ${TaxiWaysStrings.dateChip(c.date.value)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                    ),
                ]),
              ),
            ]),
            if (plan != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Obx(() => Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      _chip(JourneyPlanLoader.carsChip(plan, c.chosenOf(plan.planKey), c.people.value)),
                      _chip(
                        '${TaxiWaysStrings.viewOnRoad} ›',
                        onTap: () => TaxiWaysNavigation.openRoad(planKey: l.planKey, controllerTag: l.tag),
                      ),
                    ])),
              ),
            ],
          ]),
        ),
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

  Widget _content(BuildContext context, JourneyPlanLoader l, WayPlan? plan) {
    if (plan == null) {
      if (l.loading) {
        return ListView(padding: const EdgeInsets.all(16), children: [
          TripShimmers.rowBox(height: 48),
          const SizedBox(height: 12),
          TripShimmers.rowBox(height: 150),
          const SizedBox(height: 12),
          TripShimmers.rowBox(height: 150),
        ]);
      }
      return ListView(children: [
        EmptyStateView(
          icon: l.offline ? Iconsax.wifi_square : Iconsax.cloud_cross,
          title: l.offline ? TaxiWaysStrings.offlineTitle : TaxiWaysStrings.loadFailed,
          subtitle: TaxiWaysStrings.offlineBody,
          onRetry: () => l.load(_changed),
          retryLabel: TaxiWaysStrings.retry,
          palette: ModulePalette.taxi,
        ),
      ]);
    }
    final c = l.c;
    if (plan.legs.isEmpty) {
      return ListView(children: [
        EmptyStateView(
          icon: Iconsax.routing_2,
          title: TripStringsA6.planEmptyTitle,
          subtitle: TripStringsA6.planEmptyBody,
          onRetry: () => l.load(_changed),
          retryLabel: TaxiWaysStrings.retry,
          palette: ModulePalette.taxi,
        ),
      ]);
    }
    return RefreshIndicator(
      color: TaxiColors.accent,
      onRefresh: () => l.load(_changed),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (l.loading) ...[
                  const LinearProgressIndicator(minHeight: 2, color: TaxiColors.accent, backgroundColor: Colors.transparent),
                  const SizedBox(height: 10),
                ],
                if (l.offline) ...[
                  _offline(),
                  const SizedBox(height: 12),
                ],
                if (l.refreshFailed && !l.loading) ...[
                  _refreshFailed(l),
                  const SizedBox(height: 12),
                ],
                Obx(() => JourneyRail(
                      plan: plan,
                      chosen: c.chosenOf(plan.planKey),
                      date: c.date.value,
                      onChangeDriver: (leg) => l.changeDriver(context, leg),
                    )),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _refreshFailed(JourneyPlanLoader l) => Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Iconsax.info_circle, size: 18, color: AppColors.warningText),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              TripStringsA6.refreshFailedTitle,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText),
            ),
          ),
          TextButton(
            onPressed: () => l.load(_changed),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: TaxiColors.accentDark),
            child: const Text(TaxiWaysStrings.retry, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
      );

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
