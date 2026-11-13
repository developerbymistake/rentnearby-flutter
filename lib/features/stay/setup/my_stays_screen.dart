import 'dart:math' as math;

import 'stay_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_stay_owner.dart';
import '../../../models/browse_item.dart';
import '../../../services/listing_share_service.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/notification_off_banner.dart';
import '../../../widgets/plan_cap_strip.dart';
import '../../trip/trip_strings.dart';
import '../enquiries/stay_enquiries_controller.dart';
import '../models/stay_owner_model.dart';
import '../stay_strings_fin_c1.dart';
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
  final _enquiries = StayEnquiriesController.ensure();
  final _isSharing = false.obs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    await _ctrl.load();
    final stay = _ctrl.stay.value;
    if (mounted && stay != null && !stay.isDraft) _enquiries.loadBadge();
  }

  Future<void> _openEnquiries() async {
    await Get.toNamed(AppRoutes.stayEnquiries);
    if (mounted) _enquiries.loadBadge();
  }

  Future<void> _openSetup() async {
    await Get.toNamed(AppRoutes.staySetup, arguments: {'fromMyStays': true});
    if (mounted) _load();
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

  static final _tone = ListingTone.forest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ListingPalette.forest.page,
      body: Stack(children: [
        Column(children: [
          StayPageHeader(
            title: StayFinStrings.myStays,
            subtitle: StayFinStrings.manageListings,
            onBack: () => Get.back(),
            asset: SetupAssets.hotel,
          ),
          Expanded(
            child: Obx(() {
              final loading = _ctrl.isLoading.value;
              final loaded = _ctrl.hasLoaded.value;
              final stay = _ctrl.stay.value;
              final failed = _ctrl.loadFailed.value;
              if (!loaded && loading) return _skeleton();
              return RefreshIndicator(
                color: _tone.g2,
                backgroundColor: DesignColors.surface,
                onRefresh: _load,
                child: LayoutBuilder(
                  builder: (context, box) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: EdgeInsets.only(bottom: 16 + MediaQuery.viewPaddingOf(context).bottom),
                    children: [
                      PlanCapStrip(accent: PickKit.stay, icon: Icons.workspace_premium_rounded, showUsage: false),
                      const NotificationOffBanner(),
                      failed && stay == null
                          ? _stateCard(
                              box,
                              art: ListingArt.compass,
                              title: TripStrings.couldNotLoad,
                              message: TripStrings.checkConnection,
                              action: TripStrings.retry,
                              onAction: _load,
                            )
                          : stay == null
                              ? _stateCard(
                                  box,
                                  art: ListingArt.hotel,
                                  title: StayFinStrings.noStayYet,
                                  message: StayFinStrings.listStaySteps,
                                  action: StayFinStrings.setUpStay,
                                  onAction: _openSetup,
                                )
                              : Builder(builder: (ctx) => _card(ctx, stay)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ]),
        Obx(() => _ctrl.isSaving.value || _isSharing.value
            ? StayBusy(message: _isSharing.value ? 'Sharing...' : 'Updating...')
            : const SizedBox.shrink()),
      ]),
    );
  }

  Widget _stateCard(BoxConstraints box, {required String art, required String title, required String message, required String action, required VoidCallback onAction}) =>
      StateCard3D(
        tone: _tone,
        layout: StateLayout.tall,
        art: art,
        title: title,
        message: message,
        actionLabel: action,
        onAction: onAction,
        minHeight: math.max(300, box.maxHeight - 330),
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
        onEnquiries: _openEnquiries,
        enquiryNewCount: _enquiries.newCount,
      );

  Widget _skeleton() => ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 26, 18, 0),
            child: ClipRRect(borderRadius: StayOwnerShapes.card68, child: const SkeletonBox(height: 98, radius: 0)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 30, 14, 0),
            child: ClipRRect(borderRadius: StayOwnerShapes.card54, child: const SkeletonBox(height: 560, radius: 0)),
          ),
        ],
      );

  Future<void> _setAccepting(bool accepting) async {
    final ok = await _ctrl.setAccepting(accepting);
    if (ok) AppToast.success(accepting ? 'Accepting guests' : 'Paused');
  }

  Future<void> _editPrice(StayRoomModel room) async {
    final priceCtrl = TextEditingController(text: '${room.pricePerNight}');
    final price = await Sheet3D.show<int>(
      context,
      builder: (sheetCtx) => Sheet3D(
        tone: _tone,
        art: ListingArt.moneyBag,
        title: '${room.label} price',
        subtitle: 'Price per night',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 6),
          PillField(
            tone: _tone,
            controller: priceCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
            prefixText: '₹',
            hint: 'e.g. 1500',
          ),
          const SizedBox(height: 16),
          GradientPillButton(
            tone: _tone,
            label: 'Save',
            onTap: () {
              final text = priceCtrl.text.trim();
              if (text.isEmpty) {
                AppToast.error('Please enter the price per night');
                return;
              }
              final v = int.tryParse(text) ?? 0;
              if (v < StayOptionSets.minPrice || v > StayOptionSets.maxPrice) {
                AppToast.error('Price per night must be between ₹100 and ₹99,00,000');
                return;
              }
              Navigator.pop(sheetCtx, v);
            },
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
      builder: (ctx) => StayConfirmDialog(
        title: StayFinStrings.deleteStayTitle,
        body: StayFinStrings.deleteStayBody,
        cancelLabel: StayFinStrings.cancel,
        confirmLabel: StayFinStrings.delete,
        destructive: true,
        art: ListingArt.hotel,
        onCancel: () => Navigator.pop(ctx),
        onConfirm: () {
          Navigator.pop(ctx);
          _ctrl.deleteStay();
        },
      ),
    );
  }
}
