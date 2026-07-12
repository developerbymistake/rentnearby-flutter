import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/app_feature_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/listing_controller.dart';
import '../controllers/location_controller.dart';
import '../services/listing_permission_service.dart';
import '../utils/app_toast.dart';
import '../widgets/app_loading_overlay.dart';
import '../widgets/listing_card.dart';
import '../widgets/payment_success_dialog.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});
  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen>
    with WidgetsBindingObserver {
  final _ctrl = Get.find<ListingController>();
  final _auth = Get.find<AuthController>();
  final _scrollCtrl = ScrollController();
  int _page = 1;
  bool _isAddingRoom = false;
  String? _goLiveLoadingId;
  Future<void> _dataReady = Future.value();
  late final _permissionService = ListingPermissionService(
    _ctrl,
    _auth,
    Get.find<LocationController>(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dataReady = Future.wait([
      _ctrl.loadMyListings(page: 1),
      _ctrl.loadMembership(),
    ]).then((_) {}).catchError((_) {});
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
      _dataReady = Future.wait([
        _ctrl.loadMyListings(page: 1),
        _ctrl.loadMembership(),
      ]).then((_) {}).catchError((_) {});
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
        isLoading: _ctrl.isDeleting.value || _ctrl.isTogglingActive.value || _ctrl.isMembershipLoading.value,
        message: _ctrl.isMembershipLoading.value
            ? 'Loading...'
            : _ctrl.isTogglingActive.value
                ? 'Updating...'
                : 'Deleting...',
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

          Obx(() => _buildRoomPlanStrip()),
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
                        onGoLive: () => _showPaymentDialog(listings[i].id),
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
        case ListingShowLimitDialog():
          _showRoomLimitDialog(maxRooms: result.maxRooms, hasPlan: result.hasPlan);
        case ListingShowUpgradeSheet():
          _showPaidUpgradeSheet();
      }
    } catch (_) {
      AppToast.error('Could not verify your plan. Please try again.');
    } finally {
      if (mounted) setState(() => _isAddingRoom = false);
    }
  }

  void _showRoomLimitDialog({required int maxRooms, required bool hasPlan}) {
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
              hasPlan
                  ? 'Your current plan allows up to $maxRooms room${maxRooms > 1 ? 's' : ''}. Delete an existing room to add a new one.'
                  : 'Free plan allows 1 room. Delete your existing room to replace it, or go live with a Premium plan to add more.',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.textMedium,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (!hasPlan) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showPaidUpgradeSheet();
                  },
                  icon: const Icon(Icons.flash_on_rounded, size: 16),
                  label: const Text('Upgrade Plan',
                      style: TextStyle(
                          fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.list_alt_rounded, size: 16),
                  label: const Text('Manage Rooms',
                      style: TextStyle(
                          fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMedium,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else
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

  void _showPaidUpgradeSheet({String listingId = '', bool allowRenewal = false}) async {
    final plans = _ctrl.roomPlans.value;
    final currentCount = _ctrl.myListings.length;

    // Plans strictly above current room count (true upgrade)
    final upgradePlans = (plans.values
        .where((p) =>
            (p['originalPrice'] as num? ?? 0) > 0 &&
            (p['roomLimit'] as num? ?? 0) > currentCount)
        .toList()
      ..sort((a, b) => (a['originalPrice'] as num? ?? 0).compareTo(b['originalPrice'] as num? ?? 0)));

    // Plans that match current room count (renewal — same level)
    final renewalPlans = (plans.values
        .where((p) =>
            (p['originalPrice'] as num? ?? 0) > 0 &&
            (p['roomLimit'] as num? ?? 0) >= currentCount)
        .toList()
      ..sort((a, b) => (a['originalPrice'] as num? ?? 0).compareTo(b['originalPrice'] as num? ?? 0)));

    final displayPlans = allowRenewal
        ? (upgradePlans.isNotEmpty ? upgradePlans : renewalPlans.isNotEmpty ? renewalPlans : plans.values.toList()..sort((a, b) => (a['originalPrice'] as num? ?? 0).compareTo(b['originalPrice'] as num? ?? 0)))
        : upgradePlans;

    if (!mounted) return;

    String? selectedType = displayPlans.isNotEmpty
        ? (displayPlans.first['planType'] as String? ?? '')
        : null;

    const golden = Color(0xFFD4A017);
    final screenH = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final selectedPlan = displayPlans.isNotEmpty
              ? displayPlans.firstWhere((p) => p['planType'] == selectedType, orElse: () => displayPlans.first)
              : null;
          final selOrigPrice = (selectedPlan?['originalPrice'] as num?)?.toInt() ?? 0;
          final btnLabel = selOrigPrice == 0 ? 'Activate FREE' : 'Continue  ₹$selOrigPrice';

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // Dialog card
                Container(
                  margin: const EdgeInsets.only(top: 36),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: screenH * 0.78),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 52, 20, 4),
                          child: Column(children: [
                            const Text('Upgrade Your Plan',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                            const SizedBox(height: 4),
                            const Text('Choose a plan to add more rooms',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium),
                                textAlign: TextAlign.center),
                          ]),
                        ),
                        // Plan list
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: displayPlans.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text('No plans available.', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight), textAlign: TextAlign.center),
                                  )
                                : Column(
                                    children: displayPlans.map((p) {
                                      final normalPrice = (p['price'] as num?)?.toInt() ?? 0;
                                      final origPrice = (p['originalPrice'] as num?)?.toInt() ?? 0;
                                      final disc = (p['discountPercent'] as num?)?.toInt() ?? 0;
                                      final hasDiscount = disc > 0 && normalPrice > 0;
                                      final days = (p['days'] as num?)?.toInt() ?? 30;
                                      final rooms = (p['roomLimit'] as num?)?.toInt() ?? 2;
                                      final raw = (p['planType'] as String? ?? '');
                                      final label = raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1).toLowerCase();
                                      final isSelected = selectedType == raw;
                                      final displayPrice = origPrice == 0 ? 'FREE' : '₹$origPrice';

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: GestureDetector(
                                          onTap: () => setS(() => selectedType = raw),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: isSelected ? golden.withValues(alpha: 0.04) : Colors.white,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isSelected ? golden : AppColors.divider,
                                                width: isSelected ? 2 : 1.5,
                                              ),
                                            ),
                                            child: Row(children: [
                                              // Radio
                                              Container(
                                                width: 22, height: 22,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: isSelected ? golden : AppColors.textLight, width: 2),
                                                ),
                                                child: isSelected
                                                    ? Center(child: Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: golden)))
                                                    : null,
                                              ),
                                              const SizedBox(width: 12),
                                              // Name + badge
                                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                Row(children: [
                                                  Text('$label Plan',
                                                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                                  if (hasDiscount) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(4)),
                                                      child: Text('$disc% Savings',
                                                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                                                    ),
                                                  ],
                                                ]),
                                                Text('Valid for $days days • $rooms rooms',
                                                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                                              ])),
                                              // Prices
                                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                                if (hasDiscount)
                                                  Text('₹$normalPrice',
                                                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight, decoration: TextDecoration.lineThrough)),
                                                Text(displayPrice,
                                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700,
                                                        color: origPrice == 0 ? AppColors.success : AppColors.primary)),
                                              ]),
                                            ]),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ),
                        // Buttons
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                          child: Column(children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: selectedPlan == null ? null : () {
                                  Navigator.pop(ctx);
                                  Get.toNamed(AppRoutes.paymentScreen, arguments: {'listingId': listingId, 'plan': selectedPlan});
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: Text(btnLabel, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15)),
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

  void _showPaymentDialog(String listingId) async {
    setState(() => _goLiveLoadingId = listingId);
    try {
    final paymentEnabled = Get.find<AppFeatureController>().isRoomPaymentEnabled.value;
    if (!paymentEnabled) {
      setState(() => _goLiveLoadingId = null);
      _activateFreePlanDirect(listingId);
      return;
    }

    final hasUsedFree = _auth.user.value?.hasUsedFreePlan ?? false;
    if (mounted) setState(() => _goLiveLoadingId = null);
    final membership = _ctrl.roomMembership.value;
    final plans      = _ctrl.roomPlans.value;
    final hasMembership = membership != null && (membership['hasMembership'] == true);

    if (hasMembership) {
      // Membership exists and days remain — activate directly.
      // Room count limit is already enforced at Add Room time, no need to recheck here.
      _activateFreePlanDirect(listingId);
      return;
    }

    if (hasUsedFree) {
      if (mounted) _showPaidUpgradeSheet(listingId: listingId, allowRenewal: true);
      return;
    }

    if (!mounted) return;

    final selectedPlan = await _showPlanSelectionDialog(
      plans: plans,
      hasUsedFreePlan: hasUsedFree,
    );

    if (selectedPlan == null) return;

    final selectedPlanType = selectedPlan['planType'] as String? ?? '';
    final isFree = (selectedPlan['originalPrice'] as num? ?? 0) == 0;

    if (isFree) {
      final success = await _ctrl.activatePlan(listingId, selectedPlanType);
      if (!success) return;
      if (!mounted) return;
      Get.dialog(
        PaymentSuccessDialog(
          planType: selectedPlanType,
          daysValid: (selectedPlan['days'] as num?)?.toInt() ?? 2,
          maxRooms: (selectedPlan['roomLimit'] as num?)?.toInt() ?? 1,
          originalPrice: (selectedPlan['originalPrice'] as num?)?.toInt() ?? 0,
          onDismiss: () {
            // Already on this screen when the dialog shows (triggered from the
            // "Make it Live" flow here) — refresh so the newly-activated plan's
            // status reflects immediately, instead of the old tab-reselect no-op.
            _refresh();
          },
        ),
        barrierDismissible: false,
      );
      return;
    }

    await Get.toNamed(AppRoutes.paymentScreen, arguments: {
      'listingId': listingId,
      'plan': selectedPlan,
    });

    _refresh();
    } finally {
      if (mounted) setState(() => _goLiveLoadingId = null);
    }
  }

  void _activateFreePlanDirect(String listingId) async {
    await _ctrl.toggleActive(listingId, false);
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

  Widget _buildRoomPlanStrip() {
    final m = _ctrl.roomMembership.value;
    if (m == null || m['hasMembership'] != true) return const SizedBox.shrink();
    final plan = ((m['planType'] as String?) ?? '').toUpperCase();
    final max  = (m['maxRooms'] as num?)?.toInt() ?? 0;
    final used = _ctrl.myListings.length;
    final validUntilStr = m['validUntil'] as String?;
    final daysText = validUntilStr != null ? _daysLeft(validUntilStr) : '';
    final expired  = validUntilStr != null &&
        DateTime.parse(validUntilStr).toUtc().isBefore(DateTime.now().toUtc());
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.bed_rounded, size: 13, color: AppColors.primary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(plan,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                        color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          VerticalDivider(width: 1, thickness: 1, color: AppColors.primary.withValues(alpha: 0.2)),
          Expanded(
            child: Center(
              child: Text('$used / $max rooms',
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                      color: AppColors.primary, fontWeight: FontWeight.w500)),
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: AppColors.primary.withValues(alpha: 0.2)),
          Expanded(
            child: Center(
              child: Text(daysText,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                      fontWeight: expired ? FontWeight.w700 : FontWeight.w500,
                      color: expired ? AppColors.error : AppColors.primary)),
            ),
          ),
        ]),
      ),
    );
  }

  String _daysLeft(String s) {
    final days = DateTime.parse(s).toUtc().difference(DateTime.now().toUtc()).inDays;
    if (days < 0) return 'Expired';
    if (days == 0) return 'Expires today';
    return '$days days left';
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

  Future<Map<String, dynamic>?> _showPlanSelectionDialog({
    required Map<String, Map<String, dynamic>> plans,
    required bool hasUsedFreePlan,
  }) async {
    const golden = Color(0xFFD4A017);
    final screenH = MediaQuery.of(context).size.height;

    final allPlans = plans.values.toList()
      ..sort((a, b) => (a['originalPrice'] as num? ?? 0).compareTo(b['originalPrice'] as num? ?? 0));
    final visiblePlans = hasUsedFreePlan
        ? allPlans.where((p) => (p['originalPrice'] as num? ?? 0) > 0).toList()
        : allPlans;

    if (visiblePlans.isEmpty) return null;

    String? selectedType = visiblePlans.first['planType'] as String?;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final selectedPlan = visiblePlans.firstWhere(
            (p) => p['planType'] == selectedType,
            orElse: () => visiblePlans.first,
          );
          final selOrigPrice = (selectedPlan['originalPrice'] as num?)?.toInt() ?? 0;
          final btnLabel = selOrigPrice == 0 ? 'Activate FREE' : 'Continue  ₹$selOrigPrice';

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
                                final isSelected = selectedType == raw;
                                final displayPrice = origPrice == 0 ? 'FREE' : '₹$origPrice';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: GestureDetector(
                                    onTap: () => setS(() => selectedType = raw),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isSelected ? golden.withValues(alpha: 0.04) : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: isSelected ? golden : AppColors.divider, width: isSelected ? 2 : 1.5),
                                      ),
                                      child: Row(children: [
                                        Container(
                                          width: 22, height: 22,
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
                                        ])),
                                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                          if (hasDiscount)
                                            Text('₹$normalPrice', style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight, decoration: TextDecoration.lineThrough)),
                                          Text(displayPrice, style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: origPrice == 0 ? AppColors.success : AppColors.primary)),
                                        ]),
                                      ]),
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
                                onPressed: () => Navigator.pop(ctx, selectedPlan),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: Text(btnLabel, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15)),
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

