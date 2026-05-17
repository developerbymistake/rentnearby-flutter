import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/listing_controller.dart';
import '../utils/app_toast.dart';
import '../widgets/listing_card.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});
  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  final _ctrl = Get.find<ListingController>();
  final _auth = Get.find<AuthController>();
  final _scrollCtrl = ScrollController();
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _ctrl.loadMyListings(page: 1);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
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
      body: Column(
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
                    Obx(() => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${_ctrl.myListings.length} rooms',
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        )),
                    const SizedBox(width: 10),
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
                  padding: const EdgeInsets.all(16),
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
    );
  }

  void _onAddRoom() async {
    final name = _auth.user.value?.name?.trim() ?? '';
    if (name.isEmpty) {
      _showProfileRequiredDialog();
      return;
    }

    try {
      // Check if user can add more rooms based on membership
      final membership = await _ctrl.getMembershipStatus();

      if (membership != null) {
        final maxRooms = (membership['maxRooms'] as num?)?.toInt() ?? 0;
        final activeRooms = (membership['activeRooms'] as num?)?.toInt() ?? 0;

        if (activeRooms >= maxRooms) {
          AppToast.error('Room limit reached. You can add maximum $maxRooms room${maxRooms > 1 ? 's' : ''} with your plan.');
          return;
        }
      } else {
        // No membership - check if already has 1 free room
        final myRooms = _ctrl.myListings.length;
        if (myRooms >= 1) {
          AppToast.error('You have reached your free limit. Upgrade your plan to add more rooms.');
          return;
        }
      }

      Get.toNamed(AppRoutes.addListing);
    } catch (e) {
      // On error, allow user to try adding room anyway
      AppToast.info('Adding room...');
      Get.toNamed(AppRoutes.addListing);
    }
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
    final hasMembership = membership != null && (membership['hasMembership'] == true);

    // User has active membership — re-activate room directly, no payment needed
    if (hasMembership) {
      _activateFreePlanDirect(listingId);
      return;
    }

    if (!mounted) return;

    final planType = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PlanSelectionSheet(hasUsedFreePlan: hasUsedFree),
    );

    if (planType == null) return;

    await Get.toNamed(AppRoutes.paymentScreen, arguments: {
      'listingId': listingId,
      'planType': planType,
      'hasUsedFreePlan': hasUsedFree,
    });

    _refresh();
  }

  void _activateFreePlanDirect(String listingId) async {
    try {
      await _ctrl.toggleActive(listingId, false);
      AppToast.success('Room is now LIVE! 🎉');
    } catch (e) {
      AppToast.error('Could not activate: $e');
    }
  }

  void _showProfileRequiredDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          bool saving = false;

          Future<void> save() async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              AppToast.error('Please enter your name.');
              return;
            }
            setDialogState(() => saving = true);
            final ok = await _auth.updateProfile(name, null);
            setDialogState(() => saving = false);
            if (ok && ctx.mounted) {
              Navigator.pop(ctx);
              Get.toNamed(AppRoutes.addListing);
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
                  autofocus: true,
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
}

class _PlanSelectionSheet extends StatelessWidget {
  final bool hasUsedFreePlan;
  const _PlanSelectionSheet({required this.hasUsedFreePlan});

  @override
  Widget build(BuildContext context) {
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
          if (!hasUsedFreePlan) ...[
            _planTile(
              context,
              plan: 'FREE',
              title: 'Free Plan',
              subtitle: '2 days • 1 room',
              price: '₹0',
              icon: Icons.star_rounded,
              color: const Color(0xFF10B981),
            ),
            const SizedBox(height: 12),
          ],
          _planTile(
            context,
            plan: 'PAID',
            title: 'Premium Plan',
            subtitle: '30 days • 2 rooms',
            price: '₹99',
            icon: Icons.flash_on_rounded,
            color: AppColors.primary,
            isHighlighted: hasUsedFreePlan,
          ),
        ],
      ),
    );
  }

  Widget _planTile(
    BuildContext context, {
    required String plan,
    required String title,
    required String subtitle,
    required String price,
    required IconData icon,
    required Color color,
    bool isHighlighted = false,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, plan),
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
