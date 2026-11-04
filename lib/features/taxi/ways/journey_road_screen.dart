import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/module_palette.dart';
import '../../../widgets/empty_state_view.dart';
import '../../trip/widgets/trip_shimmers.dart';
import '../taxi_option_sets.dart';
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

class _JourneyRoadScreenState extends State<JourneyRoadScreen> {
  static const double _maxWidth = 720;
  static const double _sheetMin = 0.22;
  static const double _sheetStart = 0.4;

  JourneyPlanLoader? _l;
  int? _selected;

  @override
  void initState() {
    super.initState();
    _l = JourneyPlanLoader.fromArgs(Get.arguments);
    _l?.load(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _select(int legIndex) => setState(() => _selected = _selected == legIndex ? null : legIndex);

  @override
  Widget build(BuildContext context) {
    final l = _l;
    final plan = l?.plan;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(children: [
        _header(context, plan),
        Expanded(child: l == null ? _invalid() : _body(context, l, plan)),
      ]),
    );
  }

  Widget _invalid() => ListView(children: [
        EmptyStateView(
          icon: Iconsax.routing_2,
          title: TripStringsA6.journeyGoneTitle,
          subtitle: TripStringsA6.journeyGoneBody,
          onRetry: () => Get.back(),
          retryLabel: TripStringsA6.goBack,
          palette: ModulePalette.taxi,
        ),
      ]);

  Widget _header(BuildContext context, WayPlan? plan) {
    final top = MediaQuery.paddingOf(context).top;
    final sub = plan == null
        ? null
        : '${TaxiWaysStrings.subtitle(plan.from.name, plan.to.name)} · '
            '${TaxiWaysStrings.carsCount(plan.cars)}';
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
          child: Row(children: [
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
                  TaxiWaysStrings.onTheRoad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                if (sub != null)
                  Text(
                    sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, JourneyPlanLoader l, WayPlan? plan) {
    if (plan == null) {
      if (l.loading) {
        return ListView(padding: const EdgeInsets.all(16), children: [
          TripShimmers.rowBox(height: 60),
          const SizedBox(height: 12),
          TripShimmers.rowBox(height: 120),
          const SizedBox(height: 12),
          TripShimmers.rowBox(height: 120),
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
                        chosen: c.chosenOf(plan.planKey),
                        selectedLeg: _selected,
                        onSelectLeg: _select,
                      )),
                ),
              ),
            ],
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: _sheetStart,
          minChildSize: _sheetMin,
          maxChildSize: 0.9,
          builder: (context, scroll) => _sheet(context, l, plan, scroll),
        ),
      ]);
    });
  }

  Widget _sheet(BuildContext context, JourneyPlanLoader l, WayPlan plan, ScrollController scroll) {
    final c = l.c;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: AppColors.textDark.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, -4))],
      ),
      child: Obx(() {
        final chosen = c.chosenOf(plan.planKey);
        final busy = c.busyPlans.contains(plan.planKey);
        return ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + AppInsets.bottomViewPadding(context)),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
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
                          onChange: () => l.changeDriver(context, leg),
                        ),
                      ),
                  const SizedBox(height: 4),
                  JourneyAskButton(
                    label: JourneyAskButton.labelFor(plan.legs.length),
                    busy: busy,
                    onPressed: () => c.askDrivers(context, plan),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    TaxiWaysStrings.payLine,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
                  ),
                ]),
              ),
            ),
          ],
        );
      }),
    );
  }
}
