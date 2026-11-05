import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_routes.dart';
import '../../../models/browse_item.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/contact_launcher.dart';
import '../../../widgets/empty_state_view.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_supply_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_a2.dart';
import '../trip_strings_fin_b1.dart';
import '../trip_strings_mca_a3.dart';
import '../utils/trip_format.dart';
import '../widgets/trip_filter_chips.dart';
import '../widgets/trip_night_chooser.dart';
import '../widgets/trip_page_header.dart';
import '../widgets/trip_route_strip.dart';
import '../widgets/trip_sheet_frame.dart';
import '../widgets/trip_shortlist_bar.dart';
import '../widgets/trip_status.dart';
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
  final _groundOnly = false.obs;
  final _offStays = <String>{}.obs;
  final _checkedStays = <String>{};

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
    if (_plan.isMultiCity) return TripStringsMcaA3.stayIn(_plan.cityNameOf(d));
    final date = _plan.dateOf(d);
    final now = DateTime.now();
    final today = date != null && date.year == now.year && date.month == now.month && date.day == now.day;
    return TripStrings.nightTitle(d, today: today);
  }

  String _subtitle(int d) {
    final date = _plan.dateOf(d);
    if (_plan.isMultiCity) {
      return TripStringsMcaA3.nightLine(d, date, TripStrings.peopleText(_plan.settings.peopleCount));
    }
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
        label: TripStringsFinB1.groundFloor,
        selected: _groundOnly.value,
        onTap: () => _groundOnly.toggle(),
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
      if (_hasFilters)
        TripFilterChip(
          label: TripStringsA2.clearFilters,
          selected: false,
          icon: Iconsax.filter_remove,
          onTap: _clearFilters,
        ),
    ];
  }

  bool get _hasFilters => _supply.hasStayFilters || _groundOnly.value;

  void _clearFilters() {
    _supply.clearStayFilters();
    _groundOnly.value = false;
  }

  bool _noSupply() =>
      _plan.stayTabOff.value || (!_plan.supplyAvailableFor(_supply.day.value) && !_plan.supplyPendingFor(_supply.day.value));

  Widget _buildTop() {
    return Obx(() {
      final d = _supply.day.value;
      _plan.plan.value;
      _plan.enquiryList.length;
      final listMode = TripNightChooser.modeOf(_plan, d) == TripNightMode.nightByNight;
      final showChips = listMode && !_noSupply() && (_supply.stays.isNotEmpty || _hasFilters);
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
    final stay = _plan.plan.value?.dayAt(d)?.stay;
    final name = stay?.name ?? '';
    final base = skipped || stay == null ? null : _baseLines(stay);
    final actions = !skipped && !_locked(d);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: StayColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: StayColors.accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                      for (final line in base ?? const <String>[]) ...[
                        const SizedBox(height: 4),
                        Text(line,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: StayColors.accentDark)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (actions) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _modeButton(TripStringsFinB1.keepIt, () => Get.back())),
                  const SizedBox(width: 8),
                  Expanded(child: _modeButton(TripStringsFinB1.newStay, () => _plan.clearStay(d))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _modeButton(String label, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          side: BorderSide(color: StayColors.accent.withValues(alpha: 0.6)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: StayColors.accentDark)),
      );

  List<String>? _baseLines(TripStayChoice stay) {
    final baseDay = stay.sameAsDay;
    if (baseDay == null) return null;
    if (stay.isOwn) return ['${TripStringsA2.nightChip(baseDay)} · ${TripStrings.ownBooking}'];
    final e = _plan.enquiriesForNight(baseDay).firstWhereOrNull((x) => x.isBooked && x.listingId == stay.stayId);
    if (e == null) return null;
    final head = '${TripStringsA2.nightChip(baseDay)} · ${TripStatusVisuals.label(e.display)}';
    final out = e.acceptedOffer?.checkOut ?? e.checkOut;
    final first = _plan.dayOfDate(e.acceptedOffer?.checkIn ?? e.checkIn);
    if (first == null || out == null) return [head];
    final after = _plan.dayOfDate(out);
    final last = after == null ? first + e.nights - 1 : after - 1;
    return [head, TripStringsFinB1.baseStayLine(first, last < first ? first : last, TripFormat.shortDate(out))];
  }

  Widget _buildBody() {
    return Obx(() {
      final d = _supply.day.value;
      _plan.plan.value;
      _plan.enquiryList.length;
      if (_noSupply()) return _box(_noSupplyView());
      final mode = TripNightChooser.modeOf(_plan, d);
      if (mode != TripNightMode.nightByNight) return _box(_modeCard(d, mode));
      if (_plan.supplyPendingFor(_supply.day.value) || _supply.stayLoading.value) return _skeletons();
      final all = _supply.stays;
      final ground = _groundOnly.value;
      _offStays.length;
      final items = [
        for (final s in _supply.filteredStays)
          if (!ground || s.hasGroundFloorRoom) s,
      ];
      final listed = {for (final s in _plan.plan.value?.dayAt(d)?.stayShortlist ?? const []) s.stayId};
      final asked = <String, TripEnquiryModel>{
        for (final e in _plan.enquiriesForNight(d).reversed)
          if (e.isOpen) e.listingId: e,
      };
      final pinned = _pinned(d, all, items, asked);
      if (pinned.isNotEmpty) _checkLater(pinned);
      Widget? empty;
      if (all.isEmpty) {
        if (_supply.stayFailed.value) {
          empty = EmptyStateView(
            icon: Iconsax.cloud_cross,
            title: TripStrings.staysFailed,
            subtitle: TripStrings.checkConnection,
            onRetry: () => _supply.loadStays(),
            palette: StayColors.palette,
          );
        } else if (!_supply.canWidenRadius) {
          empty = _noSupplyView();
        } else {
          empty = EmptyStateView(
            icon: Iconsax.building_4,
            title: TripStrings.noStays,
            subtitle: 'Within ${TripFormat.km(_supply.stayRadiusKm.value)} of your Day $d spots',
            onRetry: () => _supply.widenRadius(),
            retryLabel: TripStrings.widerRadius,
            palette: StayColors.palette,
          );
        }
      } else if (items.isEmpty) {
        empty = EmptyStateView(
          icon: Iconsax.filter_remove,
          title: TripStringsA2.noMatchTitle,
          subtitle: TripStringsA2.noMatchBody,
          onRetry: _clearFilters,
          retryLabel: TripStringsA2.clearFilters,
          palette: StayColors.palette,
        );
      }
      final emptyView = empty;
      if (pinned.isEmpty && emptyView != null) return _box(emptyView);
      final gap = emptyView == null ? 0 : 1;
      final locked = _locked(d);
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.builder(
          itemCount: pinned.length + gap + items.length,
          itemBuilder: (_, i) {
            if (emptyView != null && i == pinned.length) {
              return Center(
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: emptyView),
              );
            }
            final s = i < pinned.length ? pinned[i] : items[i - pinned.length - gap];
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _row(s, d, listed.contains(s.id), asked[s.id], locked),
              ),
            );
          },
        ),
      );
    });
  }

  List<StayNearbyModel> _pinned(
    int d,
    List<StayNearbyModel> all,
    List<StayNearbyModel> shown,
    Map<String, TripEnquiryModel> asked,
  ) {
    final off = {..._plan.unavailableStayIds, ..._offStays};
    final seen = {for (final s in shown) s.id};
    final loaded = {for (final s in all) s.id: s};
    final out = <StayNearbyModel>[];
    void add(StayNearbyModel s) {
      if (seen.add(s.id)) out.add(_withActive(loaded[s.id] ?? s, !off.contains(s.id)));
    }

    for (final s in _plan.shortlistAsModels(d) ?? const <StayNearbyModel>[]) {
      add(s);
    }
    for (final e in asked.values) {
      add(StayNearbyModel(
        id: e.listingId,
        name: e.listingName,
        latitude: e.listingLatitude ?? 0,
        longitude: e.listingLongitude ?? 0,
        distanceKm: 0,
        isActive: true,
      ));
    }
    return out;
  }

  static StayNearbyModel _withActive(StayNearbyModel s, bool active) => s.isActive == active
      ? s
      : StayNearbyModel(
          id: s.id,
          name: s.name,
          stayTypeName: s.stayTypeName,
          latitude: s.latitude,
          longitude: s.longitude,
          minPricePerNight: s.minPricePerNight,
          thumbnailUrl: s.thumbnailUrl,
          distanceKm: s.distanceKm,
          ownerName: s.ownerName,
          ownerPhone: s.ownerPhone,
          isActive: active,
          isFeatured: s.isFeatured,
          maxGuests: s.maxGuests,
          meals: s.meals,
          checkInTime: s.checkInTime,
          roomCount: s.roomCount,
          hasGroundFloorRoom: s.hasGroundFloorRoom,
          bestRoomName: s.bestRoomName,
          bestRoomGuests: s.bestRoomGuests,
        );

  void _checkLater(List<StayNearbyModel> pinned) {
    final ids = [for (final s in pinned) if (_checkedStays.add(s.id)) s.id];
    if (ids.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final id in ids) {
        _checkStay(id);
      }
    });
  }

  Future<void> _checkStay(String id) async {
    try {
      await ApiService.get('/stays/$id');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && mounted) _offStays.add(id);
    } catch (_) {}
  }

  static String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  static String? _askedLine(TripEnquiryModel? e) {
    if (e == null) return null;
    final offer = e.openOffer;
    return switch (e.display) {
      TripDisplayStatus.asked => TripStringsFinB1.askedWaiting(_ago(e.createdAt)),
      TripDisplayStatus.offered when offer != null => TripStringsFinB1.offeredTotal(BrowseItem.inr(offer.total)),
      _ => null,
    };
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
      statusLine: _askedLine(asked),
      onOpenChat: asked?.conversationId == null ? null : () => TripNavigation.openChatForEnquiry(asked!),
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
    final d = _supply.day.value;
    final legPlan = p != null && p.isMultiCity ? p : null;
    final leg = legPlan?.legIndexOf(d) ?? 1;
    final start = legPlan == null ? settings.startDate : settings.dateOf(legPlan.legStart(leg));
    final end = p == null
        ? null
        : (legPlan == null ? settings.endDate(p.days.length) : settings.dateOf(legPlan.legEnd(leg)));
    return TripStrings.stayWhatsAppText(
      legPlan?.cityNameOf(d) ?? _plan.cityName,
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
