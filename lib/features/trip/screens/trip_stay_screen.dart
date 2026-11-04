import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_routes.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/contact_launcher.dart';
import '../../../widgets/empty_state_view.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_supply_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_strings.dart';
import '../trip_strings_a2.dart';
import '../utils/trip_format.dart';
import '../widgets/trip_filter_chips.dart';
import '../widgets/trip_night_chooser.dart';
import '../widgets/trip_page_header.dart';
import '../widgets/trip_route_strip.dart';
import '../widgets/trip_sheet_frame.dart';
import '../widgets/trip_shortlist_bar.dart';
import '../widgets/trip_stay_row.dart';
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
    final map = args is Map ? args : const {};
    final day = map['day'] as int?;
    final lat = (map['nearLat'] as num?)?.toDouble();
    final lng = (map['nearLng'] as num?)?.toDouble();
    if (day != null) _supply.setDay(day);
    if (lat != null && lng != null) {
      _supply.setSearchPoint(lat, lng);
    } else {
      _supply.clearSearchPoint();
    }
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

  bool _locked(int day) => _plan.isReadOnly || _plan.isDayPast(day);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          Obx(() {
            final d = _supply.day.value;
            _plan.plan.value;
            return TripPageHeader(
              title: _title(d),
              subtitle: _subtitle(d),
              onBack: () => Get.back(),
              gradient: StayColors.gradient,
              bottom: TripTaxiStayToggle(
                selected: TripSupplyKind.stay,
                day: d,
                onHeader: true,
                activeColor: StayColors.accent,
              ),
            );
          }),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildTop()),
                _buildBody(),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
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

  String _title(int d) {
    final date = _plan.dateOf(d);
    final now = DateTime.now();
    final today = date != null && date.year == now.year && date.month == now.month && date.day == now.day;
    return TripStrings.nightTitle(d, today: today);
  }

  String _subtitle(int d) {
    final date = _plan.dateOf(d);
    return TripStrings.joinDots([
      _plan.cityName,
      date == null ? null : TripFormat.dayMonth(date),
      TripStrings.peopleText(_plan.settings.peopleCount),
    ]);
  }

  Future<void> _pickPrice() async {
    final picked = await TripSheetFrame.show<int>(context, _PriceBody(current: _supply.maxPrice.value));
    if (picked == null) return;
    _supply.maxPrice.value = picked == 0 ? null : picked;
  }

  List<TripFilterChip> _chips() {
    final max = _supply.maxPrice.value;
    return [
      TripFilterChip(
        label: max == null ? TripStringsA2.maxPrice : TripStringsA2.underPrice(BrowseItem.inr(max)),
        selected: max != null,
        icon: Iconsax.wallet_2,
        onTap: _pickPrice,
      ),
      TripFilterChip(
        label: TripStringsA2.homestay,
        selected: _supply.onlyHomestay.value,
        onTap: () => _supply.onlyHomestay.toggle(),
      ),
      if (_supply.hostelAvailable.value)
        TripFilterChip(
          label: TripStringsA2.hostel,
          selected: _supply.onlyHostel.value,
          onTap: () => _supply.onlyHostel.toggle(),
        ),
      if (_supply.hasStayFilters)
        TripFilterChip(
          label: TripStringsA2.clearFilters,
          selected: false,
          icon: Iconsax.filter_remove,
          onTap: _supply.clearStayFilters,
        ),
    ];
  }

  bool _noSupply() => _plan.stayTabOff.value || (!_plan.supplyAvailable && !_plan.supplyPending);

  Widget _buildTop() {
    return Obx(() {
      final d = _supply.day.value;
      _plan.plan.value;
      _plan.enquiryList.length;
      final listMode = TripNightChooser.modeOf(_plan, d) == TripNightMode.nightByNight;
      final showChips = listMode && !_noSupply() && (_supply.stays.isNotEmpty || _supply.hasStayFilters);
      final chooser = TripNightChooser.visible(_plan, d);
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TripRouteStrip(
                  day: d,
                  onDayChanged: _changeDay,
                  showRoute: false,
                  nights: true,
                  accent: StayColors.accent,
                ),
                if (chooser) ...[
                  const SizedBox(height: 8),
                  TripNightChooser(day: d),
                ],
                if (showChips) ...[
                  const SizedBox(height: 4),
                  TripFilterChips(items: _chips(), accent: StayColors.accent),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _box(Widget child) => SliverToBoxAdapter(
        child: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: child),
        ),
      );

  Widget _noSupplyView() => const EmptyStateView(
        icon: Iconsax.building_4,
        title: TripStrings.noStaysHere,
        subtitle: TripStrings.addOwnToKeep,
        palette: StayColors.palette,
      );

  Widget _skeletons() => SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        sliver: SliverList.builder(
          itemCount: 4,
          itemBuilder: (_, _) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: const TripStayRowSkeleton(),
            ),
          ),
        ),
      );

  Widget _modeCard(int d, TripNightMode mode) {
    final skipped = mode == TripNightMode.none;
    final name = _plan.plan.value?.dayAt(d)?.stay?.name ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: StayColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: StayColors.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(skipped ? Iconsax.car : Iconsax.building_4, size: 20, color: StayColors.accentDark),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(skipped ? TripStrings.noStayTonight : TripStrings.sameAsLastNight,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(skipped ? TripStringsA2.travellingBody : TripStringsA2.sameStayBody(name),
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      final d = _supply.day.value;
      _plan.plan.value;
      _plan.enquiryList.length;
      if (_noSupply()) return _box(_noSupplyView());
      final mode = TripNightChooser.modeOf(_plan, d);
      if (mode != TripNightMode.nightByNight) return _box(_modeCard(d, mode));
      if (_plan.supplyPending || _supply.stayLoading.value) return _skeletons();
      final all = _supply.stays;
      if (all.isEmpty) {
        if (_supply.stayFailed.value) {
          return _box(EmptyStateView(
            icon: Iconsax.cloud_cross,
            title: TripStrings.staysFailed,
            subtitle: TripStrings.checkConnection,
            onRetry: () => _supply.loadStays(),
            palette: StayColors.palette,
          ));
        }
        if (!_supply.canWidenRadius) return _box(_noSupplyView());
        return _box(EmptyStateView(
          icon: Iconsax.building_4,
          title: TripStrings.noStays,
          subtitle: 'Within ${TripFormat.km(_supply.stayRadiusKm.value)} of your Day $d spots',
          onRetry: () => _supply.widenRadius(),
          retryLabel: TripStrings.widerRadius,
          palette: StayColors.palette,
        ));
      }
      final items = _supply.filteredStays;
      if (items.isEmpty) {
        return _box(EmptyStateView(
          icon: Iconsax.filter_remove,
          title: TripStringsA2.noMatchTitle,
          subtitle: TripStringsA2.noMatchBody,
          onRetry: _supply.clearStayFilters,
          retryLabel: TripStringsA2.clearFilters,
          palette: StayColors.palette,
        ));
      }
      final listed = {for (final s in _plan.plan.value?.dayAt(d)?.stayShortlist ?? const []) s.stayId};
      final asked = <String, TripEnquiryModel>{
        for (final e in _plan.enquiriesForNight(d).reversed)
          if (e.isOpen) e.listingId: e,
      };
      final locked = _locked(d);
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.builder(
          itemCount: items.length,
          itemBuilder: (_, i) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: _row(items[i], d, listed.contains(items[i].id), asked[items[i].id], locked),
            ),
          ),
        ),
      );
    });
  }

  void _toggle(int day, StayNearbyModel s) {
    if (TripShortlistBar.isFull(_plan, day) || !_plan.toggleShortlist(day, s)) {
      AppToast.warning(TripStrings.shortlistFull);
    }
  }

  Future<void> _remove(int day, StayNearbyModel s) async {
    final open = _plan.enquiriesForNight(day).where((e) => e.listingId == s.id && e.isUnconfirmed).toList();
    if (open.isNotEmpty && !await TripWithdrawSheet.showForRemove(context, open: open)) return;
    _plan.removeShortlist(day, s.id);
  }

  Widget _row(StayNearbyModel s, int day, bool shortlisted, TripEnquiryModel? asked, bool locked) {
    final rawPhone = s.ownerPhone;
    final phone = (rawPhone == null || ContactLauncher.tenDigits(rawPhone).isEmpty) ? null : rawPhone;
    return TripStayRow(
      key: ValueKey(s.id),
      stay: s,
      shortlisted: shortlisted,
      status: asked?.display,
      readOnly: locked,
      onOpen: () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': s.id, 'distanceKm': s.distanceKm}),
      onCall: phone == null ? null : () => ContactLauncher.call(phone),
      onWhatsApp: phone == null ? null : () => ContactLauncher.whatsApp(phone, message: _whatsAppText()),
      onShortlist: () => _toggle(day, s),
      onRemove: () => _remove(day, s),
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

class _PriceBody extends StatelessWidget {
  const _PriceBody({required this.current});

  final int? current;

  Widget _option(BuildContext context, int value, String label) {
    final on = (current ?? 0) == value;
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Icon(on ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20, color: on ? StayColors.accent : AppColors.textHint),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.textDark)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TripSheetFrame(
      title: TripStringsA2.priceSheetTitle,
      children: [
        _option(context, 0, TripStringsA2.anyPrice),
        for (final p in TripSupplyController.pricePresets)
          _option(context, p, TripStringsA2.underPrice(BrowseItem.inr(p))),
      ],
    );
  }
}
