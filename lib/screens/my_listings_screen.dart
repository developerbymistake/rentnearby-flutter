import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
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

class _MyListingsScreenState extends State<MyListingsScreen> {
  final _ctrl = Get.find<ListingController>();
  final _auth = Get.find<AuthController>();
  final _scrollCtrl = ScrollController();
  Worker? _tabWorker;
  int _page = 1;
  late final _permissionService = ListingPermissionService(
    _ctrl,
    _auth,
    Get.find<LocationController>(),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.loadMyListings(page: 1);
    _scrollCtrl.addListener(_onScroll);
    _tabWorker = ever(_auth.tabIndex, (int idx) {
      if (idx == 1 && !_ctrl.isLoading.value) _refresh();
    });
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Row(
                  children: [
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('My Rooms',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      Text('Manage your listings',
                          style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 13, color: Colors.white70)),
                    ]),
                    const Spacer(),
                    GestureDetector(
                      onTap: _onAddRoom,
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
                        child: const Row(
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
    ListingPermissionResult result;
    try {
      result = await _permissionService.check();
    } catch (_) {
      AppToast.info('Adding room...');
      Get.toNamed(AppRoutes.addListing);
      return;
    }
    if (!mounted) return;
    switch (result) {
      case ListingAllowed():
        Get.toNamed(AppRoutes.addListing);
      case ListingNeedsDistrict():
        AppToast.error('Your area is not supported yet. Contact admin to expand coverage.');
      case ListingNeedsName():
        _showProfileRequiredDialog();
      case ListingNeedsPhoneVerification():
        _showPhoneVerificationRequired();
      case ListingShowLimitDialog():
        _showRoomLimitDialog(maxRooms: result.maxRooms, hasPlan: result.hasPlan);
      case ListingShowUpgradeSheet():
        _showPaidUpgradeSheet();
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

  void _showPaidUpgradeSheet({String listingId = ''}) async {
    final plans = await _ctrl.getPlans();
    final paidPlans = plans.values
        .where((p) => (p['originalPrice'] as num? ?? 0) > 0)
        .toList()
      ..sort((a, b) => (a['originalPrice'] as num? ?? 0).compareTo(b['originalPrice'] as num? ?? 0));

    if (!mounted) return;

    String? selectedType = paidPlans.isNotEmpty
        ? (paidPlans.first['planType'] as String? ?? '')
        : null;

    const golden = Color(0xFFD4A017);
    final screenH = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final selectedPlan = paidPlans.isNotEmpty
              ? paidPlans.firstWhere((p) => p['planType'] == selectedType, orElse: () => paidPlans.first)
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
                            child: paidPlans.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text('No plans available.', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight), textAlign: TextAlign.center),
                                  )
                                : Column(
                                    children: paidPlans.map((p) {
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
                // Logo circle (overlapping top)
                Positioned(
                  top: 0,
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: const Center(
                      child: Text('B', style: TextStyle(fontFamily: 'Poppins', fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
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
    // If admin disabled payment feature, skip plan popup and activate FREE directly
    final paymentEnabled = await _ctrl.isPaymentFeatureEnabled();
    if (!paymentEnabled) {
      _activateFreePlanDirect(listingId);
      return;
    }

    final hasUsedFree = _auth.user.value?.hasUsedFreePlan ?? false;
    final membership = await _ctrl.getMembershipStatus();
    final plans = await _ctrl.getPlans();
    final hasMembership = membership != null && (membership['hasMembership'] == true);

    if (hasMembership) {
      final maxRooms = (membership['maxRooms'] as num?)?.toInt() ?? 0;
      final activeRooms = (membership['activeRooms'] as num?)?.toInt() ?? 0;
      final membershipPlanType = membership['planType'] as String? ?? '';

      // Route by price: if current plan is free (originalPrice=0) and at capacity → upgrade to paid
      final currentPlan = plans[membershipPlanType];
      final currentPlanIsFree = currentPlan == null || (currentPlan['originalPrice'] as num? ?? 0) == 0;

      if (activeRooms >= maxRooms && currentPlanIsFree) {
        // At capacity on free plan → show upgrade dialog with paid plans
        _showPaidUpgradeSheet(listingId: listingId);
        return;
      }

      // Has remaining capacity → activate directly (free/no extra charge)
      _activateFreePlanDirect(listingId);
      return;
    }

    if (hasUsedFree) {
      if (mounted) _showPaidUpgradeSheet(listingId: listingId);
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
      try {
        await _ctrl.activatePlan(listingId, selectedPlanType);
        await _ctrl.loadMyListings();
      } catch (e) {
        AppToast.error('Could not activate plan: $e');
        return;
      }
      if (!mounted) return;
      Get.dialog(
        PaymentSuccessDialog(
          planType: selectedPlanType,
          daysValid: (selectedPlan['days'] as num?)?.toInt() ?? 2,
          maxRooms: (selectedPlan['roomLimit'] as num?)?.toInt() ?? 1,
          originalPrice: (selectedPlan['originalPrice'] as num?)?.toInt() ?? 0,
          onDismiss: () {
            Get.find<AuthController>().tabIndex.value = 1;
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
  }

  void _activateFreePlanDirect(String listingId) async {
    await _ctrl.toggleActive(listingId, false);
  }

  void _showPhoneVerificationRequired() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.phone_android_rounded, color: AppColors.warning, size: 28),
          ),
          const SizedBox(height: 16),
          const Text('Mobile verification required',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 8),
          const Text('You need to verify your mobile number before posting a room.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.5)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Get.find<AuthController>().tabIndex.value = 4;
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Go to Profile', style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  void _showProfileRequiredDialog() {
    final nameCtrl = TextEditingController();
    bool saving = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> save() async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              AppToast.error('Please enter your name.');
              return;
            }
            setDialogState(() => saving = true);
            final ok = await _auth.updateProfile(name);
            if (ok) {
              if (ctx.mounted) { Navigator.pop(ctx); Get.toNamed(AppRoutes.addListing); }
            } else {
              setDialogState(() => saving = false);
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Enter Your Name',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your name is shown to renters. Please add it before listing a room.',
                  style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Full name',
                    hintStyle: const TextStyle(
                        fontFamily: 'Poppins', color: AppColors.textHint),
                    prefixIcon: const Icon(Icons.person_rounded,
                        color: AppColors.primaryLight, size: 20),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.divider)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.divider)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.primary, width: 1.5)),
                  ),
                  onSubmitted: (_) => save(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () {
                        nameCtrl.dispose();
                        Navigator.pop(ctx);
                      },
                child: const Text('Later',
                    style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: saving ? null : save,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Update Profile',
                        style: TextStyle(
                            fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
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

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Listing',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: const Text('Are you sure? This will also delete all photos.',
            style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(
                      fontFamily: 'Poppins', color: AppColors.textLight))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            onPressed: () {
              Navigator.pop(context);
              _ctrl.deleteListing(id);
            },
            child: const Text('Delete', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
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
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Center(child: Image.asset('assets/images/app_logo.png', width: 44, height: 44, fit: BoxFit.contain)),
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

class _PlanSelectionSheet extends StatelessWidget {
  final bool hasUsedFreePlan;
  final Map<String, Map<String, dynamic>> plans;
  const _PlanSelectionSheet({required this.hasUsedFreePlan, required this.plans});

  String _label(Map<String, dynamic> p) {
    final raw = (p['planType'] as String? ?? '');
    if (raw.isEmpty) return '';
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final freePlans = plans.values
        .where((p) => (p['originalPrice'] as num? ?? 0) == 0)
        .toList();
    final paidPlans = plans.values
        .where((p) => (p['originalPrice'] as num? ?? 0) > 0)
        .toList()
      ..sort((a, b) => (a['originalPrice'] as num).compareTo(b['originalPrice'] as num));

    final tiles = <Widget>[];

    if (!hasUsedFreePlan) {
      for (final p in freePlans) {
        final days = (p['days'] as num?)?.toInt() ?? 2;
        final rooms = (p['roomLimit'] as num?)?.toInt() ?? 1;
        tiles.add(_planTile(
          context,
          planType: p['planType'] as String,
          title: '${_label(p)} Plan',
          subtitle: '$days days • $rooms room${rooms > 1 ? 's' : ''}',
          price: 'Free',
          icon: Icons.star_rounded,
          color: const Color(0xFF10B981),
        ));
        tiles.add(const SizedBox(height: 12));
      }
    }

    for (int i = 0; i < paidPlans.length; i++) {
      final p = paidPlans[i];
      final days = (p['days'] as num?)?.toInt() ?? 30;
      final rooms = (p['roomLimit'] as num?)?.toInt() ?? 2;
      final origPrice = (p['originalPrice'] as num?)?.toInt() ?? 0;
      tiles.add(_planTile(
        context,
        planType: p['planType'] as String,
        title: '${_label(p)} Plan',
        subtitle: '$days days • $rooms rooms',
        price: origPrice == 0 ? 'FREE' : '₹$origPrice',
        icon: Icons.flash_on_rounded,
        color: AppColors.primary,
        isHighlighted: hasUsedFreePlan && i == 0,
      ));
      if (i < paidPlans.length - 1) tiles.add(const SizedBox(height: 12));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Make Room Live',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
          const SizedBox(height: 4),
          Text('Choose a plan to activate your listing',
              style: TextStyle(fontSize: 13, color: Colors.grey[600], fontFamily: 'Poppins')),
          const SizedBox(height: 20),
          ...tiles,
        ],
      ),
    );
  }

  Widget _planTile(
    BuildContext context, {
    required String planType,
    required String title,
    required String subtitle,
    required String price,
    required IconData icon,
    required Color color,
    bool isHighlighted = false,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, planType),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isHighlighted ? color : color.withValues(alpha: 0.3),
            width: isHighlighted ? 2 : 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isHighlighted ? color.withValues(alpha: 0.05) : Colors.grey[50],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600], fontFamily: 'Poppins')),
                ],
              ),
            ),
            Text(price,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: color, fontFamily: 'Poppins')),
          ],
        ),
      ),
    );
  }
}
