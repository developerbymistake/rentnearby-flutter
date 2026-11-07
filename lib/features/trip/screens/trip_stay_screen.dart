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
import '../models/trip_plan_model.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_a2.dart';
import '../trip_strings_fin_b1.dart';
import '../trip_strings_v2_easy.dart';
import '../trip_strings_v2_find.dart';
import '../utils/trip_clock.dart';
import '../utils/trip_format.dart';
import '../widgets/trip_arrange_confirm.dart';
import '../widgets/trip_filter_chips.dart';
import '../widgets/trip_page_header.dart';
import '../widgets/trip_phone_booking_sheet.dart';
import '../widgets/trip_sheet_frame.dart';
import '../widgets/trip_status.dart';
import '../widgets/trip_stay_row.dart';
import 'trip_dates_sheet.dart';
import 'trip_stay_enquiry_sheet.dart';

class TripStayScreen extends StatefulWidget {
  const TripStayScreen({super.key});

  @override
  State<TripStayScreen> createState() => _TripStayScreenState();
}

class _TripStayScreenState extends State<TripStayScreen> {
  static const double _maxWidth = 640;
  static const int _nightPreview = 3;

  late final TripPlanController _plan;
  late final TripSupplyController _supply;
  late final int _leg;
  final _split = false.obs;
  final _expanded = <int>{}.obs;
  List<int> _only = const [];
  Worker? _planWorker;

  @override
  void initState() {
    super.initState();
    _plan = TripPlanController.to;
    _plan.openPages++;
    _supply = TripSupplyController.to;
    final args = Get.arguments;
    final map = args is Map ? args : const {};
    _leg = (map['legIndex'] as int?) ?? 1;
    final p = _plan.plan.value;
    final from = p?.legStart(_leg) ?? 1;
    final count = p?.legDayCount(_leg) ?? 1;
    final only = map['onlyDays'];
    if (only is List) {
      _only = [
        for (final d in only.whereType<int>().toSet())
          if (d >= from && d < from + count && !_plan.isDayPast(d)) d,
      ]..sort();
    }
    _split.value = _only.isNotEmpty || (map['split'] == true && count != 1);
    _supply.setNear((map['nearLat'] as num?)?.toDouble(), (map['nearLng'] as num?)?.toDouble());
    _supply.ensureStays(_leg);
    _planWorker = ever(_plan.plan, (_) => _supply.ensureStays(_leg));
  }

