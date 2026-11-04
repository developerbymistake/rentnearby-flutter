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
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../widgets/trip_back_to_plan_bar.dart';
import '../widgets/trip_route_strip.dart';
import '../widgets/trip_status.dart';
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

  Future<void> _select(TaxiBrowseItem t) async {
    final d = _supply.day.value;
    final current = _plan.plan.value?.dayAt(d)?.taxi;
    if (current != null && current.isBooked) {
      if (current.taxiId == t.id) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(TripStrings.replaceBooking('Day $d', current.name),
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
    await TripTaxiBookingSheet.show(context, taxi: t, day: _supply.day.value);
  }

  Future<void> _enquire(TaxiBrowseItem t) async {
    if (!_plan.hasDates) {
      final ok = await TripDetailsSheet.edit(
        context,
        heading: TripStrings.addYourDates,
        description: TripStrings.addYourDatesOwners,
      );
      if (!ok || !mounted) return;
    }
    await TripTaxiEnquirySheet.show(context, taxi: t, day: _supply.day.value);
  }

  TripDisplayStatus? _enquiryStatus(String taxiId) {
    for (final e in _plan.taxiEnquiriesForDay(_supply.day.value)) {
      if (e.listingId != taxiId) continue;
      final d = e.display;
      if (d == TripDisplayStatus.asked ||
          d == TripDisplayStatus.fareSent ||
          d == TripDisplayStatus.bookedByYou ||
          d == TripDisplayStatus.confirmedByBoth) {
        return d;
      }
    }
    return null;
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
        if (taxi != null && !taxi.isBooked) return TripBackToPlanBar(text: '${taxi.name} selected for Day $d');
        final booked = taxi ?? _plan.bookedTaxi;
        if (booked == null) return const SizedBox.shrink();
        return TripBackToPlanBar(text: TripStrings.bookedBar(booked.name));
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
            subtitle: failed ? TripStrings.checkConnection : TripStrings.noTripTaxisSubtitle,
            onRetry: failed
                ? () => _supply.loadTaxis()
                : (_plan.taxiTabOff.value ? null : () => TaxiNavigation.openList()),
            retryLabel: failed ? 'Retry' : TripStrings.seeAllTaxis,
            palette: TripColors.palette,
          ),
        );
      }
      _plan.enquiryList.length;
      final chosenId = _plan.plan.value?.dayAt(d)?.taxi?.taxiId;
      final bookedId = _plan.bookedTaxi?.taxiId;
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
              onSelect: () => _select(t),
              selected: chosenId == t.id,
              onBook: () => _book(t),
              booked: bookedId == t.id,
              onEnquire: () {
                final status = _enquiryStatus(t.id);
                if (status == null) {
                  _enquire(t);
                } else {
                  TripNavigation.openTaxiReplies(d);
                }
              },
              enquiryStatus: _enquiryStatus(t.id),
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
