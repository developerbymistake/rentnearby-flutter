import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/location_controller.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/global_location_gates.dart';
import '../../stay/setup/stay_step_row.dart';
import '../models/taxi_owner_model.dart';
import '../taxi_option_sets.dart';
import 'taxi_setup_controller.dart';

class TaxiSetupHubScreen extends StatefulWidget {
  const TaxiSetupHubScreen({super.key});
  @override
  State<TaxiSetupHubScreen> createState() => _TaxiSetupHubScreenState();
}

class _TaxiSetupHubScreenState extends State<TaxiSetupHubScreen> {
  final _ctrl = TaxiSetupController.ensure();
  final _auth = Get.find<AuthController>();
  late final bool _fromMyTaxi;

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
      return PopScope(
        canPop: !gated,
        child: Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          body: Column(children: [
            _header(gated, canCorrect),
            Expanded(
              child: !loaded && loading
                  ? const Center(child: CircularProgressIndicator(color: TaxiColors.accent, strokeWidth: 2))
                  : failed
                      ? _errorView()
                      : RefreshIndicator(
                          color: TaxiColors.accent,
                          onRefresh: _ctrl.load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            children: _content(taxi, gated),
                          ),
                        ),
            ),
          ]),
        ),
      );
    });
  }

  Widget _header(bool gated, bool canCorrect) => Container(
        decoration: const BoxDecoration(gradient: TaxiColors.gradient),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(gated ? 20 : 4, 8, 4, 20),
            child: Row(children: [
              if (!gated)
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                ),
              const Expanded(
                child: Text('Set up your taxi',
                    style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
              if (gated)
                PopupMenuButton<String>(
                  icon: const Icon(Iconsax.more, color: Colors.white),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    if (v == 'role') {
                      Get.toNamed(AppRoutes.roleChange);
                    } else {
                      _auth.logout();
                    }
                  },
                  itemBuilder: (_) => [
                    if (!canCorrect)
                      const PopupMenuItem(
                          value: 'role',
                          child: Text('Change role', style: TextStyle(fontFamily: 'Poppins', fontSize: 14))),
                    const PopupMenuItem(
                        value: 'logout',
                        child: Text('Log out', style: TextStyle(fontFamily: 'Poppins', fontSize: 14))),
                  ],
                ),
            ]),
          ),
        ),
      );

  List<Widget> _content(TaxiOwnerModel? t, bool gated) {
    final d1 = t?.step1Done ?? false;
    final u2 = d1;
    final stepDone = (t?.identityDone ?? false) || (t?.isPendingReview ?? false);
    final d2 = u2 && (t?.routesDone ?? false);
    final u3 = d2;
    final d3 = u3 && (t != null && (t.isPendingReview || t.isApproved));
    final percent = t?.percent ?? 0;
    final canCorrect = gated && (t == null || t.isDraft) && (_auth.user.value?.canCorrectRole ?? false);

    StayStepState state(bool unlocked, bool done) =>
        !unlocked ? StayStepState.locked : (done ? StayStepState.done : StayStepState.current);

    return [
      if (t != null && t.isRejected) _rejectedStrip(t),
      if (t != null && t.isPendingReview) _pendingStrip(),
      if (t != null && (t.isDraft || t.isRejected) && !t.identityDone) _identityStrip(),
      _scoreCard(percent),
      if (canCorrect) _wrongRoleLink(percent),
      const SizedBox(height: 16),
      StayStepRow(
        number: 1,
        title: 'Vehicle and contact',
        subtitle: d1
            ? (stepDone ? TaxiOptionSets.step1Summary(t!) : 'Add licence and date of birth')
            : 'Vehicle, plate, licence, phone, base',
        state: state(true, d1 && stepDone),
        onTap: () => _open(AppRoutes.taxiVehicle),
        accent: TaxiColors.accent,
      ),
      StayStepRow(
        number: 2,
        title: 'Routes and fares',
        subtitle: !u2 ? 'Complete step 1 first' : d2 ? TaxiOptionSets.routesSummary(t!) : 'Add routes, up to 10',
        state: state(u2, d2),
        onTap: () => _open(AppRoutes.taxiRoutes),
        accent: TaxiColors.accent,
      ),
      StayStepRow(
        number: 3,
        title: 'Final submit',
        subtitle: !u3
            ? 'Complete step 2 first'
            : t!.isApproved
                ? 'Your taxi is live'
                : d3
                    ? 'Submitted for review'
                    : 'Review and submit',
        state: state(u3, d3),
        onTap: _openSubmit,
        accent: TaxiColors.accent,
      ),
    ];
  }

  Widget _wrongRoleLink(int percent) => Center(
        child: TextButton(
          onPressed: () => Get.toNamed(AppRoutes.roleSelect, arguments: {'correction': true, 'percent': percent}),
          child: const Text('Wrong role? Change it',
              style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: TaxiColors.accentDark)),
        ),
      );

  Widget _scoreCard(int percent) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final caption = switch (percent) {
      0 => 'Finish 3 steps to open your dashboard',
      90 => '100% after submit',
      _ => null,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: percent / 100),
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 600),
        curve: Curves.easeOut,
        builder: (_, value, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('Profile $percent% complete',
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            ),
            Text('${(value * 100).round()}%',
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: TaxiColors.accentDark)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(children: [
              Container(height: 8, color: AppColors.divider),
              FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(height: 8, decoration: const BoxDecoration(gradient: TaxiColors.gradient)),
              ),
            ]),
          ),
          if (caption != null) ...[
            const SizedBox(height: 8),
            Text(caption, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          ],
        ]),
      ),
    );
  }

  Widget _strip({required Color color, required IconData icon, required String title, String? body}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: color)),
              if (body != null && body.isNotEmpty)
                Text(body, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium)),
            ]),
          ),
        ]),
      );

  Widget _rejectedStrip(TaxiOwnerModel t) =>
      _strip(color: AppColors.error, icon: Iconsax.close_circle, title: 'Not approved', body: t.rejectedReason);

  Widget _identityStrip() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(999)),
        child: const Row(children: [
          Icon(Iconsax.info_circle, size: 16, color: AppColors.warningText),
          SizedBox(width: 8),
          Expanded(
            child: Text('Licence details needed',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText)),
          ),
        ]),
      );

  Widget _pendingStrip() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(999)),
        child: const Row(children: [
          Icon(Iconsax.clock, size: 16, color: AppColors.warningText),
          SizedBox(width: 8),
          Expanded(
            child: Text('Under review · We will notify you',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText)),
          ),
        ]),
      );

  Widget _errorView() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
}
