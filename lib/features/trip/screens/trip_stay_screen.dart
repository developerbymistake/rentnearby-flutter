import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_routes.dart';
import '../../../models/browse_item.dart';
import '../../../widgets/empty_state_view.dart';
import '../../../widgets/nearby_item_row.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_supply_controller.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../utils/trip_format.dart';
import '../widgets/trip_back_to_plan_bar.dart';
import '../widgets/trip_route_strip.dart';
import '../widgets/trip_shimmers.dart';
import '../widgets/trip_taxi_stay_toggle.dart';

class TripStayScreen extends StatefulWidget {
  const TripStayScreen({super.key});

  @override
  State<TripStayScreen> createState() => _TripStayScreenState();
}

class _TripStayScreenState extends State<TripStayScreen> {
  late final TripPlanController _plan;
  late final TripSupplyController _supply;

  @override
  void initState() {
    super.initState();
    _plan = TripPlanController.to;
    _plan.openPages++;
    _supply = TripSupplyController.to;
    final args = Get.arguments;
    final day = args is Map ? args['day'] as int? : null;
    if (day != null) _supply.setDay(day);
    _supply.ensureStays();
  }

  @override
  void dispose() {
    if (Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), _plan)) {
      _plan.openPages--;
      _plan.releaseIfIdle();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildTop()),
                _buildBody(),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Obx(() {
        final stay = _plan.plan.value?.dayAt(_supply.day.value)?.stay;
        if (stay == null) return const SizedBox.shrink();
        return TripBackToPlanBar(text: '${stay.name} selected');
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
                      'Stay for Day ${_supply.day.value}',
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
            TripTaxiStayToggle(selected: TripSupplyKind.stay, day: d),
            const SizedBox(height: 12),
            TripRouteStrip(
              day: d,
              text: 'Near your Day $d spots · sorted by distance',
              onDayChanged: _supply.setDay,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildBody() {
    return Obx(() {
      final items = _supply.stays;
      final d = _supply.day.value;
      if (_supply.stayLoading.value) {
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverList.separated(
            itemCount: 5,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, _) => TripShimmers.rowBox(height: 76),
          ),
        );
      }
      if (items.isEmpty) {
        if (_supply.stayFailed.value) {
          return SliverToBoxAdapter(
            child: EmptyStateView(
              icon: Iconsax.cloud_cross,
              title: TripStrings.staysFailed,
              subtitle: TripStrings.checkConnection,
              onRetry: () => _supply.loadStays(),
              palette: TripColors.palette,
            ),
          );
        }
        return SliverToBoxAdapter(
          child: EmptyStateView(
            icon: Iconsax.building_4,
            title: TripStrings.noStays,
            subtitle: 'Within ${TripFormat.km(_supply.stayRadiusKm.value)} of your Day $d spots',
            onRetry: _supply.canWidenRadius ? () => _supply.widenRadius() : null,
            retryLabel: TripStrings.widerRadius,
            palette: TripColors.palette,
          ),
        );
      }
      final chosenId = _plan.plan.value?.dayAt(d)?.stay?.stayId;
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        sliver: SliverList.builder(
          itemCount: items.length,
          itemBuilder: (_, i) => _row(items[i], d, chosenId == items[i].id),
        ),
      );
    });
  }

  Widget _row(StayNearbyModel s, int day, bool selected) {
    return NearbyItemRow(
      key: ValueKey(s.id),
      thumbnailUrl: s.thumbnailUrl,
      tag: 'FOR STAY',
      title: s.title,
      subtitle: [
        if (s.stayTypeName != null && s.stayTypeName!.isNotEmpty) s.stayTypeName!,
        '${s.distanceKm.toStringAsFixed(1)} km',
      ].join(' · '),
      caption: 'FROM',
      value: s.minPricePerNight != null ? BrowseItem.inr(s.minPricePerNight!) : 'On request',
      unit: s.minPricePerNight != null ? '/night' : '',
      palette: StayColors.palette,
      placeholderIcon: Iconsax.building_4,
      isFeatured: s.isFeatured,
      onTap: () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': s.id, 'distanceKm': s.distanceKm}),
      trailing: _selectPill(selected, () => _plan.selectStay(day, s)),
    );
  }

  Widget _selectPill(bool selected, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? StayColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: StayColors.accent, width: 1.3),
        ),
        child: Text(
          selected ? '✓ Selected' : 'Select',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : StayColors.accentDark,
          ),
        ),
      ),
    );
  }
}
