import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/contact_launcher.dart';
import '../../../widgets/empty_state_view.dart';
import '../../taxi/guest/taxi_browse_repository.dart';
import '../../taxi/guest/taxi_navigation.dart';
import '../../taxi/leads/trip_lead_format.dart';
import '../../taxi/models/taxi_browse_item.dart';
import '../../taxi/taxi_option_sets.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_supply_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_a3.dart';
import '../utils/trip_enquiry_rules.dart';
import '../utils/trip_format.dart';
import '../widgets/trip_back_to_plan_bar.dart';
import '../widgets/trip_cancel_sheet.dart';
import '../widgets/trip_driver_row.dart';
import '../widgets/trip_filter_chips.dart';
import '../widgets/trip_own_booking_sheet.dart';
import '../widgets/trip_page_bottom_bar.dart';
import '../widgets/trip_page_header.dart';
import '../widgets/trip_route_strip.dart';
import '../widgets/trip_shimmers.dart';
import '../widgets/trip_taxi_booking_sheet.dart';
import '../widgets/trip_taxi_stay_toggle.dart';
import 'trip_details_sheet.dart';
import 'trip_taxi_enquiry_sheet.dart';

class TripTaxiScreen extends StatefulWidget {
  const TripTaxiScreen({super.key});

  @override
  State<TripTaxiScreen> createState() => _TripTaxiScreenState();
}

class _TripTaxiScreenState extends State<TripTaxiScreen> {
  static const double _maxWidth = 640;
  static const int _shortlistMax = 3;

  late final TripPlanController _plan;
  late final TripSupplyController _supply;
  final _scroll = ScrollController();
  final _wholeTrip = true.obs;
  final _contactBusy = <String>{}.obs;
  final _contacts = <String, ({String phone, String whatsApp})>{};

  int get _day => _supply.day.value;

  bool _readOnly(int day) => _plan.isReadOnly || _plan.isDayPast(day);

  @override
  void initState() {
    super.initState();
    _plan = TripPlanController.to;
    _plan.openPages++;
    _supply = TripSupplyController.to;
    final args = Get.arguments;
    final day = args is Map ? args['day'] as int? : null;
    if (day != null) _supply.setDay(day);
    _supply.minSeats.value = null;
    _supply.onlySuv.value = false;
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
        whatsAppMessage: _plan.whatsAppMessage(_day, t.driverName),
      );

  Future<({String phone, String whatsApp})?> _loadContact(TaxiBrowseItem t) async {
    if (_contactBusy.contains(t.id)) return null;
    _contactBusy.add(t.id);
    try {
      final d = await const TaxiBrowseRepository().getById(t.id);
      final phone = d.contactPhone;
      if (phone == null || ContactLauncher.tenDigits(phone).isEmpty) {
        _open(t);
        return null;
      }
      final c = (phone: phone, whatsApp: d.whatsAppNumber ?? phone);
      _contacts[t.id] = c;
      return c;
    } catch (_) {
      AppToast.error(TripStringsA3.contactFailed);
      return null;
    } finally {
      _contactBusy.remove(t.id);
    }
  }

  Future<void> _contact(TaxiBrowseItem t, {required bool whatsApp}) async {
    final c = _contacts[t.id] ?? await _loadContact(t);
    if (c == null) return;
    if (whatsApp) {
      await ContactLauncher.whatsApp(c.whatsApp, message: _plan.whatsAppMessage(_day, t.driverName));
    } else {
      await ContactLauncher.call(c.phone);
    }
  }

