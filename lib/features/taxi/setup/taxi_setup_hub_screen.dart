import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/location_controller.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_taxi_owner.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/global_location_gates.dart';
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
  static final ListingTone _tone = ListingTone.coral;
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
    _anim.value = 0;
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
          backgroundColor: ListingPalette.coral.page,
          body: KitStatusBar(
            lightIcons: false,
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                PageHeader3D(
                  tone: _tone,
                  title: 'Set up your taxi',
                  art: ListingArt.taxi,
                  inlineTitle: true,
                  onBack: gated ? null : () => Get.back(),
                  trailing: gated ? _menu(canCorrect) : null,
                ),
                Expanded(
                  child: showSkeleton
                      ? _skeleton()
                      : failed
                          ? ListView(
                              padding: const EdgeInsets.only(top: 60, bottom: 24),
                              children: [
                                StateCard3D(
                                  tone: _tone,
                                  art: ListingArt.clipboard,
                                  title: "Couldn't load your taxi",
                                  actionLabel: 'Try again',
                                  onAction: _ctrl.load,
                                  layout: StateLayout.tall,
                                ),
                              ],
                            )
                          : RefreshIndicator(
                              color: _tone.button,
                              backgroundColor: FitnessAppTheme.white,
                              onRefresh: _ctrl.load,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.only(bottom: 28 + MediaQuery.paddingOf(context).bottom),
                                children: _content(taxi, gated),
                              ),
                            ),
                ),
              ]),
            ),
          ),
        ),
      );
    });
  }

  Widget _menu(bool canCorrect) => Builder(
        builder: (ctx) => TaxiHeaderButton(
          tone: _tone,
          icon: Icons.more_vert_rounded,
          tooltip: 'Menu',
          onTap: () {
            final box = ctx.findRenderObject() as RenderBox?;
            if (box == null) return;
            final rect = box.localToGlobal(Offset.zero) & box.size;
            showMenu3D(ctx, anchor: rect, items: [
              if (!canCorrect) MenuItem3D(label: 'Change role', art: ListingArt.compass, onTap: () => Get.toNamed(AppRoutes.roleChange)),
              MenuItem3D(label: 'Log out', art: ListingArt.key, onTap: _auth.logout),
            ]);
          },
        ),
      );

  Widget _skeleton() => const Padding(
        padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
        child: Column(children: [
          SkeletonBox(height: 160, radius: 8),
          SizedBox(height: 16),
          SkeletonBox(height: 78, radius: 8),
          SizedBox(height: 16),
          SkeletonBox(height: 78, radius: 8),
          SizedBox(height: 16),
          SkeletonBox(height: 78, radius: 8),
        ]),
      );

  Widget _in(int i, Widget child) => SetupEntrance(controller: _anim, index: i, count: _count, child: child);

  List<Widget> _content(TaxiOwnerModel? t, bool gated) {
    final d1 = t?.step1Done ?? false;
    final u2 = d1;
    final stepDone = (t?.identityDone ?? false) || (t?.isPendingReview ?? false);
    final d2 = u2 && (t?.routesDone ?? false) && (t?.hasLocalRate ?? false) && t?.localDayKm != null;
    final u3 = d2 && stepDone;
    final d3 = u3 && (t != null && (t.isPendingReview || t.isApproved));
    final percent = t?.percent ?? 0;
    final rateMissing = t != null && t.isApproved && t.localDayRate == null;
    final canCorrect = gated && (t == null || t.isDraft) && (_auth.user.value?.canCorrectRole ?? false);

    TaxiStepIcon icon(bool unlocked, bool done, {bool add = false}) =>
        !unlocked ? TaxiStepIcon.lock : (done ? TaxiStepIcon.check : (add ? TaxiStepIcon.add : TaxiStepIcon.arrow));

    return [
      if (t != null && t.isRejected) _in(0, _rejectedStrip(t)),
      if (t != null && t.isPendingReview) _in(0, _pendingStrip()),
      if (t != null && (t.isDraft || t.isRejected) && !t.identityDone) _in(0, _identityStrip()),
      if (rateMissing)
        _in(
          1,
          FormNoteCard(
            tone: ListingTone.cF,
            art: ListingArt.moneyBag,
            title: TripStrings.notInTripPlanning,
            body: TripStrings.addRateHint,
            titleColor: Form3D.amber,
          ),
        ),
      if (t != null && t.isApproved) _in(1, TaxiPopularRoutesNudge(onTap: () => _open(AppRoutes.taxiRoutes))),
      _in(2, _scoreCard(percent)),
      if (canCorrect) _in(3, _wrongRoleLink(percent)),
      _in(
        4,
        TaxiStepCard3D(
          tone: ListingTone.cF,
          art: ListingArt.taxi,
          step: 'Step 1',
          title: 'Vehicle and contact',
          subtitle: d1
              ? (stepDone ? TaxiOptionSets.step1Summary(t!) : 'Add licence and date of birth')
              : 'Vehicle, plate, licence, phone, base',
          icon: icon(true, d1 && stepDone),
          onTap: () => _open(AppRoutes.taxiVehicle),
        ),
      ),
      _in(
        5,
        TaxiStepCard3D(
          tone: ListingTone.cC,
          art: ListingArt.compass,
          step: 'Step 2',
          tag: rateMissing ? TripStrings.addRate : null,
          title: 'Routes and fares',
          subtitle: !u2
              ? 'Complete step 1 first'
              : d2
                  ? '${TaxiOptionSets.routesSummary(t!)}${rateMissing ? ' · ${TripStrings.rateMissing}' : ''}'
                  : 'Routes, fares, local rate',
          icon: icon(u2, d2, add: rateMissing),
          onTap: () => _open(AppRoutes.taxiRoutes),
        ),
      ),
      _in(
        6,
        TaxiStepCard3D(
          tone: ListingTone.cD,
          art: ListingArt.key,
          step: 'Step 3',
          title: 'Final submit',
          subtitle: !u3
              ? (d2 ? 'Complete step 1 first' : 'Complete step 2 first')
              : t!.isApproved
                  ? 'Your taxi is live'
                  : d3
                      ? 'Submitted for review'
                      : 'Review and submit',
          icon: icon(u3, d3),
          onTap: _openSubmit,
        ),
      ),
    ];
  }

  Widget _wrongRoleLink(int percent) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Center(
          child: Tap3D(
            onTap: () => Get.toNamed(AppRoutes.roleSelect, arguments: {'correction': true, 'percent': percent}),
            label: 'Wrong role? Change it',
            exclude: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  widthFactor: 1,
                  child: Text('Wrong role? Change it', style: Ink3D.text(13.5, FontWeight.w700, _tone.text)),
                ),
              ),
            ),
          ),
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
        return TaxiRingCard3D(
          tone: _tone,
          title: 'Profile $percent% complete',
          value: '${(percent * f).round()}%',
          progress: percent / 100 * f,
          caption: caption,
        );
      },
    );
  }

  Widget _rejectedStrip(TaxiOwnerModel t) => FormNoteCard(
        tone: ListingTone.cC,
        art: ListingArt.warning,
        title: 'Not approved',
        body: t.rejectedReason,
        titleColor: Form3D.errorText,
      );

  Widget _identityStrip() => FormNoteCard(
        tone: ListingTone.cF,
        art: ListingArt.clipboard,
        title: 'Licence details needed',
        titleColor: Form3D.amber,
      );

  Widget _pendingStrip() => FormNoteCard(
        tone: ListingTone.cB,
        art: ListingArt.calendar,
        title: 'Under review · We will notify you',
        titleColor: ListingPalette.indigo.text,
      );
}
