import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/location_controller.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/global_location_gates.dart';
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

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final gated = _gated;
      final stay = _ctrl.stay.value;
      final canCorrect = gated && (stay == null || stay.isDraft) && (_auth.user.value?.canCorrectRole ?? false);
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
                  ? const Center(child: CircularProgressIndicator(color: StayColors.accent, strokeWidth: 2))
                  : failed
                      ? _errorView()
                      : RefreshIndicator(
                          color: StayColors.accent,
                          onRefresh: _ctrl.load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            children: _content(stay, gated),
                          ),
                        ),
            ),
          ]),
        ),
      );
    });
  }

  Widget _header(bool gated, bool canCorrect) => Container(
        decoration: const BoxDecoration(gradient: StayColors.gradient),
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
                child: Text('Set up your stay',
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

  List<Widget> _content(StayOwnerModel? s, bool gated) {
    final d1 = s?.step1Done ?? false;
    final regMissing =
        d1 && (s?.canEditSetup ?? true) && !(s?.registrationDone ?? false);
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
      const SizedBox(height: 16),
      StayStepRow(
        number: 1,
        title: 'Basic details',
        subtitle: regMissing
            ? 'Add registration details'
            : d1
                ? StayOptionSets.basicSummary(s!)
                : 'Details, registration, location, photos',
        accent: StayColors.accent,
        state: state(true, d1 && !regMissing),
        onTap: () => _open(AppRoutes.stayBasicDetails),
      ),
      StayStepRow(
        number: 2,
        title: 'Rooms',
        subtitle: !u2 ? 'Complete step 1 first' : d2 ? StayOptionSets.roomsSummary(s!) : 'Add rooms, up to 2',
        accent: StayColors.accent,
        state: state(u2, d2),
        onTap: () => _open(AppRoutes.stayRooms),
      ),
      StayStepRow(
        number: 3,
        title: 'Rules',
        subtitle: !u3 ? 'Complete step 2 first' : d3 ? StayOptionSets.rulesSummary(s!) : 'Check-in, house rules, cancellation',
        accent: StayColors.accent,
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
        accent: StayColors.accent,
        state: state(u4, d4),
        onTap: () => _open(AppRoutes.staySubmit),
      ),
    ];
  }

  Widget _wrongRoleLink(int percent) => Center(
        child: TextButton(
          onPressed: () => Get.toNamed(AppRoutes.roleSelect, arguments: {'correction': true, 'percent': percent}),
          child: const Text('Wrong role? Change it',
              style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: StayColors.accentDark)),
        ),
      );

  Widget _scoreCard(int percent) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final caption = switch (percent) {
      0 => 'Finish 4 steps to open your dashboard',
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
                    fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: StayColors.accentDark)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(children: [
              Container(height: 8, color: AppColors.divider),
              FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(height: 8, decoration: const BoxDecoration(gradient: StayColors.gradient)),
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

  Widget _rejectedStrip(StayOwnerModel s) =>
      _strip(color: AppColors.error, icon: Iconsax.close_circle, title: 'Not approved', body: s.rejectedReason);

  Widget _registrationStrip() => _strip(
        color: AppColors.warningText,
        icon: Iconsax.info_circle,
        title: 'Registration details needed',
        body: 'Add them in Basic details',
      );

  Widget _pendingStrip() => _strip(
        color: StayColors.accentDark,
        icon: Iconsax.clock,
        title: 'Under review',
        body: 'We will notify you',
      );

  Widget _errorView() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Couldn't load your stay",
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium)),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _ctrl.load,
            child: const Text('Try again',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: StayColors.accentDark)),
          ),
        ]),
      );
}
