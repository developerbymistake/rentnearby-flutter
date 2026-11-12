import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../../design/extra/taxi_setup_kit.dart';
import '../../../models/browse_item.dart';
import '../../../services/listing_share_service.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/notification_off_banner.dart';
import '../../../widgets/plan_cap_strip.dart';
import '../../stay/stay_strings_fin_c1.dart';
import '../leads/trip_leads_controller.dart';
import '../models/taxi_owner_model.dart';
import '../taxi_option_sets.dart';
import 'taxi_owner_card.dart';
import 'taxi_setup_controller.dart';

class MyTaxiScreen extends StatefulWidget {
  const MyTaxiScreen({super.key});
  @override
  State<MyTaxiScreen> createState() => _MyTaxiScreenState();
}

class _MyTaxiScreenState extends State<MyTaxiScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final _ctrl = TaxiSetupController.ensure();
  final _isSharing = false.obs;
  final _leads = TripLeadsController.ensure();
  late final AnimationController _anim = SetupKit.controller(this);
  bool _played = false;

  void _playOnce() {
    if (_played) return;
    _played = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SetupKit.play(_anim, context);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl.load();
    _leads.loadBadge(force: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _anim.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ctrl.load();
      _leads.loadBadge(force: true);
    }
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
      backgroundColor: FitnessAppTheme.background,
      body: Stack(children: [
        Column(children: [
          ModuleHeader(
            title: StayFinStrings.myTaxi,
            subtitle: StayFinStrings.manageListing,
            tone: KitTone.taxi,
            onBack: () => Get.back(),
          ),
          PlanCapStrip(accent: PickKit.taxi, icon: Icons.workspace_premium_rounded, showUsage: false),
          const NotificationOffBanner(),
          Expanded(
            child: Obx(() {
              final loading = _ctrl.isLoading.value;
              final loaded = _ctrl.hasLoaded.value;
              final failed = _ctrl.loadFailed.value;
              final taxi = _ctrl.taxi.value;
              if (!loaded && loading) return _skeleton();
              _playOnce();
              final items = <Widget>[
                if (failed && taxi == null)
                  _error()
                else if (taxi == null)
                  _empty()
                else ...[
                  Builder(builder: (ctx) => Obx(() => _card(ctx, taxi))),
                  if (!taxi.isPendingReview)
                    Center(
                      child: TextButton.icon(
                        onPressed: _openSetup,
                        icon: const Icon(Icons.edit_outlined, size: 16, color: FitnessAppTheme.nearlyDarkBlue),
                        label: Text(StayFinStrings.editSetup,
                            style: TripKit.text(14, weight: FontWeight.w600, color: FitnessAppTheme.nearlyDarkBlue)),
                      ),
                    ),
                ],
              ];
              return RefreshIndicator(
                color: FitnessAppTheme.nearlyDarkBlue,
                backgroundColor: FitnessAppTheme.white,
                onRefresh: _ctrl.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(KitMetrics.gutter, 16, KitMetrics.gutter, 16 + AppInsets.bottomViewPadding(context)),
                  children: [
                    for (var i = 0; i < items.length; i++)
                      SetupEntrance(controller: _anim, index: i, count: items.length, child: items[i]),
                  ],
                ),
              );
            }),
          ),
        ]),
        Obx(() => _ctrl.isSaving.value || _isSharing.value
            ? SetupBusy(message: _isSharing.value ? 'Sharing...' : 'Updating...')
            : const SizedBox.shrink()),
      ]),
    );
  }

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
        newLeads: _leads.newCount.value,
        onTripLeads: () async {
          await Get.toNamed(AppRoutes.tripLeads);
          if (mounted) _leads.loadBadge(force: true);
        },
        onLocalRate: _openSetup,
      );

  Widget _empty() => StateCard(
        asset: TravelIcon.taxi,
        title: StayFinStrings.noTaxiYet,
        message: StayFinStrings.listTaxiSteps,
        kit: KitTone.taxi,
        actionLabel: StayFinStrings.setUpTaxi,
        onAction: _openSetup,
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      );

  Widget _error() => StateCard.error(
        title: StayFinStrings.couldNotLoadTaxi,
        kit: KitTone.taxi,
        actionLabel: StayFinStrings.tryAgain,
        onAction: _ctrl.load,
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      );

  Widget _skeleton() => Padding(
        padding: const EdgeInsets.all(KitMetrics.gutter),
        child: OwnerListingCard.skeleton(margin: EdgeInsets.zero),
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
    final fare = await SetupKit.sheet<int>(
      context,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + AppInsets.bottomViewPadding(sheetCtx) + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SetupKit.grabber(),
          Text('Edit fare', style: TripKit.text(18, weight: FontWeight.w700).copyWith(letterSpacing: 0.27)),
          const SizedBox(height: 4),
          Text('${route.fromName} → ${route.toName} · ${TaxiOptionSets.tripLabel(route.tripType)}',
              maxLines: 2, overflow: TextOverflow.ellipsis, style: TripKit.text(12, color: FitnessAppTheme.grey)),
          const SizedBox(height: 12),
          TextField(
            controller: fareCtrl,
            autofocus: true,
            cursorColor: FitnessAppTheme.nearlyDarkBlue,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
            style: SetupKit.fieldText(),
            decoration: SetupKit.input(prefix: '₹ '),
          ),
          const SizedBox(height: 16),
          PickButton(
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
            gradient: PickKit.taxiGradient,
            shadowColor: PickKit.taxiDark,
          ),
        ]),
      ),
    ).whenComplete(() => fareCtrl.dispose());
    if (fare == null || fare == route.fare) return;
    final ok = await _ctrl.updateFare(route.id, fare);
    if (ok) AppToast.success('Fare updated');
  }

  Future<void> _confirmDelete() async {
    if (_ctrl.isSaving.value) return;
    final ok = await showTaxiDialog(
      context,
      title: 'Delete taxi?',
      body: 'Your taxi, routes and plate photo will be deleted.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok == true) _ctrl.deleteTaxi();
  }
}