  @override
  void dispose() {
    _planWorker?.dispose();
    if (Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), _plan)) {
      _plan.openPages--;
      _plan.releaseIfIdle();
    }
    super.dispose();
  }

  TripEasyRowKey get _key => TripEasyRowKey(TripEasyRowKind.stay, _leg);

  int get _firstDay => _plan.plan.value?.legStart(_leg) ?? 1;

  int get _nights => _plan.plan.value?.legDayCount(_leg) ?? 1;

  int get _pastNights {
    final today = TripClock.today();
    var n = 0;
    for (var i = 0; i < _nights - 1; i++) {
      final d = _plan.dateOf(_firstDay + i);
      if (d != null && d.isBefore(today)) n++;
    }
    return n;
  }

  String get _city {
    final p = _plan.plan.value;
    return p == null ? _plan.cityName : p.cityNameOf(_firstDay);
  }

  bool get _noSupply =>
      _plan.stayTabOff.value || (!_plan.supplyAvailableFor(_firstDay) && !_plan.supplyPendingFor(_firstDay));

  void _skip() {
    _plan.skipRow(_key);
    TripNavigation.backToPlan();
  }

  Future<void> _arrange() async {
    if (!await TripArrangeConfirm.show(context, _key) || !mounted) return;
    final res = await TripArrangeConfirm.mark(context, _key);
    if (res == null || !mounted) return;
    if (res is TripMarkBlocked) {
      AppToast.warning(TripStringsV2Find.cancelFirstStay);
      return;
    }
    TripNavigation.backToPlan();
  }

  String _subtitle() {
    if (_only.isNotEmpty) return TripStringsV2Find.nightsLeft(_only.length);
    final p = _plan.plan.value;
    final first = _plan.dateOf(_firstDay);
    String? range;
    if (first != null && p != null) {
      range = TripStringsV2Easy.stayDates(first, DateTime(first.year, first.month, first.day + _nights));
    }
    final people = _plan.settings.peopleCount;
    return TripStringsV2Find.staySubtitle(_nights, range, people > 0 ? TripStrings.peopleText(people) : null);
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

  Widget _box(Widget child) => SliverToBoxAdapter(
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _maxWidth), child: child)),
      );

  Widget _skeletons() => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.builder(
          itemCount: 4,
          itemBuilder: (_, _) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: const TripStayRowSkeleton(),
            ),
          ),
        ),
      );

  Widget _noSupplyView() {
    final paused = _plan.stayTabOff.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
      child: Column(
        children: [
          const Icon(Iconsax.building_4, size: 40, color: AppColors.textHint),
          const SizedBox(height: 10),
          Text(paused ? TripStringsV2Find.staysPaused : TripStringsV2Find.noStaysTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
          const SizedBox(height: 4),
          Text(TripStringsV2Find.noStaysBody(_city),
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          if (!_plan.isReadOnly) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _arrange,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  side: BorderSide(color: StayColors.accent.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(TripStringsV2Find.arrangeMyself,
                    style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: StayColors.accentDark)),
              ),
            ),
            TextButton(
              onPressed: _skip,
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              child: const Text(TripStringsV2Find.skip,
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: StayColors.accentDark)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _splitBar() {
    final on = _split.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _split.value = !on,
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          icon: Icon(on ? Iconsax.building_4 : Iconsax.calendar_1, size: 16, color: StayColors.accentDark),
          label: Text(on ? TripStringsV2Find.sameStayFor(_nights - _pastNights) : TripStringsV2Find.nightByNight,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: StayColors.accentDark)),
        ),
      ),
    );
  }

  Future<void> _phoneBooked() async {
    if (!await TripDatesSheet.ensure(context, heading: TripStrings.addYourDates) || !_plan.hasDates || !mounted) return;
    final stay = await TripSheetFrame.show<StayNearbyModel>(context, _PickStaySheet(stays: _supply.stays.toList()));
    if (stay == null || !mounted) return;
    final phone = ContactLauncher.tenDigits(stay.ownerPhone ?? '');
    final r = await TripPhoneBookingSheet.show(
      context,
      stayId: stay.id,
      stayName: stay.name ?? '',
      hostName: stay.ownerName,
      hostPhone: phone.length == 10 ? phone : null,
      day: _only.isNotEmpty ? _only.first : _firstDay,
    );
    if (r == null || !mounted) return;
    _plan.rememberLink(r);
    if (r.confirmLink.isNotEmpty) await TripConfirmLinkSheet.show(context, r);
    TripNavigation.backToPlan();
  }

  Widget _phoneLink() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _phoneBooked,
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: const Text(TripStringsV2Find.alreadyBookedByPhone,
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: StayColors.accentDark)),
          ),
        ),
      );

  Widget _top() => Obx(() {
        _plan.plan.value;
        final showSplit = _only.isEmpty && _nights - _pastNights > 1 && !_noSupply && !_plan.isReadOnly && !_split.value;
        final showPhone = !_noSupply &&
            !_plan.isReadOnly &&
            _plan.confirmedRowOf(_key) == null &&
            _supply.stays.isNotEmpty;
        final showChips = !_noSupply && (_supply.stays.isNotEmpty || _supply.hasStayFilters);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showSplit) _splitBar(),
                if (showPhone) _phoneLink(),
                if (showChips)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TripFilterChips(items: _chips(), accent: StayColors.accent),
                  ),
              ],
            ),
          ),
        );
      });

  List<StayNearbyModel> _pinned(List<StayNearbyModel> shown, Map<String, TripEnquiryModel> asked) {
    final seen = {for (final s in shown) s.id};
    final loaded = {for (final s in _supply.stays) s.id: s};
    final out = <StayNearbyModel>[];
    for (final e in asked.values) {
      if (!seen.add(e.listingId)) continue;
      out.add(loaded[e.listingId] ??
          StayNearbyModel(
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

  String _whatsAppText(int day, int nights) {
    final first = _plan.dateOf(day);
    final range = first == null ? null : TripFormat.dateRange(first, DateTime(first.year, first.month, first.day + nights));
    return TripStrings.stayWhatsAppText(_city, range, _plan.settings.peopleSummary);
  }

  Widget _row(StayNearbyModel s, int day, int nights, TripEnquiryModel? asked) {
    final rawPhone = s.ownerPhone;
    final phone = (rawPhone == null || ContactLauncher.tenDigits(rawPhone).isEmpty) ? null : rawPhone;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: TripStayRow(
          key: ValueKey('${s.id}-$day'),
          stay: s,
          fit: _supply.stayFitOf(s.id),
          status: asked?.display,
          statusLine: _askedLine(asked),
          onOpenChat: asked?.conversationId == null ? null : () => TripNavigation.openChatForEnquiry(asked!),
          readOnly: _plan.isReadOnly,
          onOpen: () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': s.id, 'distanceKm': s.distanceKm}),
          onCall: phone == null ? null : () => ContactLauncher.call(phone),
          onWhatsApp: phone == null ? null : () => ContactLauncher.whatsApp(phone, message: _whatsAppText(day, nights)),
          onAsk: () => TripStayEnquirySheet.show(context, stay: s, day: day, nights: nights),
        ),
      ),
    );
  }

  Map<String, TripEnquiryModel> _askedOf(List<TripEnquiryModel> rows) => {
        for (final e in rows.reversed)
          if (e.isOpen) e.listingId: e,
      };

  Widget? _emptyView(List<StayNearbyModel> all, List<StayNearbyModel> items) {
    if (all.isEmpty) {
      if (_supply.stayFailed.value) {
        return EmptyStateView(
          icon: Iconsax.cloud_cross,
          title: TripStringsV2Find.staysFailed,
          subtitle: TripStringsV2Find.checkConnection,
          onRetry: () => _supply.loadStays(),
          retryLabel: TripStringsV2Find.retry,
          palette: StayColors.palette,
        );
      }
      return _noSupplyView();
    }
    if (items.isEmpty) {
      return EmptyStateView(
        icon: Iconsax.filter_remove,
        title: TripStringsV2Find.noMatch,
        subtitle: TripStringsA2.noMatchBody,
        onRetry: _supply.clearStayFilters,
        retryLabel: TripStringsV2Find.clearFilters,
        palette: StayColors.palette,
      );
    }
    return null;
  }

  Widget _buildBody() => Obx(() {
        _plan.plan.value;
        _plan.enquiryList.length;
        if (_noSupply) return _box(_noSupplyView());
        if (_plan.supplyPendingFor(_firstDay) || _supply.stayLoading.value || _supply.staysOutOfDate) return _skeletons();
        final all = _supply.stays;
        final items = _supply.filteredStays;
        if (_split.value) return _splitBody(all, items);
        final asked = _askedOf(_plan.stayEnquiriesOf(_leg));
        final pinned = _pinned(items, asked);
        final empty = pinned.isEmpty ? _emptyView(all, items) : null;
        if (empty != null) return _box(empty);
        final rows = [...pinned, ...items];
        final past = _pastNights;
        final day = _firstDay + past;
        final nights = _nights - past;
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: rows.length + 1,
            itemBuilder: (_, i) => i == rows.length
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(TripStringsV2Find.askNote,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                  )
                : _row(rows[i], day, nights, asked[rows[i].id]),
          ),
        );
      });

  Widget _splitBody(List<StayNearbyModel> all, List<StayNearbyModel> items) {
    final empty = _emptyView(all, items);
    if (empty != null) return _box(empty);
    final past = _pastNights;
    final first = _firstDay + past;
    final nightDays = _only.isNotEmpty ? _only : [for (var i = 0; i < _nights - past; i++) first + i];
    final n = nightDays.length;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: n + 1,
        itemBuilder: (_, i) {
          if (i == n) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_plan.isReadOnly && _only.isEmpty) _splitBar(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(TripStringsV2Find.splitNote,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                    ),
                  ],
                ),
              ),
            );
          }
          final day = nightDays[i];
          final date = _plan.dateOf(day);
          final asked = _askedOf(_plan.enquiriesForNight(day));
          final shown = _pinned(items, asked);
          final rows = [...shown, ...items];
          final open = _expanded.contains(day);
          final visible = open ? rows : rows.take(_nightPreview).toList();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(TripStringsV2Find.nightLabel(day - _firstDay + 1, date == null ? null : TripFormat.shortDate(date)),
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  ),
                  for (final s in visible) _row(s, day, 1, asked[s.id]),
                  if (rows.length > _nightPreview)
                    TextButton(
                      onPressed: () => open ? _expanded.remove(day) : _expanded.add(day),
                      style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                      child: Text(open ? TripStringsV2Find.showLess : TripStringsV2Find.showAll(rows.length),
                          style: const TextStyle(
                              fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: StayColors.accentDark)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) TripNavigation.backToPlan();
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Column(
          children: [
            Obx(() {
              _plan.plan.value;
              return TripPageHeader(
                title: TripStringsV2Find.stayIn(_city),
                subtitle: _subtitle(),
                onBack: TripNavigation.backToPlan,
                gradient: StayColors.gradient,
                trailing: _plan.isReadOnly || _only.isNotEmpty || _plan.openRowsOf(_key).isNotEmpty || _plan.confirmedRowOf(_key) != null
                    ? null
                    : TextButton(
                        onPressed: _skip,
                        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                        child: const Text(TripStringsV2Find.skip,
                            style: TextStyle(
                                fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
              );
            }),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _top()),
                  _buildBody(),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ],
        ),
      ),
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

class _PickStaySheet extends StatelessWidget {
  const _PickStaySheet({required this.stays});

  final List<StayNearbyModel> stays;

  @override
  Widget build(BuildContext context) {
    return TripSheetFrame(
      title: TripStringsV2Find.whichStay,
      description: TripStringsV2Find.pickBookedStay,
      children: [
        for (final s in stays)
          InkWell(
            onTap: () => Navigator.pop(context, s),
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          if (_area(s).isNotEmpty)
                            Text(_area(s),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20, color: AppColors.textHint),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _area(StayNearbyModel s) => [
        if ((s.stayTypeName ?? '').isNotEmpty) s.stayTypeName!,
        if (s.distanceKm > 0) '${s.distanceKm.toStringAsFixed(1)} km',
      ].join(' · ');
}
