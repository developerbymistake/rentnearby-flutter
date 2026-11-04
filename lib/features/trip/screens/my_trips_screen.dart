import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../widgets/empty_state_view.dart';
import '../../../widgets/selectable_chip.dart';
import '../controllers/my_trips_controller.dart';
import '../models/trip_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_shimmers.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  static int _open = 0;
  late final MyTripsController _ctrl;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _open++;
    _ctrl = MyTripsController.to;
    _ctrl.load();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _open--;
    if (_open == 0) Get.delete<MyTripsController>();
    super.dispose();
  }

  void _onScroll() {
    final p = _scroll.position;
    if (p.maxScrollExtent > 0 && p.pixels >= p.maxScrollExtent - 300) _ctrl.loadMore();
  }

  void _openPlan(TripSummaryModel t) {
    TripNavigation.openPlan(tripId: t.id)?.then((_) {
      if (mounted) _ctrl.load();
    });
  }

  void _openMap(TripSummaryModel t) {
    _openPlan(t);
    // Get.arguments is global; the plan screen must read its args before the map route is pushed.
    WidgetsBinding.instance.addPostFrameCallback((_) => TripNavigation.openMap());
  }

  Future<void> _delete(TripSummaryModel t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(TripStrings.deleteTrip, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: const Text(TripStrings.deleteConfirmBody, style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(TripStrings.cancelAction, style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(64, 44),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(TripStrings.delete, style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
    if (ok == true) await _ctrl.delete(t.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: RefreshIndicator(
              color: TripColors.accent,
              onRefresh: _ctrl.load,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildBody(context),
                  SliverToBoxAdapter(child: _buildFooter()),
                ],
              ),
            ),
          ),
        ],
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 2),
              const Expanded(
                child: Text(
                  TripStrings.myTrips,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Obx(() {
              final c = _ctrl.counts.value;
              const chipPad = EdgeInsets.symmetric(vertical: 13, horizontal: 14);
              return Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  SelectableChip(
                    label: TripStrings.upcomingChip(c.upcoming),
                    selected: _ctrl.state.value == 'upcoming',
                    activeColor: TripColors.accentDark,
                    padding: chipPad,
                    onTap: () => _ctrl.selectState('upcoming'),
                  ),
                  SelectableChip(
                    label: TripStrings.completedChip(c.completed),
                    selected: _ctrl.state.value == 'completed',
                    activeColor: TripColors.accentDark,
                    padding: chipPad,
                    onTap: () => _ctrl.selectState('completed'),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Obx(() {
      if (_ctrl.plannerOff.value) {
        return const SliverToBoxAdapter(
          child: EmptyStateView(
            icon: Iconsax.routing_2,
            title: TripStrings.plannerOff,
            subtitle: TripStrings.plannerOffSubtitle,
            palette: TripColors.palette,
          ),
        );
      }
      final items = _ctrl.items;
      if (items.isEmpty) {
        if (_ctrl.isLoading.value) {
          return SliverPadding(
            padding: EdgeInsets.fromLTRB(_sidePad(context), 16, _sidePad(context), 0),
            sliver: SliverList.separated(
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, _) => const TripCardSkeleton(),
            ),
          );
        }
        final failed = _ctrl.loadFailed.value;
        final completed = _ctrl.state.value == 'completed';
        return SliverToBoxAdapter(
          child: failed
              ? EmptyStateView(
                  icon: Iconsax.cloud_cross,
                  title: TripStrings.tripsFailed,
                  subtitle: TripStrings.checkConnection,
                  onRetry: _ctrl.load,
                  palette: TripColors.palette,
                )
              : completed
                  ? const EmptyStateView(
                      icon: Iconsax.routing_2,
                      title: TripStrings.noCompletedTrips,
                      subtitle: TripStrings.noCompletedSub,
                      palette: TripColors.palette,
                    )
                  : EmptyStateView(
                      icon: Iconsax.routing_2,
                      title: TripStrings.noUpcomingTrips,
                      subtitle: TripStrings.noTripsSubtitle,
                      onRetry: () => TripNavigation.start(context),
                      retryLabel: TripStrings.planATrip,
                      palette: TripColors.palette,
                    ),
        );
      }
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(_sidePad(context), 16, _sidePad(context), 0),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final t = items[i];
            return TripCard(
              key: ValueKey(t.id),
              trip: t,
              onOpen: () => _openPlan(t),
              onMap: () => _openMap(t),
              onSummary: () => TripNavigation.openSummary(t.id),
              onDelete: () => _delete(t),
            );
          },
        ),
      );
    });
  }

  static double _sidePad(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w > 640 ? (w - 640) / 2 : 16;
  }

  Widget _buildFooter() {
    return Obx(() => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: SizedBox(
            height: 24,
            child: _ctrl.isLoadingMore.value
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
