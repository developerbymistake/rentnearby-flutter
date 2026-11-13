import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/location_controller.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_stay_owner.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/global_location_gates.dart';
import '../../trip/trip_strings.dart';
import '../models/stay_owner_model.dart';
import 'stay_option_sets.dart';
import 'stay_setup_controller.dart';
import 'stay_step_row.dart';

class StaySetupHubScreen extends StatefulWidget {
  const StaySetupHubScreen({super.key});
  @override
  State<StaySetupHubScreen> createState() => _StaySetupHubScreenState();
}

class _StaySetupHubScreenState extends State<StaySetupHubScreen> {
  final _ctrl = StaySetupController.ensure();
  final _auth = Get.find<AuthController>();
  late final bool _fromMyStays;
  static final _tone = ListingTone.forest;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    _fromMyStays = args is Map && args['fromMyStays'] == true;
    _ctrl.mainBelow = _fromMyStays;
    // Gated owners never build MainScreen; permanent so its later Get.put reuses this instance.
    if (!Get.isRegistered<LocationController>()) {
      Get.put(LocationController(), permanent: true);
      GlobalLocationGates.notifyReady();
    }
    _load();
  }

  Future<void> _load() async {
    final ok = await _ctrl.load();
    if (!ok && mounted && !_auth.staysEnabled) {
      _auth.leaveOffTabRoute();
      return;
    }
    final s = _ctrl.stay.value;
    if (!ok || !mounted || _fromMyStays) return;
    if (s == null || s.isDraft) {
      _auth.refreshProfile();
      return;
    }
    await _auth.refreshProfile();
    Get.offAllNamed(AppRoutes.main);
  }

  bool get _gated {
    if (_fromMyStays) return false;
    final status = _ctrl.stay.value?.status ?? _auth.user.value?.stayStatus;
    return status == null || status == StayStatus.draft;
  }

  Future<void> _open(String route) async {
    final s = _ctrl.stay.value;
    if (s != null && !s.canEditSetup) {
      AppToast.info(s.isPendingReview ? 'Your stay is under review' : 'Your stay is live');
      return;
    }
    await Get.toNamed(route);
    if (mounted) _ctrl.load();
  }

  Future<void> _openAdvance() async {
    await Get.toNamed(AppRoutes.stayAdvanceDetails);
    if (mounted) _ctrl.load();
  }

  void _openMenu(bool canCorrect) {
    final top = MediaQuery.paddingOf(context).top + 8;
    showMenu3D(
      context,
      anchor: Rect.fromLTWH(18, top, PageHeader3D.buttonSize, PageHeader3D.buttonSize),
      items: [
        if (!canCorrect) MenuItem3D(label: 'Change role', onTap: () => Get.toNamed(AppRoutes.roleChange)),
        MenuItem3D(label: 'Log out', danger: true, onTap: _auth.logout),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final gated = _gated;
      final stay = _ctrl.stay.value;
      final canCorrect = gated && (stay == null || stay.isDraft) && (_auth.user.value?.canCorrectRole ?? false);
      final loading = _ctrl.isLoading.value;
      final loaded = _ctrl.hasLoaded.value;
      final failed = _ctrl.loadFailed.value;
      final showSkeleton = !loaded && loading;
      return PopScope(
        canPop: !gated,
        child: Scaffold(
          backgroundColor: ListingPalette.forest.page,
          body: Column(children: [
            SafeArea(
              bottom: false,
              child: PageHeader3D(
                tone: _tone,
                title: 'Set up your stay',
                art: SetupAssets.hotel,
                artSize: 100,
                onBack: gated ? null : () => Get.back(),
                leadingIcon: gated ? Icons.more_vert_rounded : null,
                onLeading: gated ? () => _openMenu(canCorrect) : null,
                leadingSemantics: 'Menu',
              ),
            ),
            Expanded(
              child: showSkeleton
                  ? _skeleton()
                  : failed
                      ? _error()
                      : RefreshIndicator(
                          color: _tone.g2,
                          backgroundColor: DesignColors.surface,
                          onRefresh: _ctrl.load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: EdgeInsets.only(bottom: 28 + MediaQuery.viewPaddingOf(context).bottom),
                            children: _content(stay, gated),
                          ),
                        ),
            ),
          ]),
        ),
      );
    });
  }

  Widget _error() => LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: StateCard3D(
            tone: _tone,
            layout: StateLayout.tall,
            art: ListingArt.compass,
            title: "Couldn't load your stay",
            actionLabel: 'Try again',
            onAction: _ctrl.load,
            minHeight: math.max(300, box.maxHeight - 160),
          ),
        ),
      );

  Widget _skeleton() => ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 48, 18, 0),
            child: ClipRRect(borderRadius: StayOwnerShapes.card68, child: const SkeletonBox(height: 182, radius: 0)),
          ),
          for (var i = 0; i < 4; i++) const SkeletonSlimCard(),
        ],
      );

  List<Widget> _content(StayOwnerModel? s, bool gated) {
    final d1 = s?.step1Done ?? false;
    final regMissing = d1 && (s?.canEditSetup ?? true) && !(s?.registrationDone ?? false);
    final u2 = d1;
    final d2 = u2 && (s?.roomsDone ?? false);
    final u3 = d2;
    final d3 = u3 && (s?.rulesDone ?? false);
    final u4 = d3 && !regMissing;
    final d4 = u4 && (s != null && (s.isPendingReview || s.isApproved));
    final percent = s?.setupPercent ?? 0;
    final canCorrect = gated && (s == null || s.isDraft) && (_auth.user.value?.canCorrectRole ?? false);

    StayStepState state(bool unlocked, bool done) =>
        !unlocked ? StayStepState.locked : (done ? StayStepState.done : StayStepState.current);

    return [
      if (s != null && s.isRejected) _rejectedStrip(s),
      if (s != null && s.isPendingReview) _pendingStrip(),
      if (regMissing) _registrationStrip(),
      _scoreCard(percent),
      if (canCorrect) _wrongRoleLink(percent),
      StayStepRow(
        number: 1,
        title: 'Basic details',
        subtitle: regMissing
            ? 'Add registration details'
            : d1
                ? StayOptionSets.basicSummary(s!)
                : 'Details, registration, location, photos',
        accent: PickKit.stay,
        asset: SetupAssets.hotel,
        state: state(true, d1 && !regMissing),
        onTap: () => _open(AppRoutes.stayBasicDetails),
      ),
      StayStepRow(
        number: 2,
        title: 'Rooms',
        subtitle: !u2 ? 'Complete step 1 first' : d2 ? StayOptionSets.roomsSummary(s!) : 'Add rooms, up to 2',
        accent: PickKit.stay,
        asset: SetupAssets.bed,
        state: state(u2, d2),
        onTap: () => _open(AppRoutes.stayRooms),
      ),
      StayStepRow(
        number: 3,
        title: 'Rules',
        subtitle: !u3
            ? 'Complete step 2 first'
            : d3
                ? StayOptionSets.rulesSummary(s!)
                : 'Check-in, house rules, cancellation',
        accent: PickKit.stay,
        asset: SetupAssets.clipboard,
        state: state(u3, d3),
        onTap: () => _open(AppRoutes.stayRules),
      ),
      StayStepRow(
        number: 4,
        title: 'Final submit',
        subtitle: !u4
            ? (d3 ? 'Complete step 1 first' : 'Complete step 3 first')
            : s!.isApproved
                ? 'Your stay is live'
                : d4
                    ? 'Submitted for review'
                    : 'Review and submit',
        accent: PickKit.stay,
        asset: SetupAssets.key,
        state: state(u4, d4),
        onTap: () => _open(AppRoutes.staySubmit),
      ),
      if (d1 && s != null) ..._advanceRow(s),
    ];
  }

  List<Widget> _advanceRow(StayOwnerModel s) {
    final has = s.hasAdvanceDetails;
    return [
      const SectionCaption3D(TripStrings.optionalLabel),
      StayStepRow(
        number: 0,
        icon: Icons.add_rounded,
        eyebrow: 'Payment',
        title: TripStrings.advanceDetails,
        subtitle: has ? TripStrings.advanceSet : TripStrings.advanceNotSet,
        accent: PickKit.stay,
        asset: SetupAssets.moneyBag,
        state: has ? StayStepState.done : StayStepState.current,
        trailing: has ? TripStrings.edit : TripStrings.add,
        onTap: _openAdvance,
      ),
    ];
  }

  Widget _wrongRoleLink(int percent) => LinkLine3D(
        text: 'Wrong role? Change it',
        center: true,
        color: _tone.text,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
        onTap: () => Get.toNamed(AppRoutes.roleSelect, arguments: {'correction': true, 'percent': percent}),
      );

  Widget _scoreCard(int percent) {
    final caption = switch (percent) {
      0 => 'Finish 4 steps to open your dashboard',
      90 => '100% after submit',
      _ => '',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: WorkoutCard(
        tone: _tone,
        art: ListingArt.star,
        eyebrow: 'Your stay',
        title: 'Profile $percent% complete',
        subtitle: caption,
        trailing: WorkoutTrailing.ring,
        progress: percent / 100,
        minHeight: 182,
      ),
    );
  }

  Widget _rejectedStrip(StayOwnerModel s) => Banner3D(
        kind: BannerKind.bad,
        art: ListingArt.pushpin,
        title: 'Not approved',
        subtitle: (s.rejectedReason?.isNotEmpty ?? false) ? s.rejectedReason : null,
        tone: _tone,
      );

  Widget _registrationStrip() => Banner3D(
        kind: BannerKind.warn,
        art: SetupAssets.clipboard,
        title: 'Registration details needed',
        subtitle: 'Add them in Basic details',
        tone: _tone,
      );

  Widget _pendingStrip() => Banner3D(
        kind: BannerKind.good,
        art: SetupAssets.calendar,
        title: 'Under review',
        subtitle: 'We will notify you',
        tone: _tone,
      );
}
