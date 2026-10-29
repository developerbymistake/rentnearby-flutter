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
import '../../../widgets/plan_cap_strip.dart';
import '../../../widgets/gradient_button.dart';
import '../models/taxi_owner_model.dart';
import '../taxi_option_sets.dart';
import 'taxi_owner_card.dart';
import 'taxi_setup_controller.dart';

class MyTaxiScreen extends StatefulWidget {
  const MyTaxiScreen({super.key});
  @override
  State<MyTaxiScreen> createState() => _MyTaxiScreenState();
}

class _MyTaxiScreenState extends State<MyTaxiScreen> with WidgetsBindingObserver {
  final _ctrl = TaxiSetupController.ensure();
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
    if (_ctrl.isSaving.value) return;
    await Get.toNamed(AppRoutes.taxiSetup, arguments: {'fromMyTaxi': true});
    if (mounted) _ctrl.load();
  }

  Future<void> _share(BuildContext ctx, TaxiOwnerModel t) async {
    if (_isSharing.value) return;
    _isSharing.value = true;
    try {
      await shareListing(
        context: ctx,
        type: 't',
        slug: t.slug!,
        photoUrl: t.platePhotoUrl,
        priceOrArea: 'From ${BrowseItem.inr(t.minFare ?? 0)}',
        typeLabel: t.vehicleTypeName ?? 'Taxi',
        locality: t.locality,
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
            indicatorColor: TaxiColors.accent,
            child: Column(children: [
              _header(),
              PlanCapStrip(accent: TaxiColors.accent, icon: Icons.workspace_premium_rounded, showUsage: false),
              Expanded(
                child: Obx(() {
                  final loading = _ctrl.isLoading.value;
                  final loaded = _ctrl.hasLoaded.value;
                  final failed = _ctrl.loadFailed.value;
                  final taxi = _ctrl.taxi.value;
                  if (!loaded && loading) return _shimmer();
                  return RefreshIndicator(
                    color: TaxiColors.accent,
                    onRefresh: _ctrl.load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + AppInsets.bottomViewPadding(context)),
                      children: [
                        if (failed && taxi == null)
                          _error()
                        else if (taxi == null)
                          _empty()
                        else ...[
                          Builder(builder: (ctx) => _card(ctx, taxi)),
                          if (!taxi.isPendingReview)
                            Center(
                              child: TextButton.icon(
                                onPressed: _openSetup,
                                icon: const Icon(Iconsax.edit_2, size: 16, color: TaxiColors.accentDark),
                                label: const Text('Edit setup',
                                    style: TextStyle(
                                        fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: TaxiColors.accentDark)),
                              ),
                            ),
                        ],
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
        decoration: const BoxDecoration(gradient: TaxiColors.gradient),
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
                Text('My Taxi',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Manage your listing', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white70)),
              ]),
            ]),
          ),
        ),
      );

  Widget _card(BuildContext ctx, TaxiOwnerModel t) => TaxiOwnerCard(
        taxi: t,
        onAvailableChanged: _setAvailable,
        onAvailableLocked: () =>
            AppToast.info(t.isPendingReview ? 'Your taxi is under review' : 'Your taxi is not live yet.'),
        onEditFare: _editFare,
        onPreview: () => Get.toNamed(AppRoutes.taxiDetail, arguments: {'id': t.id}),
        onShare: t.isApproved && t.slug != null ? () => _share(ctx, t) : null,
        onDelete: _confirmDelete,
        onReportsTap: () => Get.toNamed(AppRoutes.listingReports, arguments: {
          'listingId': t.id,
          'listingType': 'Taxi',
          'title': t.plateDisplay ?? 'Taxi',
        }),
        onOpenSetup: _openSetup,
      );

  Widget _empty() => Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(children: [
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(color: TaxiColors.surface, shape: BoxShape.circle),
            child: const Icon(Iconsax.car, size: 40, color: TaxiColors.accent),
          ),
          const SizedBox(height: 20),
          const Text('No taxi yet',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          const Text('List your taxi in 3 steps', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textLight)),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: GradientButton(
              onPressed: _openSetup,
              label: 'Set up your taxi',
              gradient: TaxiColors.gradient,
              shadowColor: TaxiColors.accent,
            ),
          ),
        ]),
      );

  Widget _error() => Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(children: [
          const Text("Couldn't load your taxi",
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium)),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _ctrl.load,
            child: const Text('Try again',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: TaxiColors.accentDark)),
          ),
        ]),
      );

  Widget _shimmer() => Padding(
        padding: const EdgeInsets.all(16),
        child: Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Container(
            height: 260,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );

  Future<void> _setAvailable(bool available) async {
    final ok = await _ctrl.setAvailable(available);
    if (ok) AppToast.success(available ? 'Available now' : 'Hidden from search');
  }

  Future<void> _editFare(TaxiRouteModel route) async {
    if (_ctrl.taxi.value?.isPendingReview ?? false) {
      AppToast.info('Your taxi is under review');
      return;
    }
    if (_ctrl.isSaving.value) return;
    final fareCtrl = TextEditingController(text: '${route.fare}');
    final fare = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + AppInsets.bottomViewPadding(sheetCtx) + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text('Edit fare',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text('${route.fromName} → ${route.toName} · ${TaxiOptionSets.tripLabel(route.tripType)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          const SizedBox(height: 12),
          TextField(
            controller: fareCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle:
                  const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500),
              filled: true,
              fillColor: TaxiColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TaxiColors.accent, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          GradientButton(
            onPressed: () {
              final text = fareCtrl.text.trim();
              if (text.isEmpty) {
                AppToast.error('Enter the fare');
                return;
              }
              final v = int.tryParse(text) ?? 0;
              if (v < TaxiOptionSets.minFare || v > TaxiOptionSets.maxFare) {
                AppToast.error('Fare must be between ₹100 and ₹99,00,000');
                return;
              }
              Navigator.pop(sheetCtx, v);
            },
            label: 'Save',
            gradient: TaxiColors.gradient,
            shadowColor: TaxiColors.accent,
          ),
        ]),
      ),
    ).whenComplete(() => fareCtrl.dispose());
    if (fare == null || fare == route.fare) return;
    final ok = await _ctrl.updateFare(route.id, fare);
    if (ok) AppToast.success('Fare updated');
  }

  void _confirmDelete() {
    if (_ctrl.isSaving.value) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete taxi?', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: const Text('Your taxi, routes and plate photo will be deleted.', style: TextStyle(fontFamily: 'Poppins')),
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
              _ctrl.deleteTaxi();
            },
            child: const Text('Delete', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }
}
