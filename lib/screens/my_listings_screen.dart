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
import '../widgets/payment_dialog.dart';

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
      floatingActionButton: FutureBuilder<Map<String, dynamic>?>(
        future: _ctrl.getMembershipStatus(),
        builder: (context, snapshot) {
          final membership = snapshot.data;

          // No membership = user can add 1 free room
          if (membership == null) {
            final activeRooms = _ctrl.myListings.length;
            // If already has 1 room and payment disabled, hide button
            if (activeRooms >= 1) {
              return const SizedBox.shrink();
            }
          } else {
            // Has membership, check room limit
            final maxRooms = (membership['maxRooms'] as num?)?.toInt() ?? 1;
            final activeRooms = (membership['activeRooms'] as num?)?.toInt() ?? 0;

            if (activeRooms >= maxRooms) {
              return const SizedBox.shrink();
            }
          }

          return Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ],
            ),
            child: FloatingActionButton.extended(
              onPressed: _onAddRoom,
              backgroundColor: Colors.transparent,
              elevation: 0,
              icon: const Icon(Iconsax.add_square, color: Colors.white),
              label: const Text('Add Room',
                  style: TextStyle(
                      fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          );
        },
      ),
    );
  }

  void _onAddRoom() async {
    final name = _auth.user.value?.name?.trim() ?? '';
    if (name.isEmpty) {
      _showProfileRequiredDialog();
      return;
    }

    // Check if user can add more rooms based on membership
    final membership = await _ctrl.getMembershipStatus();
    if (membership != null) {
      final maxRooms = (membership['maxRooms'] as num?)?.toInt() ?? 0;
      final activeRooms = (membership['activeRooms'] as num?)?.toInt() ?? 0;

      if (activeRooms >= maxRooms) {
        AppToast.error('Room limit reached. You can add maximum $maxRooms room${maxRooms > 1 ? 's' : ''} with your plan.');
        return;
      }
    }

    Get.toNamed(AppRoutes.addListing);
  }

  void _showPaymentDialog(String listingId) async {
    final isPaymentEnabled = await _ctrl.isPaymentFeatureEnabled();
    final hasUsedFree = _auth.user.value?.hasUsedFreePlan ?? false;

    // If payment not enabled and free plan available, activate directly
    if (!isPaymentEnabled && !hasUsedFree) {
      _activateFreePlanDirect(listingId);
      return;
    }

    // Show payment dialog normally
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => PaymentDialog(
        listingId: listingId,
        hasUsedFreePlan: hasUsedFree,
        onPaymentSuccess: () {
          _refresh();
        },
      ),
    );
  }

  void _activateFreePlanDirect(String listingId) async {
    try {
      AppToast.info('Activating your listing...');
      await _ctrl.activateFreePlan(listingId);
      _refresh();
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