  Future<void> _cancelFirst(TripEnquiryModel booked, int day) async {
    final cancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(TripStringsA3.cancelFirstTitle,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        content: Text(TripStringsA3.cancelFirstBody(TripLeadFormat.driver(booked), day),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(TripStringsA3.keep, style: TextStyle(fontFamily: 'Poppins', color: AppColors.textMedium)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(TripStrings.cancelBooking,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: AppColors.error)),
          ),
        ],
      ),
    );
    if (cancel != true || !mounted) return;
    await TripCancelSheet.show(context, enquiry: booked, ownerSide: false);
  }

  Future<void> _select(TaxiBrowseItem t) async {
    final d = _day;
    final booked = _plan.bookedTaxiEnquiryFor(d);
    if (booked != null) {
      if (booked.listingId != t.id) await _cancelFirst(booked, d);
      return;
    }
    final current = _plan.plan.value?.dayAt(d)?.taxi;
    if (current != null && current.isBooked && !current.isOwn) {
      if (current.taxiId == t.id) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(TripStrings.replaceBooking(TripStrings.dayN(d), current.name),
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          content: const Text(TripStrings.replaceQuestion,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
              child: const Text(TripStrings.keep, style: TextStyle(fontFamily: 'Poppins', color: AppColors.textMedium)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
              child: const Text(TripStrings.replace,
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark)),
            ),
          ],
        ),
      );
      if (ok != true) return;
      _plan.clearTaxiBooking(current.taxiId);
    }
    _plan.selectTaxi(d, t);
    AppToast.success(TripStringsA3.selectedForDay(t.driverName, d));
  }

  Future<void> _book(TaxiBrowseItem t) async {
    if (!_plan.hasDates) {
      final ok = await TripDetailsSheet.edit(
        context,
        heading: TripStrings.addYourDates,
        description: TripStrings.datesNeededBooking,
      );
      if (!ok || !mounted) return;
    }
    await TripTaxiBookingSheet.show(context, taxi: t, day: _day);
  }

  Future<void> _shortlist(TaxiBrowseItem t) async {
    final d = _day;
    final booked = _plan.bookedTaxiEnquiryFor(d);
    if (booked != null && booked.listingId != t.id) {
      await _cancelFirst(booked, d);
      return;
    }
    if (!_plan.toggleTaxiShortlist(d, t, wholeTrip: _wholeTrip.value)) AppToast.warning(TripStrings.shortlistFull);
  }

  Future<void> _send() async {
    final d = _day;
    final drivers = _plan.sendableTaxiShortlist(d);
    if (drivers.isEmpty) return;
    if (!_plan.hasDates) {
      final ok = await TripDetailsSheet.edit(
        context,
        heading: TripStrings.addYourDates,
        description: TripStrings.addYourDatesOwners,
      );
      if (!ok || !mounted) return;
    }
    await TripTaxiEnquirySheet.show(context, drivers: drivers, day: d);
  }

  Future<void> _own() => TripOwnBookingSheet.show(
        context,
        day: _day,
        kind: TripOwnKind.taxi,
        existingTaxi: _plan.ownTaxiOf(_day),
      );

  void _clearFilters() {
    _supply.minSeats.value = null;
    _supply.onlySuv.value = false;
  }

  int _sendDays(int day) {
    final ids = {for (final s in _plan.sendableTaxiShortlist(day)) s.taxiId};
    final whole = _plan.sendableTaxiShortlist(day).any((s) => s.wholeTrip);
    return TripTaxiEnquirySheet.defaultDays(_plan, day, whole: whole, taxiIds: ids).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(),
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
      bottomNavigationBar: _buildBar(),
    );
  }

  Widget _buildHeader() => Obx(() {
        _plan.plan.value;
        final d = _day;
        final date = _plan.dateOf(d);
        final today = TripEnquiryRules.todayIst(DateTime.now().toUtc());
        final isToday = date != null && date.year == today.year && date.month == today.month && date.day == today.day;
        return TripPageHeader(
          title: TripStrings.dayTitle(d, today: isToday),
          subtitle: TripStrings.joinDots([
            _plan.cityName,
            date == null ? null : TripFormat.dayMonth(date),
            TripStrings.peopleText(_plan.settings.peopleCount),
          ]),
          onBack: () => Get.back(),
          gradient: TaxiColors.gradient,
          bottom: TripTaxiStayToggle(
            selected: TripSupplyKind.taxi,
            day: d,
            onHeader: true,
            activeColor: TaxiColors.accent,
          ),
        );
      });

  Widget _narrow(Widget child) => Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _maxWidth), child: child),
      );

  Widget _buildTop() {
    return Obx(() {
      final d = _day;
      _plan.plan.value;
      _plan.enquiryList.length;
      final readOnly = _readOnly(d);
      final showChips = !readOnly && _supply.taxis.isNotEmpty;
      return _narrow(Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TripRouteStrip(day: d, onDayChanged: _supply.setDay, accent: TaxiColors.accent),
            if (showChips) ...[
              const SizedBox(height: 12),
              TripFilterChips(accent: TaxiColors.accent, items: [
                TripFilterChip(
                  label: TripStringsA3.seats4,
                  selected: _supply.minSeats.value == 4,
                  onTap: () => _supply.minSeats.value = _supply.minSeats.value == 4 ? null : 4,
                ),
                TripFilterChip(
                  label: TripStringsA3.seats6,
                  selected: _supply.minSeats.value == 6,
                  onTap: () => _supply.minSeats.value = _supply.minSeats.value == 6 ? null : 6,
                ),
                TripFilterChip(
                  label: TripStringsA3.suv,
                  selected: _supply.onlySuv.value,
                  onTap: () => _supply.onlySuv.value = !_supply.onlySuv.value,
                ),
                TripFilterChip(
                  label: TripStringsA3.wholeTrip,
                  selected: _wholeTrip.value,
                  onTap: () => _wholeTrip.value = !_wholeTrip.value,
                ),
              ]),
            ],
            ..._banner(d),
          ],
        ),
      ));
    });
  }

  List<Widget> _banner(int d) {
    final booked = _plan.bookedTaxiEnquiryFor(d);
    final own = _plan.ownTaxiOf(d);
    final chosen = _plan.plan.value?.dayAt(d)?.taxi;
    final readOnly = _readOnly(d);
    if (booked != null) {
      return [
        const SizedBox(height: 12),
        _bannerBox(
          text: TripStringsA3.bookedBanner(TripLeadFormat.driver(booked)),
          bg: TripStatusColors.bookedSurface,
          fg: TripStatusColors.booked,
          actions: [
            if (!readOnly)
              _bannerAction(TripStrings.cancelBooking, () => TripCancelSheet.show(context, enquiry: booked, ownerSide: false)),
            _bannerAction(TripStrings.backToPlan, TripBackToPlanBar.backToPlan),
          ],
        ),
      ];
    }
    if (own != null) {
      return [
        const SizedBox(height: 12),
        _bannerBox(
          text: TripStringsA3.ownTaxiBanner(own.name),
          bg: TripStatusColors.bookedSurface,
          fg: TripStatusColors.booked,
          actions: [
            if (!readOnly) _bannerAction(TripStringsA3.edit, _own),
            _bannerAction(TripStrings.backToPlan, TripBackToPlanBar.backToPlan),
          ],
        ),
      ];
    }
    if (chosen != null && !chosen.isOwn) {
      return [
        const SizedBox(height: 12),
        _bannerBox(
          text: chosen.isBooked ? TripStrings.bookedBar(chosen.name) : TripStringsA3.selectedForDay(chosen.name, d),
          bg: AppColors.successSurface,
          fg: AppColors.successText,
          actions: [_bannerAction(TripStrings.backToPlan, TripBackToPlanBar.backToPlan)],
        ),
      ];
    }
    return const [];
  }

  Widget _bannerBox({required String text, required Color bg, required Color fg, required List<Widget> actions}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
          Wrap(spacing: 4, children: actions),
        ],
      ),
    );
  }

  Widget _bannerAction(String label, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
        child: Text(label,
            maxLines: 1,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TripColors.accentDark)),
      );

  Widget _stateBox({
    required IconData icon,
    required String title,
    required String subtitle,
    List<Widget> actions = const [],
  }) {
    return SliverToBoxAdapter(
      child: _narrow(Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: TripColors.surface, shape: BoxShape.circle),
              child: Icon(icon, size: 28, color: TripColors.accent),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight, height: 1.4)),
            for (final a in actions) ...[const SizedBox(height: 12), a],
          ],
        ),
      )),
    );
  }

  Widget _outlinedAction(String label, IconData icon, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18, color: TripColors.accent),
          label: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: TripColors.accent)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: TripColors.accent, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  Widget _buildBody() {
    return Obx(() {
      final d = _day;
      _plan.plan.value;
      _plan.enquiryList.length;
      if (_readOnly(d)) {
        final hasReplies = _plan.taxiEnquiriesForDay(d).isNotEmpty;
        return _stateBox(
          icon: Iconsax.lock,
          title: _plan.isReadOnly ? TripStringsA3.pastTripTitle : TripStringsA3.pastDayTitle,
          subtitle: TripStringsA3.readOnlyBody,
          actions: [
            if (hasReplies) _outlinedAction(TripStrings.taxiReplies, Iconsax.message, () => TripNavigation.openTaxiReplies(d)),
          ],
        );
      }
      final items = _supply.taxis;
      if (items.isEmpty) {
        if (_supply.taxiLoading.value) {
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverList.separated(
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, _) => _narrow(TripShimmers.rowBox(height: TripDriverRow.height)),
            ),
          );
        }
        if (_supply.taxiFailed.value) {
          return SliverToBoxAdapter(
            child: EmptyStateView(
              icon: Iconsax.cloud_cross,
              title: TripStrings.taxisFailed,
              subtitle: TripStrings.checkConnection,
              onRetry: () => _supply.loadTaxis(),
              retryLabel: TripStrings.retry,
              palette: TripColors.palette,
            ),
          );
        }
        return _stateBox(
          icon: Iconsax.car,
          title: TripStringsA3.noDriversTitle,
          subtitle: TripStringsA3.noDriversBody,
          actions: [
            _outlinedAction(TripStringsA3.iHaveTaxi, Iconsax.car, _own),
            if (!_plan.taxiTabOff.value)
              TextButton(
                onPressed: () => TaxiNavigation.openList(),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: const Text(TripStrings.seeAllTaxis,
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark)),
              ),
          ],
        );
      }
      final list = _supply.filteredTaxis;
      if (list.isEmpty) {
        return _stateBox(
          icon: Iconsax.filter,
          title: TripStringsA3.noMatchTitle,
          subtitle: TripStringsA3.noMatchBody,
          actions: [_outlinedAction(TripStringsA3.clearFilters, Iconsax.close_circle, _clearFilters)],
        );
      }
      final chosenId = _plan.plan.value?.dayAt(d)?.taxi?.taxiId;
      final full = _plan.taxiShortlistCount(d) >= _shortlistMax;
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverList.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final t = list[i];
            final status = _plan.taxiStatusFor(d, t.id);
            return _narrow(Obx(() => TripDriverRow(
                  key: ValueKey('${t.id}-$d'),
                  item: t,
                  status: status,
                  shortlisted: _plan.isTaxiShortlisted(d, t.id),
                  shortlistFull: full,
                  selected: chosenId == t.id,
                  contactBusy: _contactBusy.contains(t.id),
                  onOpen: () => _open(t),
                  onCall: () => _contact(t, whatsApp: false),
                  onWhatsApp: () => _contact(t, whatsApp: true),
                  onShortlist: () => status == null ? _shortlist(t) : TripNavigation.openTaxiReplies(d),
                  menuItems: _menu(d),
                  onMenu: (v) => switch (v) {
                    0 => _select(t),
                    1 => _book(t),
                    _ => _open(t),
                  },
                )));
          },
        ),
      );
    });
  }

  List<PopupMenuEntry<int>> _menu(int d) {
    PopupMenuItem<int> item(int v, IconData icon, String label) => PopupMenuItem<int>(
          value: v,
          child: Row(
            children: [
              Icon(icon, size: 18, color: TripColors.accentDark),
              const SizedBox(width: 10),
              Flexible(
                child: Text(label,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textDark)),
              ),
            ],
          ),
        );
    return [
      item(0, Iconsax.tick_circle, TripStringsA3.useForDay(d)),
      item(1, Iconsax.receipt_edit, TripStringsA3.iBookedThis),
      item(2, Iconsax.eye, TripStringsA3.viewDetails),
    ];
  }

  Widget _buildBar() {
    return Obx(() {
      final d = _day;
      _plan.plan.value;
      _plan.enquiryList.length;
      if (_readOnly(d)) return const SizedBox.shrink();
      final empty = _supply.taxis.isEmpty && !_supply.taxiLoading.value && !_supply.taxiFailed.value;
      if (empty) return const SizedBox.shrink();
      final n = _plan.taxiShortlistCount(d);
      final sendable = _plan.sendableTaxiShortlist(d);
      final days = sendable.isEmpty ? 0 : _sendDays(d);
      return TripPageBottomBar(
        counterText: n == 0 ? TripStringsA3.shortlistNone : TripStrings.shortlistedCount(n),
        secondaryLabel: TripStringsA3.iHaveTaxi,
        secondaryIcon: Iconsax.car,
        onSecondary: _own,
        primaryLabel: days == 0 ? TripStringsA3.sendIdle : TripStringsA3.sendForDays(days),
        onPrimary: days == 0 ? null : _send,
        hint: n >= _shortlistMax ? TripStrings.shortlistFull : null,
        accent: TaxiColors.accent,
        gradient: TaxiColors.gradient,
      );
    });
  }

  Widget _buildFooter() {
    return Obx(() => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: SizedBox(
            height: 24,
            child: _supply.taxiLoadingMore.value
                ? const Center(
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
