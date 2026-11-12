import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/location_controller.dart';
import '../../../design/design.dart';
import '../../../design/extra/trip_plan_look.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/global_location_gates.dart';
import '../../stay/setup/stay_step_row.dart';
import '../../trip/trip_strings.dart';
import '../models/taxi_owner_model.dart';
import '../taxi_option_sets.dart';
import 'taxi_popular_routes_nudge.dart';
import 'taxi_setup_controller.dart';

class TaxiSetupHubScreen extends StatefulWidget {
  const TaxiSetupHubScreen({super.key});
  @override
  State<TaxiSetupHubScreen> createState() => _TaxiSetupHubScreenState();
}

class _TaxiSetupHubScreenState extends State<TaxiSetupHubScreen> with TickerProviderStateMixin {
  static const int _count = 10;
  final _ctrl = TaxiSetupController.ensure();
  final _auth = Get.find<AuthController>();
  late final bool _fromMyTaxi;
  late final AnimationController _anim = SetupKit.controller(this);
  bool _played = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    _fromMyTaxi = args is Map && args['fromMyTaxi'] == true;
    _ctrl.mainBelow = _fromMyTaxi;
    // Gated drivers never build MainScreen; permanent so its later Get.put reuses this instance.
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
    if (!ok && mounted && !_auth.taxisEnabled) {
      _auth.leaveOffTabRoute();
      return;
    }
    final t = _ctrl.taxi.value;
    if (!ok || !mounted || _fromMyTaxi) return;
    if (t == null || t.isDraft) {
      _auth.refreshProfile();
      return;
    }
    await _auth.refreshProfile();
    Get.offAllNamed(AppRoutes.main);
  }

  bool get _gated {
    if (_fromMyTaxi) return false;
    final status = _ctrl.taxi.value?.status ?? _auth.user.value?.taxiStatus;
    return status == null || status == TaxiStatus.draft;
  }

  Future<void> _open(String route) async {
    final t = _ctrl.taxi.value;
    if (t != null && t.isPendingReview) {
      AppToast.info('Your taxi is under review');
      return;
    }
    await Get.toNamed(route);
    if (mounted) _ctrl.load();
  }

  void _openSubmit() {
    final t = _ctrl.taxi.value;
    if (t != null && t.isApproved) {
      AppToast.info('Your taxi is live');
      return;
    }
    _open(AppRoutes.taxiSubmit);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final gated = _gated;
      final taxi = _ctrl.taxi.value;
      final canCorrect = gated && (taxi == null || taxi.isDraft) && (_auth.user.value?.canCorrectRole ?? false);
      final loading = _ctrl.isLoading.value;
      final loaded = _ctrl.hasLoaded.value;
      final failed = _ctrl.loadFailed.value;
      final showSkeleton = !loaded && loading;
      if (!showSkeleton && !failed) _playOnce();
      return PopScope(
        canPop: !gated,
        child: Scaffold(
          backgroundColor: FitnessAppTheme.background,
          body: Column(children: [
            ModuleHeader(
              title: 'Set up your taxi',
              tone: KitTone.taxi,
              onBack: gated ? null : () => Get.back(),
              trailing: gated ? [_menu(canCorrect)] : const [],
            ),
            Expanded(
              child: showSkeleton
                  ? _skeleton()
                  : failed
                      ? StateCard.error(
                          title: "Couldn't load your taxi",
                          kit: KitTone.taxi,
                          actionLabel: 'Try again',
                          onAction: _ctrl.load,
                        )
                      : RefreshIndicator(
                          color: FitnessAppTheme.nearlyDarkBlue,
                          backgroundColor: FitnessAppTheme.white,
                          onRefresh: _ctrl.load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 24),
                            children: _content(taxi, gated),
                          ),
                        ),
            ),
          ]),
        ),
      );
    });
  }

  Widget _menu(bool canCorrect) => PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, color: FitnessAppTheme.white),
        color: FitnessAppTheme.white,
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
          const TemplatePlaceholder(height: 160, radius: 8),
          for (var i = 0; i < 3; i++) ...[
            const SizedBox(height: 16),
            const TemplatePlaceholder(height: 78, radius: 8),
          ],
        ]),
      );

  Widget _in(int i, Widget child, {bool pad = true}) => SetupEntrance(
        controller: _anim,
        index: i,
        count: _count,
        child: pad ? Padding(padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter), child: child) : child,
      );

  List<Widget> _content(TaxiOwnerModel? t, bool gated) {
    final d1 = t?.step1Done ?? false;
    final u2 = d1;
    final stepDone = (t?.identityDone ?? false) || (t?.isPendingReview ?? false);
    final d2 = u2 && (t?.routesDone ?? false);
    final u3 = d2 && stepDone;
    final d3 = u3 && (t != null && (t.isPendingReview || t.isApproved));
    final percent = t?.percent ?? 0;
    final rateMissing = t != null && t.isApproved && t.localDayRate == null;
    final canCorrect = gated && (t == null || t.isDraft) && (_auth.user.value?.canCorrectRole ?? false);

    StayStepState state(bool unlocked, bool done) =>
        !unlocked ? StayStepState.locked : (done ? StayStepState.done : StayStepState.current);

    return [
      if (t != null && t.isRejected) _in(0, _rejectedStrip(t)),
      if (t != null && t.isPendingReview) _in(0, _pendingStrip()),
      if (t != null && (t.isDraft || t.isRejected) && !t.identityDone) _in(0, _identityStrip()),
      if (rateMissing)
        _in(
          1,
          _strip(
            gradient: SetupKit.sunrise,
            color: TripLook.warning,
            icon: Image.asset(TravelIcon.money),
            title: TripStrings.notInTripPlanning,
            body: TripStrings.addRateHint,
          ),
        ),
      if (t != null && t.isApproved) _in(1, TaxiPopularRoutesNudge(onTap: () => _open(AppRoutes.taxiRoutes))),
      _in(2, _scoreCard(percent), pad: false),
      if (canCorrect) _in(3, _wrongRoleLink(percent)),
      _in(
        4,
        StayStepRow(
          number: 1,
          title: 'Vehicle and contact',
          subtitle: d1
              ? (stepDone ? TaxiOptionSets.step1Summary(t!) : 'Add licence and date of birth')
              : 'Vehicle, plate, licence, phone, base',
          state: state(true, d1 && stepDone),
          onTap: () => _open(AppRoutes.taxiVehicle),
          accent: PickKit.taxi,
          asset: TravelIcon.taxi,
          gradient: SetupKit.sunrise,
        ),
      ),
      _in(
        5,
        StayStepRow(
          number: 2,
          title: 'Routes and fares',
          subtitle: !u2
              ? 'Complete step 1 first'
              : d2
                  ? '${TaxiOptionSets.routesSummary(t!)}${rateMissing ? ' · ${TripStrings.rateMissing}' : ''}'
                  : 'Routes, fares, local rate',
          trailing: rateMissing ? TripStrings.addRate : null,
          state: state(u2, d2),
          onTap: () => _open(AppRoutes.taxiRoutes),
          accent: PickKit.taxi,
          asset: TravelIcon.route,
          gradient: SetupKit.rose,
        ),
      ),
      _in(
        6,
        StayStepRow(
          number: 3,
          title: 'Final submit',
          subtitle: !u3
              ? (d2 ? 'Complete step 1 first' : 'Complete step 2 first')
              : t!.isApproved
                  ? 'Your taxi is live'
                  : d3
                      ? 'Submitted for review'
                      : 'Review and submit',
          state: state(u3, d3),
          onTap: _openSubmit,
          accent: PickKit.taxi,
          asset: SetupAssets.key,
          gradient: SetupKit.dusk,
        ),
      ),
    ];
  }

  Widget _wrongRoleLink(int percent) => Center(
        child: TextButton(
          onPressed: () => Get.toNamed(AppRoutes.roleSelect, arguments: {'correction': true, 'percent': percent}),
          child: Text('Wrong role? Change it',
              style: TripKit.text(13, weight: FontWeight.w600, color: FitnessAppTheme.nearlyDarkBlue)),
        ),
      );

  Widget _scoreCard(int percent) {
    final caption = switch (percent) {
      0 => 'Finish 3 steps to open your dashboard',
      90 => '100% after submit',
      _ => null,
    };
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) {
        final f = templateInterval(_anim, 2, _count).value;
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
        decoration: BoxDecoration(
          color: FitnessAppTheme.white,
          borderRadius: TripKit.cardRadiusSmall,
          boxShadow: PickKit.greyShadow(),
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
              if (body != null && body.isNotEmpty) Text(body, style: TripKit.text(12, color: FitnessAppTheme.grey)),
            ]),
          ),
        ]),
      );

  Widget _rejectedStrip(TaxiOwnerModel t) => _strip(
        gradient: SetupKit.rose,
        color: TripLook.error,
        icon: const Icon(Icons.close_rounded, size: 20, color: FitnessAppTheme.white),
        title: 'Not approved',
        body: t.rejectedReason,
      );

  Widget _identityStrip() => _strip(
        gradient: SetupKit.sunrise,
        color: TripLook.warning,
        icon: Image.asset(TravelIcon.note),
        title: 'Licence details needed',
      );

  Widget _pendingStrip() => _strip(
        gradient: SetupKit.sky,
        color: PickKit.stayDark,
        icon: Image.asset(TravelIcon.calendar),
        title: 'Under review · We will notify you',
      );
}
