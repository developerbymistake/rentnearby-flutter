import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/listing_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/plan_controller.dart';
import '../models/listing_model.dart';
import '../services/go_live_flow.dart';
import '../services/listing_permission_service.dart';
import '../services/listing_share_service.dart';
import '../utils/app_toast.dart';
import '../widgets/app_loading_overlay.dart';
import '../widgets/listing_card.dart';
import '../widgets/plan_cap_strip.dart';
import '../widgets/plan_limit_reached_sheet.dart';
import '../widgets/swap_live_sheet.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});
  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen>
    with WidgetsBindingObserver {
  final _ctrl = Get.find<ListingController>();
  final _scrollCtrl = ScrollController();
  int _page = 1;
  bool _isAddingRoom = false;
  String? _goLiveLoadingId;
  Future<void> _dataReady = Future.value();
  late final _permissionService = ListingPermissionService(
    _ctrl,
    Get.find<LocationController>(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dataReady = _ctrl.loadMyListings(page: 1).catchError((_) => false);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No longer gated on tabIndex — this screen is now a pushed route (not a
    // resident IndexedStack tab), so "app resumed while this screen is on
    // top" is itself the correct condition for a refresh.
    if (state == AppLifecycleState.resumed) {
      _page = 1;
      _dataReady = _ctrl.loadMyListings(page: 1).catchError((_) => false);
      Get.find<PlanController>().invalidate();
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 &&
        _ctrl.hasMoreMyListings.value &&
        !_ctrl.isLoading.value) {
      _page++;
      _ctrl.loadMyListings(page: _page);
    }
  }

  Future<void> _refresh() async {
    _page = 1;
    await Future.wait([
      _ctrl.loadMyListings(page: 1),
      Get.find<PlanController>().refreshPlan(force: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() => AppLoadingOverlay(
        isLoading: _ctrl.isDeleting.value || _ctrl.isTogglingActive.value || _ctrl.isSharing.value,
        message: _ctrl.isSharing.value
            ? 'Sharing...'
            : (_ctrl.isTogglingActive.value ? 'Updating...' : 'Deleting...'),
        child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Get.back(),
                          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('My Rooms',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          const Text('Manage your listings',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white70)),
                        ]),
                        const Spacer(),
                        GestureDetector(
                          onTap: _isAddingRoom ? null : _onAddRoom,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: _isAddingRoom
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: AppColors.primary),
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                                      SizedBox(width: 4),
                                      Text('Add Room',
                                          style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary)),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const PlanCapStrip(accent: AppColors.primary, icon: Icons.bed_rounded, unitPlural: 'rooms'),
          Expanded(
            child: Obx(() {
              final isLoading = _ctrl.isLoading.value;
              final listings = _ctrl.myListings;
              final hasMore = _ctrl.hasMoreMyListings.value;

              if (isLoading && listings.isEmpty) return _buildShimmer();
              if (listings.isEmpty) return _buildEmpty();

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refresh,
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + AppInsets.bottomViewPadding(context)),
                  itemCount: listings.length + (hasMore || isLoading ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == listings.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ListingCard(
                        listing: listings[i],
                        onToggleActive: () =>
                            _ctrl.toggleActive(listings[i].id, listings[i].isActive),
                        onDelete: () => _confirmDelete(listings[i].id, listings[i].isActive),
                        onGoLive: () => _onGoLiveTap(listings[i]),
                        isGoLiveLoading: _goLiveLoadingId == listings[i].id,
                        onReportsTap: () => Get.toNamed(AppRoutes.listingReports, arguments: {
                          'listingId': listings[i].id,
                          'listingType': 'Room',
                          'title': listings[i].roomTypeName ?? 'Room for Rent',
                        }),
                        onPreview: () => Get.toNamed(AppRoutes.listingDetail, arguments: {'id': listings[i].id}),
                        onShare: (listings[i].isActive && listings[i].slug != null)
                            ? () => _shareListing(ctx, listings[i])
                            : null,
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
        ),
      )),
    );
  }

  void _onAddRoom() async {
    if (_isAddingRoom) return;
    setState(() => _isAddingRoom = true);
    try {
      await _dataReady;
      final result = await _permissionService.check();
      if (!mounted) return;
      switch (result) {
        case ListingAllowed():
          Get.toNamed(AppRoutes.addListing);
        case ListingNeedsDistrict():
          AppToast.error('Your area is not supported yet. Contact admin to expand coverage.');
        case ListingPlanUnavailable():
          AppToast.error('Could not check your plan. Try again.');
        case ListingLimitReached():
          PlanLimitReachedSheet.show(context, limit: result.cap, unitSingular: 'room', unitPlural: 'rooms', accent: AppColors.primary);
      }
    } catch (_) {
      AppToast.error('Could not verify your listing limit. Please try again.');
    } finally {
      if (mounted) setState(() => _isAddingRoom = false);
    }
  }

  void _onGoLiveTap(ListingModel listing) async {
    if (_goLiveLoadingId != null) return;
    setState(() => _goLiveLoadingId = listing.id);
    try {
      await GoLiveFlow.run(
        context,
        isPlot: false,
        accent: AppColors.primary,
        goLive: () => _ctrl.goLive(listing.id),
        swap: (pauseId) => _ctrl.swapLive(listing.id, pauseId),
        liveOptions: [
          for (final l in _ctrl.myListings)
            if (l.isActive && l.id != listing.id)
              SwapOption(
                id: l.id,
                title: l.roomTypeName ?? 'Room for Rent',
                subtitle: [l.districtName, l.cityName].where((e) => e != null && e.isNotEmpty).join(', '),
              ),
        ],
        preferSwap: listing.isPausedByPlan,
        canSwap: listing.isApproved,
      );
    } finally {
      if (mounted) setState(() => _goLiveLoadingId = null);
    }
  }

  Widget _buildEmpty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
                color: AppColors.surface, shape: BoxShape.circle),
            child: const Icon(Iconsax.building,
                size: 40, color: AppColors.primaryLight),
          ),
          const SizedBox(height: 20),
          const Text('No listings yet',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
          const SizedBox(height: 8),
          const Text('Add your first room listing',
              style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 14, color: AppColors.textLight)),
        ]),
      );

  Widget _buildShimmer() => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (context, idx) => Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Container(
            height: 120,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );

  Future<void> _shareListing(BuildContext ctx, ListingModel listing) async {
    _ctrl.isSharing.value = true;
    try {
      await shareListing(
        context: ctx,
        type: 'r',
        slug: listing.slug!,
        photoUrl: listing.photos.isNotEmpty ? listing.photos.first : null,
        priceOrArea: listing.priceDisplay,
        typeLabel: listing.roomTypeName ?? 'Room for Rent',
        locality: [listing.districtName, listing.cityName].where((e) => e != null && e.isNotEmpty).join(', '),
        furnishedStatus: listing.furnishedStatus,
      );
    } finally {
      _ctrl.isSharing.value = false;
    }
  }

  void _confirmDelete(String id, bool wasLive) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: isDeleting ? null : const Text('Delete Listing',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            content: isDeleting
                ? const SizedBox(
                    height: 80,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.error, strokeWidth: 2.5),
                          SizedBox(height: 14),
                          Text('Deleting...',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: AppColors.textMedium)),
                        ],
                      ),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Are you sure? This will also delete all photos.',
                          style: TextStyle(fontFamily: 'Poppins')),
                      if (wasLive && Get.find<PlanController>().myPlan.value.pausedByPlanCount > 0) ...[
                        const SizedBox(height: 12),
                        const Text('Your paused listing will go live.',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textLight)),
                      ],
                    ],
                  ),
            actions: isDeleting ? null : [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                onPressed: () async {
                  setDialogState(() => isDeleting = true);
                  await _ctrl.deleteListing(id);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Delete', style: TextStyle(fontFamily: 'Poppins')),
              ),
            ],
          ),
        );
      },
    );
  }
}
