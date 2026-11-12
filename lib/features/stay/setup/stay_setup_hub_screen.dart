import 'stay_page_header.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/location_controller.dart';
import '../../../design/design.dart';
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

class _StaySetupHubScreenState extends State<StaySetupHubScreen> with TickerProviderStateMixin {
  static const int _count = 9;
  final _ctrl = StaySetupController.ensure();
  final _auth = Get.find<AuthController>();
  late final bool _fromMyStays;
  late final AnimationController _anim = SetupKit.controller(this);
  bool _played = false;

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

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _playOnce() {
    if (_played) return;
    _played = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SetupKit.play(_anim, context);
    });
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
      if (!showSkeleton && !failed) _playOnce();
      return PopScope(
        canPop: !gated,
        child: Scaffold(
          backgroundColor: DesignColors.scaffold,
          body: Column(children: [
            StayPageHeader(
              title: 'Set up your stay',
              showBack: !gated,
              onBack: () => Get.back(),
              asset: SetupAssets.hotel,
              animation: templateInterval(_anim, 0, 2),
              trailing: gated ? _menu(canCorrect) : null,
            ),
            Expanded(
              child: showSkeleton
                  ? _skeleton()
                  : failed
                      ? StateCard.error(
                          kit: KitTone.stay,
                          title: "Couldn't load your stay",
                          actionLabel: 'Try again',
                          onAction: _ctrl.load,
                        )
                      : RefreshIndicator(
                          color: DesignColors.primary,
                          backgroundColor: DesignColors.surface,
                          onRefresh: _ctrl.load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: EdgeInsets.only(bottom: 24 + MediaQuery.viewPaddingOf(context).bottom),
                            children: _content(stay, gated),
                          ),
                        ),
            ),
          ]),
        ),
      );
    });
  }

  Widget _menu(bool canCorrect) => PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, color: DesignColors.onPrimary),
        color: DesignColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: TripKit.cardRadiusSmall),
        onSelected: (v) {
          if (v == 'role') {
            Get.toNamed(AppRoutes.roleChange);
          } else {
            _auth.logout();
          }
        },
        itemBuilder: (_) => [
          if (!canCorrect) PopupMenuItem(value: 'role', child: Text('Change role', style: TripKit.text(14))),
          PopupMenuItem(value: 'logout', child: Text('Log out', style: TripKit.text(14))),
        ],
      );

  Widget _skeleton() => Padding(
        padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 16, KitMetrics.gutter, 0),
        child: Column(children: [
          SectionTile.skeleton(lines: 5),
          for (var i = 0; i < 4; i++) ...[
            const SizedBox(height: 12),
            ListRow.skeleton(margin: EdgeInsets.zero),
          ],
        ]),
      );

  Widget _in(int i, Widget child, {bool pad = true}) => SetupEntrance(
        controller: _anim,
        index: i,
        count: _count,
        child: pad ? Padding(padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter), child: child) : child,
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
      if (s != null && s.isRejected) _in(0, _rejectedStrip(s)),
      if (s != null && s.isPendingReview) _in(0, _pendingStrip()),
      if (regMissing) _in(0, _registrationStrip()),
      _in(1, _scoreCard(percent), pad: false),
      if (canCorrect) _in(2, _wrongRoleLink(percent)),
      _in(
        3,
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
          gradient: SetupKit.sky,
          state: state(true, d1 && !regMissing),
          onTap: () => _open(AppRoutes.stayBasicDetails),
        ),
      ),
      _in(
        4,
        StayStepRow(
          number: 2,
          title: 'Rooms',
          subtitle: !u2 ? 'Complete step 1 first' : d2 ? StayOptionSets.roomsSummary(s!) : 'Add rooms, up to 2',
          accent: PickKit.stay,
          asset: SetupAssets.bed,
          gradient: SetupKit.rose,
          state: state(u2, d2),
          onTap: () => _open(AppRoutes.stayRooms),
        ),
      ),
      _in(
        5,
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
          gradient: SetupKit.sunrise,
          state: state(u3, d3),
          onTap: () => _open(AppRoutes.stayRules),
        ),
      ),
      _in(
        6,
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
          gradient: SetupKit.dusk,
          state: state(u4, d4),
          onTap: () => _open(AppRoutes.staySubmit),
        ),
      ),
      if (d1 && s != null) ..._advanceRow(s),
    ];
  }

  List<Widget> _advanceRow(StayOwnerModel s) {
    final has = s.hasAdvanceDetails;
    return [
      _in(
        7,
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(TripStrings.optionalLabel,
              style: TripKit.text(12, color: DesignColors.textSecondary).copyWith(letterSpacing: 1)),
        ),
      ),
      _in(
        8,
        StayStepRow(
          number: 0,
          icon: Icons.add_rounded,
          title: TripStrings.advanceDetails,
          subtitle: has ? TripStrings.advanceSet : TripStrings.advanceNotSet,
          accent: PickKit.stay,
          asset: SetupAssets.moneyBag,
          gradient: SetupKit.sky,
          state: has ? StayStepState.done : StayStepState.current,
          trailing: has ? TripStrings.edit : TripStrings.add,
          onTap: _openAdvance,
        ),
      ),
    ];
  }

  Widget _wrongRoleLink(int percent) => Center(
        child: TextButton(
          onPressed: () => Get.toNamed(AppRoutes.roleSelect, arguments: {'correction': true, 'percent': percent}),
          child: Text('Wrong role? Change it',
              style: TripKit.text(13, weight: FontWeight.w600, color: DesignColors.primary)),
        ),
      );

  Widget _scoreCard(int percent) {
    final caption = switch (percent) {
      0 => 'Finish 4 steps to open your dashboard',
      90 => '100% after submit',
      _ => null,
    };
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) {
        final f = templateInterval(_anim, 1, _count).value;
        return RingProgressCard(
          title: 'Profile $percent% complete',
          value: '${(percent * f).round()}',
          label: '%',
          progress: percent / 100 * f,
          subtitle: caption,
        );
      },
    );
  }

  Widget _strip({
    required LinearGradient gradient,
    required Color color,
    required Widget icon,
    required String title,
    String? body,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          color: DesignColors.surface,
          borderRadius: CardRadius.tile,
          boxShadow: ShadowTokens.elev1,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
            child: icon,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TripKit.text(13, weight: FontWeight.w600, color: color)),
              if (body != null && body.isNotEmpty)
                Text(body, style: TripKit.text(12, color: DesignColors.textGrey)),
            ]),
          ),
        ]),
      );

  Widget _rejectedStrip(StayOwnerModel s) => _strip(
        gradient: SetupKit.rose,
        color: PickKit.bad,
        icon: const Icon(Icons.close_rounded, size: 20, color: DesignColors.onPrimary),
        title: 'Not approved',
        body: s.rejectedReason,
      );

  Widget _registrationStrip() => _strip(
        gradient: SetupKit.sunrise,
        color: PickKit.warn,
        icon: Image.asset(SetupAssets.clipboard),
        title: 'Registration details needed',
        body: 'Add them in Basic details',
      );

  Widget _pendingStrip() => _strip(
        gradient: SetupKit.sky,
        color: PickKit.stayDark,
        icon: Image.asset(SetupAssets.calendar),
        title: 'Under review',
        body: 'We will notify you',
      );
}
