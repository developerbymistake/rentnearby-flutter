import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../widgets/empty_state_view.dart';
import '../../taxi/guest/taxi_card.dart';
import '../../taxi/guest/taxi_navigation.dart';
import '../../taxi/models/taxi_browse_item.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_supply_controller.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../widgets/trip_back_to_plan_bar.dart';
import '../widgets/trip_route_strip.dart';
import '../widgets/trip_taxi_stay_toggle.dart';

class TripTaxiScreen extends StatefulWidget {
  const TripTaxiScreen({super.key});

  @override
  State<TripTaxiScreen> createState() => _TripTaxiScreenState();
}

class _TripTaxiScreenState extends State<TripTaxiScreen> {
  late final TripPlanController _plan;
  late final TripSupplyController _supply;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _plan = TripPlanController.to;
    _plan.openPages++;
    _supply = TripSupplyController.to;
    final args = Get.arguments;
    final day = args is Map ? args['day'] as int? : null;
    if (day != null) _supply.setDay(day);
    _supply.ensureTaxis();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    if (Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), _plan)) {
      _plan.openPages--;
      _plan.releaseIfIdle();
    }
    super.dispose();
  }

  void _onScroll() {
    final p = _scroll.position;
    if (p.maxScrollExtent > 0 && p.pixels >= p.maxScrollExtent - 300) _supply.loadMoreTaxis();
  }

  void _open(TaxiBrowseItem t) => TaxiNavigation.openDetail(
        t.id,
        whatsAppMessage: _plan.whatsAppMessage(_supply.day.value, t.driverName),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(child: _buildTop()),
                _buildBody(),
                SliverToBoxAdapter(child: _buildFooter()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Obx(() {
        final d = _supply.day.value;
        final taxi = _plan.plan.value?.dayAt(d)?.taxi;
        if (taxi == null) return const SizedBox.shrink();
        return TripBackToPlanBar(text: '${taxi.name} selected for Day $d');
      }),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: const BoxDecoration(
        gradient: TripColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(12, top + 8, 20, 18),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Taxi for Day ${_supply.day.value}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _plan.cityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildTop() {
    return Obx(() {
      final d = _supply.day.value;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          children: [
            TripTaxiStayToggle(selected: TripSupplyKind.taxi, day: d),
            const SizedBox(height: 12),
            TripRouteStrip(day: d, onDayChanged: _supply.setDay),
          ],
        ),
      );
    });
  }

  Widget _buildBody() {
    return Obx(() {
      final items = _supply.taxis;
      final d = _supply.day.value;
      if (items.isEmpty) {
        if (_supply.taxiLoading.value) {
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverList.separated(
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, _) => const TaxiCardSkeleton(),
            ),
          );
        }
        final failed = _supply.taxiFailed.value;
        return SliverToBoxAdapter(
          child: EmptyStateView(
            icon: failed ? Iconsax.cloud_cross : Iconsax.car,
            title: failed ? TripStrings.taxisFailed : TripStrings.noTaxis,
            subtitle: failed ? TripStrings.checkConnection : TripStrings.noTaxisSubtitle(_plan.cityName),
            onRetry: failed ? () => _supply.loadTaxis() : null,
            palette: TripColors.palette,
          ),
        );
      }
      final chosenId = _plan.plan.value?.dayAt(d)?.taxi?.taxiId;
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final t = items[i];
            return TaxiCard(
              key: ValueKey(t.id),
              item: t,
              onOpen: () => _open(t),
              onSelect: () => _plan.selectTaxi(d, t),
              selected: chosenId == t.id,
            );
          },
        ),
      );
    });
  }

  Widget _buildFooter() {
    return Obx(() => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: SizedBox(
            height: 24,
            child: _supply.taxiLoadingMore.value
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: TripColors.accent),
                    ),
                  )
                : null,
          ),
        ));
  }
}
