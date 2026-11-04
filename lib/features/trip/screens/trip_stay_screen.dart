import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_routes.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/contact_launcher.dart';
import '../../../widgets/empty_state_view.dart';
import '../../../widgets/nearby_item_row.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_supply_controller.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../utils/trip_format.dart';
import '../widgets/trip_route_strip.dart';
import '../widgets/trip_shimmers.dart';
import '../widgets/trip_shortlist_bar.dart';
import '../widgets/trip_taxi_stay_toggle.dart';
import '../widgets/trip_withdraw_sheet.dart';

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

  void _changeDay(int d) {
    _supply.setDay(d);
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
        final d = _supply.day.value;
        return TripShortlistBar(key: ValueKey('shortlist-$d'), day: d);
      }),
    );
  }

  void _toggle(int day, StayNearbyModel s) {
    if (!_plan.toggleShortlist(day, s)) AppToast.warning(TripStrings.shortlistFull);
  }

  Future<void> _remove(int day, StayNearbyModel s) async {
    final open = _plan.enquiriesForNight(day).where((e) => e.listingId == s.id && e.isUnconfirmed).toList();
    if (open.isNotEmpty && !await TripWithdrawSheet.showForRemove(context, open: open)) return;
    _plan.removeShortlist(day, s.id);
  }

  Widget _noSupply() => EmptyStateView(
        icon: Iconsax.building_4,
        title: TripStrings.noStaysHere,
        subtitle: TripStrings.addOwnToKeep,
        retryLabel: TripStrings.haveStay,
        onRetry: () => TripShortlistBar.openOwn(context, _supply.day.value),
        palette: TripColors.palette,
      );

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
                      _headerSubtitle(),
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

  String _headerSubtitle() {
    final d = _supply.day.value;
    final date = _plan.dateOf(d);
    if (date == null) return _plan.cityName;
    return '${TripFormat.shortDate(date)} · ${TripStrings.night(d)}';
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
              onDayChanged: _changeDay,
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
      if (!_plan.supplyAvailable && !_plan.supplyPending) return SliverToBoxAdapter(child: _noSupply());
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
        if (!_supply.canWidenRadius) return SliverToBoxAdapter(child: _noSupply());
        return SliverToBoxAdapter(
          child: EmptyStateView(
            icon: Iconsax.building_4,
            title: TripStrings.noStays,
            subtitle: 'Within ${TripFormat.km(_supply.stayRadiusKm.value)} of your Day $d spots',
            onRetry: () => _supply.widenRadius(),
            retryLabel: TripStrings.widerRadius,
            palette: TripColors.palette,
          ),
        );
      }
      final day = _plan.plan.value?.dayAt(d);
      final listed = {for (final s in day?.stayShortlist ?? const []) s.stayId};
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        sliver: SliverList.builder(
          itemCount: items.length,
          itemBuilder: (_, i) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: _row(items[i], d, listed.contains(items[i].id)),
            ),
          ),
        ),
      );
    });
  }

  Widget _row(StayNearbyModel s, int day, bool selected) {
    final rawPhone = s.ownerPhone;
    final phone = (rawPhone == null || ContactLauncher.tenDigits(rawPhone).isEmpty) ? null : rawPhone;
    final off = !s.isActive;
    return NearbyItemRow(
      key: ValueKey(s.id),
      thumbnailUrl: s.thumbnailUrl,
      tag: off ? TripStrings.notAvailableNow.toUpperCase() : 'FOR STAY',
      title: s.title,
      subtitle: off
          ? TripStrings.stayPaused
          : [
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
      actions: [
        if (phone != null && !off)
          NearbyRowAction(
            icon: const Icon(Iconsax.call, size: 14, color: StayColors.accentDark),
            label: TripStrings.call,
            color: StayColors.accentDark,
            onTap: () => ContactLauncher.call(phone),
          ),
        if (phone != null && !off)
          NearbyRowAction(
            icon: Image.asset('assets/images/whatsapp_icon.png',
                width: 14,
                height: 14,
                errorBuilder: (_, _, _) => const Icon(Icons.chat, color: AppColors.whatsApp, size: 14)),
            label: TripStrings.whatsApp,
            color: AppColors.whatsApp,
            onTap: () => ContactLauncher.whatsApp(phone, message: _whatsAppText()),
          ),
        if (off && selected)
          NearbyRowAction(
            icon: const Icon(Iconsax.close_circle, size: 14, color: AppColors.error),
            label: TripStrings.remove,
            color: AppColors.error,
            onTap: () => _remove(day, s),
          )
        else if (!off)
          NearbyRowAction(
            icon: Icon(selected ? Iconsax.tick_circle : Iconsax.add_circle,
                size: 14, color: selected ? AppColors.success : StayColors.accentDark),
            label: selected ? TripStrings.shortlisted : TripStrings.shortlist,
            color: selected ? AppColors.success : StayColors.accentDark,
            onTap: () => selected ? _remove(day, s) : _toggle(day, s),
          ),
      ],
    );
  }

  String _whatsAppText() {
    final p = _plan.plan.value;
    final settings = _plan.settings;
    final start = settings.startDate;
    final end = p == null ? null : settings.endDate(p.days.length);
    return TripStrings.stayWhatsAppText(
      _plan.cityName,
      start == null ? null : (end == null ? TripFormat.shortDate(start) : TripFormat.dateRange(start, end)),
      settings.peopleSummary,
    );
  }
}
