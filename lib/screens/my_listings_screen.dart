import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/config_controller.dart';
import '../controllers/listing_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/wallet_controller.dart';
import '../models/go_live_result.dart';
import '../models/listing_model.dart';
import '../models/plan_selection_result.dart';
import '../services/listing_permission_service.dart';
import '../utils/app_toast.dart';
import '../widgets/app_loading_overlay.dart';
import '../widgets/coin_balance_chip.dart';
import '../widgets/go_live_success_dialog.dart';
import '../widgets/insufficient_balance_sheet.dart';
import '../widgets/listing_card.dart';

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
    _dataReady = _ctrl.loadMyListings(page: 1).catchError((_) {});
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
      _dataReady = _ctrl.loadMyListings(page: 1).catchError((_) {});
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
    await _ctrl.loadMyListings(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() => AppLoadingOverlay(
        isLoading: _ctrl.isDeleting.value || _ctrl.isTogglingActive.value,
        message: _ctrl.isTogglingActive.value ? 'Updating...' : 'Deleting...',
        child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 20, 24),
                child: Row(
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
                    const CoinBalanceChip(color: Colors.white),
                    const SizedBox(width: 8),
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
              ),
            ),
          ),

          Obx(() => _buildRoomCapStrip()),
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
                  itemBuilder: (_, i) {
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
                        onDelete: () => _confirmDelete(listings[i].id),
                        onGoLive: () => _onGoLiveTap(listings[i]),
                        isGoLiveLoading: _goLiveLoadingId == listings[i].id,
                        onReportsTap: () => Get.toNamed(AppRoutes.listingReports, arguments: {
                          'listingId': listings[i].id,
                          'listingType': 'Room',
                          'title': listings[i].roomTypeName ?? 'Room for Rent',
                        }),
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
        case ListingLimitReached():
          _showRoomLimitDialog(cap: result.cap);
      }
    } catch (_) {
      AppToast.error('Could not verify your listing limit. Please try again.');
    } finally {
      if (mounted) setState(() => _isAddingRoom = false);
    }
  }

  void _showRoomLimitDialog({required int cap}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  size: 30, color: Color(0xFFF59E0B)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Room Limit Reached',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You can list up to $cap room${cap > 1 ? 's' : ''}. Delete an existing room to add a new one.',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.textMedium,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.list_alt_rounded, size: 16),
                label: const Text('Manage Rooms',
                    style: TextStyle(
                        fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onGoLiveTap(ListingModel listing) async {
    if (_goLiveLoadingId != null) return;
    setState(() => _goLiveLoadingId = listing.id);
    try {
      final stillWithinValidity = listing.validUntil != null &&
          listing.validUntil!.toUtc().isAfter(DateTime.now().toUtc());

      if (stillWithinValidity) {
        // Free reactivation — owner turned it off, is turning it back on
        // before the previously-paid window expired. No plan dialog needed.
        final result = await _ctrl.goLive(listing.id);
        if (mounted) await _handleGoLiveResult(result, spentCoins: 0);
        return;
      }

      // Loop rather than a single pass: picking "Add Coins" on an
      // unaffordable row (or hitting a 409 INSUFFICIENT_BALANCE despite the
      // client-side check, e.g. balance changed elsewhere) routes to
      // CoinPacksScreen and, on a successful purchase, comes back here to
      // reopen the plan sheet against the refreshed balance — same loading
      // state (`_goLiveLoadingId`) held the whole way through instead of a
      // fragile recursive re-entry into this method.
      while (true) {
        final plans = await _ctrl.getPlans();
        if (!mounted) return;
        final selection = await _showPlanSelectionDialog(plans: plans);
        if (selection == null) return; // "Maybe Later" / dismissed

        if (selection is PlanSelectionAddCoins) {
          final toppedUp = await Get.toNamed(AppRoutes.coinPacks, arguments: {'returnToGoLive': true});
          if (toppedUp == true && mounted) continue;
          return;
        }

        final selectedPlan = (selection as PlanSelected).plan;
        final planType = selectedPlan['planType'] as String? ?? '';
        final price = (selectedPlan['originalPrice'] as num?)?.toInt() ?? 0;
        final result = await _ctrl.goLive(listing.id, planType: planType, requiredCoins: price);
        if (!mounted) return;
        final retry = await _handleGoLiveResult(result, spentCoins: price);
        if (retry && mounted) continue;
        return;
      }
    } finally {
      if (mounted) setState(() => _goLiveLoadingId = null);
    }
  }

  /// Returns true when the caller should loop back and re-show the plan
  /// sheet (owner topped up from the insufficient-balance sheet and wants to
  /// resume), false for every other outcome.
  Future<bool> _handleGoLiveResult(GoLiveResult result, {required int spentCoins}) async {
    switch (result) {
      case GoLiveSuccess():
        Get.dialog(
          GoLiveSuccessDialog(
            isPlot: false,
            planType: result.planType,
            coinsSpent: spentCoins,
            validUntil: result.validUntil,
            onDismiss: _refresh,
          ),
          barrierDismissible: false,
        );
        return false;
      case GoLiveInsufficientBalance g:
        if (!mounted) return false;
        return InsufficientBalanceSheet.show(
          context,
          required: g.requiredCoins,
          current: Get.find<WalletController>().balance.value,
        );
      case GoLiveConcurrentUpdate g:
        AppToast.error(g.message);
        return false;
      case GoLiveFailure g:
        AppToast.error(g.message);
        return false;
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

  /// Each listing already carries its own validUntil/isActive (see
  /// ListingCard's own expiry label) — this strip just shows the flat
  /// creation cap usage, sourced from ConfigController, with no separate
  /// membership call needed.
  Widget _buildRoomCapStrip() {
    final cap = Get.find<ConfigController>().roomLimit.value;
    final used = _ctrl.myListings.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.bed_rounded, size: 13, color: AppColors.primary),
        const SizedBox(width: 6),
        Text('$used / $cap rooms used',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                color: AppColors.primary, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  void _confirmDelete(String id) {
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
                : const Text('Are you sure? This will also delete all photos.',
                    style: TextStyle(fontFamily: 'Poppins')),
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

  Widget _coinPrice(int amount, {required Color color, double size = 16}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.monetization_on_rounded, size: size, color: color),
      const SizedBox(width: 4),
      Text('$amount', style: TextStyle(fontFamily: 'Poppins', fontSize: size, fontWeight: FontWeight.w700, color: color)),
    ]);
  }

  Future<PlanSelectionResult?> _showPlanSelectionDialog({
    required Map<String, Map<String, dynamic>> plans,
  }) async {
    const golden = Color(0xFFD4A017);
    final screenH = MediaQuery.of(context).size.height;

    final visiblePlans = plans.values.toList()
      ..sort((a, b) => (a['originalPrice'] as num? ?? 0).compareTo(b['originalPrice'] as num? ?? 0));

    if (visiblePlans.isEmpty) {
      AppToast.error('No plans available right now. Please try again later.');
      return null;
    }

    // Affordability is computed client-side against the live wallet balance
    // (read once — a fresh dialog is opened whenever the balance can have
    // changed, e.g. after a coin top-up) so each row can render its own
    // Select-vs-Add-Coins state instead of only discovering a shortfall
    // reactively from a 409 INSUFFICIENT_BALANCE after the network call.
    final walletBalance = Get.find<WalletController>().balance.value;
    String? selectedType = visiblePlans
        .firstWhere(
          (p) => walletBalance >= ((p['originalPrice'] as num?)?.toInt() ?? 0),
          orElse: () => const {},
        )['planType'] as String?;

    return showDialog<PlanSelectionResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final selectedPlan = selectedType == null
              ? null
              : visiblePlans.firstWhere(
                  (p) => p['planType'] == selectedType,
                  orElse: () => visiblePlans.first,
                );
          final selOrigPrice = (selectedPlan?['originalPrice'] as num?)?.toInt() ?? 0;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 36),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: screenH * 0.78),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 52, 20, 4),
                          child: Column(children: [
                            const Text('Make Room Live', style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                            const SizedBox(height: 4),
                            const Text('Choose a plan to activate your listing', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium), textAlign: TextAlign.center),
                          ]),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Column(
                              children: visiblePlans.map((p) {
                                final normalPrice = (p['price'] as num?)?.toInt() ?? 0;
                                final origPrice = (p['originalPrice'] as num?)?.toInt() ?? 0;
                                final disc = (p['discountPercent'] as num?)?.toInt() ?? 0;
                                final hasDiscount = disc > 0 && normalPrice > 0;
                                final days = (p['days'] as num?)?.toInt() ?? 30;
                                final rooms = (p['roomLimit'] as num?)?.toInt() ?? 1;
                                final raw = (p['planType'] as String? ?? '');
                                final label = raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1).toLowerCase();
                                final afford = walletBalance >= origPrice;
                                final isSelected = afford && selectedType == raw;
                                final shortfall = afford ? 0 : origPrice - walletBalance;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Opacity(
                                    opacity: afford ? 1 : 0.55,
                                    child: GestureDetector(
                                      onTap: afford ? () => setS(() => selectedType = raw) : null,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isSelected ? golden.withValues(alpha: 0.04) : Colors.white,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: isSelected ? golden : AppColors.divider, width: isSelected ? 2 : 1.5),
                                        ),
                                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Container(
                                            width: 22, height: 22,
                                            margin: const EdgeInsets.only(top: 1),
                                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? golden : AppColors.textLight, width: 2)),
                                            child: isSelected ? Center(child: Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: golden))) : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Row(children: [
                                              Text('$label Plan', style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                              if (hasDiscount) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(4)),
                                                  child: Text('$disc% Savings', style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                                                ),
                                              ],
                                            ]),
                                            Text('Valid for $days days • $rooms room${rooms > 1 ? 's' : ''}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                                            if (!afford) ...[
                                              const SizedBox(height: 4),
                                              Text('Need $shortfall more coin${shortfall == 1 ? '' : 's'}',
                                                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error)),
                                            ],
                                          ])),
                                          const SizedBox(width: 8),
                                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                            if (hasDiscount)
                                              _coinPrice(normalPrice, color: AppColors.textLight, size: 12),
                                            _coinPrice(origPrice, color: origPrice == 0 ? AppColors.success : AppColors.primary),
                                            if (!afford) ...[
                                              const SizedBox(height: 6),
                                              GestureDetector(
                                                onTap: () => Navigator.pop(ctx, PlanSelectionAddCoins()),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(8)),
                                                  child: const Text('Add Coins',
                                                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                                                ),
                                              ),
                                            ],
                                          ]),
                                        ]),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                          child: Column(children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: selectedPlan == null
                                    ? null
                                    : () async {
                                        if (selOrigPrice == 0) {
                                          Navigator.pop(ctx, PlanSelected(selectedPlan));
                                          return;
                                        }
                                        // Distinct "Confirm Spend" moment — the network
                                        // call (and the coin debit) must not fire until
                                        // the owner explicitly confirms the exact spend.
                                        final days = (selectedPlan['days'] as num?)?.toInt() ?? 30;
                                        final confirmed = await showDialog<bool>(
                                          context: ctx,
                                          builder: (c) => AlertDialog(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            title: const Text('Confirm Spend',
                                                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                            content: Text(
                                              'Spend $selOrigPrice coins to go live for $days days?',
                                              style: const TextStyle(fontFamily: 'Poppins', color: AppColors.textMedium, height: 1.4),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(c, false),
                                                child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(c, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.primary,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                child: const Text('Confirm', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true && ctx.mounted) Navigator.pop(ctx, PlanSelected(selectedPlan));
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: Text(
                                  selectedPlan == null ? 'Select an affordable plan' : (selOrigPrice == 0 ? 'Activate FREE' : 'Continue'),
                                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Maybe Later', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight, fontSize: 13)),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: ClipOval(child: Image.asset('assets/images/icon_logo.png', width: 72, height: 72, fit: BoxFit.cover)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
