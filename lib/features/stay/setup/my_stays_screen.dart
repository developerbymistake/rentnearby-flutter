import 'stay_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../design/design.dart';
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

class _MyStaysScreenState extends State<MyStaysScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final _ctrl = StaySetupController.ensure();
  final _enquiries = StayEnquiriesController.ensure();
  final _isSharing = false.obs;
  late final AnimationController _anim = SetupKit.controller(this);
  bool _played = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _anim.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  void _playOnce() {
    if (_played) return;
    _played = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SetupKit.play(_anim, context);
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Stack(children: [
        Column(children: [
          StayPageHeader(
            title: StayFinStrings.myStays,
            subtitle: StayFinStrings.manageListings,
            onBack: () => Get.back(),
            asset: SetupAssets.hotel,
            animation: templateInterval(_anim, 0, 2),
          ),
          PlanCapStrip(accent: PickKit.stay, icon: Icons.workspace_premium_rounded, showUsage: false),
          const NotificationOffBanner(),
          Expanded(
            child: Obx(() {
              final loading = _ctrl.isLoading.value;
              final loaded = _ctrl.hasLoaded.value;
              final stay = _ctrl.stay.value;
              final failed = _ctrl.loadFailed.value;
              if (!loaded && loading) return _skeleton();
              _playOnce();
              return RefreshIndicator(
                color: DesignColors.primary,
                backgroundColor: DesignColors.surface,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: EdgeInsets.fromLTRB(KitMetrics.gutter, 16, KitMetrics.gutter, 16 + MediaQuery.viewPaddingOf(context).bottom),
                  children: [
                    SetupEntrance(
                      controller: _anim,
                      index: 0,
                      count: 1,
                      child: failed && stay == null
                          ? StateCard.error(
                              kit: KitTone.stay,
                              title: TripStrings.couldNotLoad,
                              message: TripStrings.checkConnection,
                              actionLabel: TripStrings.retry,
                              onAction: _load,
                            )
                          : stay == null
                              ? _empty()
                              : Builder(builder: (ctx) => _card(ctx, stay)),
                    ),
                  ],
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

  Widget _empty() => StateCard(
        kit: KitTone.stay,
        asset: TravelIcon.stay,
        title: StayFinStrings.noStayYet,
        message: StayFinStrings.listStaySteps,
        actionLabel: StayFinStrings.setUpStay,
        onAction: _openSetup,
      );

  Widget _skeleton() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 16),
        child: OwnerListingCard.skeleton(margin: EdgeInsets.zero),
      );

  Future<void> _setAccepting(bool accepting) async {
    final ok = await _ctrl.setAccepting(accepting);
    if (ok) AppToast.success(accepting ? 'Accepting guests' : 'Paused');
  }

  Future<void> _editPrice(StayRoomModel room) async {
    final priceCtrl = TextEditingController(text: '${room.pricePerNight}');
    final price = await SheetFrame.show<int>(
      context,
      builder: (sheetCtx) => SheetFrame(
        title: '${room.label} price',
        subtitle: 'Price per night',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: priceCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
            cursorColor: DesignColors.primary,
            style: SetupKit.fieldText(),
            decoration: SetupKit.input(prefix: '₹ '),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            tone: KitTone.stay,
            label: 'Save',
            onPressed: () {
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
        onCancel: () => Navigator.pop(ctx),
        onConfirm: () {
          Navigator.pop(ctx);
          _ctrl.deleteStay();
        },
      ),
    );
  }
}
