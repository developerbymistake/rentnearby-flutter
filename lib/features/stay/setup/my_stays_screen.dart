import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../models/browse_item.dart';
import '../../../services/listing_share_service.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/app_loading_overlay.dart';
import '../../../widgets/gradient_button.dart';
import '../models/stay_owner_model.dart';
import 'stay_option_sets.dart';
import 'stay_owner_card.dart';
import 'stay_setup_controller.dart';

class MyStaysScreen extends StatefulWidget {
  const MyStaysScreen({super.key});
  @override
  State<MyStaysScreen> createState() => _MyStaysScreenState();
}

class _MyStaysScreenState extends State<MyStaysScreen> with WidgetsBindingObserver {
  final _ctrl = StaySetupController.ensure();
  final _isSharing = false.obs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _ctrl.load();
  }

  Future<void> _openSetup() async {
    await Get.toNamed(AppRoutes.staySetup, arguments: {'fromMyStays': true});
    if (mounted) _ctrl.load();
  }

  Future<void> _share(BuildContext ctx, StayOwnerModel s) async {
    _isSharing.value = true;
    try {
      await shareListing(
        context: ctx,
        type: 's',
        slug: s.slug!,
        photoUrl: s.photos.isNotEmpty ? s.photos.first.url : null,
        priceOrArea: 'From ${BrowseItem.inr(s.minPricePerNight ?? 0)}/night',
        typeLabel: s.stayTypeName ?? 'Stay',
        locality: s.locality,
      );
    } finally {
      _isSharing.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() => AppLoadingOverlay(
            isLoading: _ctrl.isSaving.value || _isSharing.value,
            message: _isSharing.value ? 'Sharing...' : 'Updating...',
            child: Column(children: [
              _header(),
              Expanded(
                child: Obx(() {
                  final loading = _ctrl.isLoading.value;
                  final loaded = _ctrl.hasLoaded.value;
                  final stay = _ctrl.stay.value;
                  if (!loaded && loading) return _shimmer();
                  return RefreshIndicator(
                    color: StayColors.accent,
                    onRefresh: _ctrl.load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + AppInsets.bottomViewPadding(context)),
                      children: [
                        if (stay == null)
                          _empty()
                        else
                          Builder(builder: (ctx) => _card(ctx, stay)),
                      ],
                    ),
                  );
                }),
              ),
            ]),
          )),
    );
  }

  Widget _header() => Container(
        decoration: const BoxDecoration(gradient: StayColors.gradient),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 20, 20),
            child: Row(children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              ),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('My Stays',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Manage your listings',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white70)),
              ]),
            ]),
          ),
        ),
      );

  Widget _card(BuildContext ctx, StayOwnerModel s) => StayOwnerCard(
        stay: s,
        onAcceptingChanged: _setAccepting,
        onEditPrice: _editPrice,
        onPreview: () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': s.id}),
        onShare: s.isApproved && s.slug != null ? () => _share(ctx, s) : null,
        onDelete: _confirmDelete,
        onReportsTap: () => Get.toNamed(AppRoutes.listingReports, arguments: {
          'listingId': s.id,
          'listingType': 'Stay',
          'title': s.name ?? 'Stay',
        }),
        onOpenSetup: _openSetup,
      );

  Widget _empty() => Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(children: [
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(color: StayColors.surface, shape: BoxShape.circle),
            child: const Icon(Iconsax.building_4, size: 40, color: StayColors.accent),
          ),
          const SizedBox(height: 20),
          const Text('No stay yet',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          const Text('List your stay in 4 steps',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textLight)),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: GradientButton(
              onPressed: _openSetup,
              label: 'Set up your stay',
              gradient: StayColors.gradient,
              shadowColor: StayColors.accent,
            ),
          ),
        ]),
      );

  Widget _shimmer() => Padding(
        padding: const EdgeInsets.all(16),
        child: Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Container(
            height: 240,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );

  Future<void> _setAccepting(bool accepting) async {
    final ok = await _ctrl.setAccepting(accepting);
    if (ok) AppToast.success(accepting ? 'Accepting guests' : 'Paused');
  }

  Future<void> _editPrice(StayRoomModel room) async {
    final priceCtrl = TextEditingController(text: '${room.pricePerNight}');
    final price = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + AppInsets.bottomViewPadding(sheetCtx) + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Room ${room.roomIndex} price',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 4),
          const Text('Price per night',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          const SizedBox(height: 12),
          TextField(
            controller: priceCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: StayColors.accent, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          GradientButton(
            onPressed: () {
              final text = priceCtrl.text.trim();
              if (text.isEmpty) {
                AppToast.error('Please enter the price per night');
                return;
              }
              final v = int.tryParse(text) ?? 0;
              if (v <StayOptionSets.minPrice || v > StayOptionSets.maxPrice) {
                AppToast.error('Price per night must be between ₹100 and ₹99,00,000');
                return;
              }
              Navigator.pop(sheetCtx, v);
            },
            label: 'Save',
            gradient: StayColors.gradient,
            shadowColor: StayColors.accent,
          ),
        ]),
      ),
    ).whenComplete(() => priceCtrl.dispose());
    if (price == null || price == room.pricePerNight) return;
    final ok = await _ctrl.updateRoomPrice(room.id, price);
    if (ok) AppToast.success('Price updated');
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete stay?', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: const Text('Your stay and all its photos will be deleted.', style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _ctrl.deleteStay();
            },
            child: const Text('Delete', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }
}
