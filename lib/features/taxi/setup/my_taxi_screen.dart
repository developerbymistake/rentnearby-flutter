import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_taxi_owner.dart';
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
  static final ListingTone _tone = ListingTone.coral;
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
    _anim.value = 0;
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
      backgroundColor: ListingPalette.coral.page,
      body: Stack(children: [
        KitStatusBar(
          lightIcons: false,
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              PageHeader3D(
                tone: _tone,
                title: StayFinStrings.myTaxi,
                subtitle: StayFinStrings.manageListing,
                art: ListingArt.taxi,
                inlineTitle: true,
                onBack: () => Get.back(),
              ),
              PlanCapStrip(accent: PickKit.taxi, icon: Icons.workspace_premium_rounded, iconAsset: ListingArt.moneyBag, showUsage: false),
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
                        Padding(
                          padding: const EdgeInsets.only(top: 22),
                          child: Center(
                            child: WhitePillButton(
                              tone: _tone,
                              label: StayFinStrings.editSetup,
                              icon: Icons.edit_rounded,
                              expand: false,
                              height: 48,
                              fontSize: 14.5,
                              onTap: _openSetup,
                            ),
                          ),
                        ),
                    ],
                  ];
                  return RefreshIndicator(
                    color: _tone.button,
                    backgroundColor: FitnessAppTheme.white,
                    onRefresh: _ctrl.load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(0, 0, 0, 24 + MediaQuery.paddingOf(context).bottom),
                      children: [
                        for (var i = 0; i < items.length; i++)
                          SetupEntrance(controller: _anim, index: i, count: items.length, child: items[i]),
                      ],
                    ),
                  );
                }),
              ),
            ]),
          ),
        ),
        Obx(() => _ctrl.isSaving.value || _isSharing.value
            ? SetupBusy(message: _isSharing.value ? 'Sharing...' : 'Updating...', tone: KitTone.taxi, art: ListingArt.taxi)
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

  Widget _empty() => TaxiEmptyCard3D(
        tone: _tone,
        art: ListingArt.taxi,
        title: StayFinStrings.noTaxiYet,
        message: StayFinStrings.listTaxiSteps,
        actionLabel: StayFinStrings.setUpTaxi,
        onAction: _openSetup,
      );

  Widget _error() => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: StateCard3D(
          tone: _tone,
          art: ListingArt.clipboard,
          title: StayFinStrings.couldNotLoadTaxi,
          actionLabel: StayFinStrings.tryAgain,
          onAction: _ctrl.load,
          layout: StateLayout.tall,
        ),
      );

  Widget _skeleton() => const Padding(
        padding: EdgeInsets.fromLTRB(18, 24, 18, 0),
        child: SkeletonFormCard(height: 420),
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
    var ring = false;
    final fare = await Sheet3D.show<int>(
      context,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Sheet3D(
          tone: _tone,
          art: ListingArt.moneyBag,
          title: 'Edit fare',
          subtitle: '${route.fromName} → ${route.toName} · ${TaxiOptionSets.tripLabel(route.tripType)}',
          centerTitle: false,
          artRight: true,
          footer: GradientPillButton(
            tone: _tone,
            label: 'Save',
            onTap: () {
              final text = fareCtrl.text.trim();
              if (text.isEmpty) {
                AppToast.error('Enter the fare');
                setSheet(() => ring = true);
                return;
              }
              final v = int.tryParse(text) ?? 0;
              if (v < TaxiOptionSets.minFare || v > TaxiOptionSets.maxFare) {
                AppToast.error('Fare must be between ₹100 and ₹99,00,000');
                setSheet(() => ring = true);
                return;
              }
              Navigator.pop(sheetCtx, v);
            },
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 8),
            PillField(
              tone: _tone,
              controller: fareCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
              prefixText: '₹',
              hint: 'e.g. 4500',
              errorRing: ring,
              onChanged: (_) {
                if (ring) setSheet(() => ring = false);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
              child: Text('Change it if the plan needs more.\nTravellers see this fare on your taxi.', style: FieldMessage.helperStyle.copyWith(fontSize: 12)),
            ),
          ]),
        ),
      ),
    ).whenComplete(() => fareCtrl.dispose());
    if (fare == null || fare == route.fare) return;
    final ok = await _ctrl.updateFare(route.id, fare);
    if (ok) AppToast.success('Fare updated');
  }

  Future<void> _confirmDelete() async {
    if (_ctrl.isSaving.value) return;
    final ok = await showTaxiOwnerDialog(
      context,
      art: ListingArt.taxi,
      title: 'Delete taxi?',
      body: 'Your taxi, routes and plate photo will be deleted.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok == true) _ctrl.deleteTaxi();
  }
}
