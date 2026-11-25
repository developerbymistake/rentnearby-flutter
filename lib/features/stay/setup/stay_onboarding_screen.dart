import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/location_controller.dart';
import '../../../design/design.dart';
import '../../../widgets/global_location_gates.dart';
import '../../owner_core/onboarding/onboarding_exit.dart';
import '../../owner_core/plan/plan_bindings.dart';
import '../../stay_owner/strings/stay_setup_strings.dart';
import 'stay_basic_details_screen.dart';
import 'stay_page_header.dart';
import 'stay_setup_controller.dart';

class StayOnboardingScreen extends StatefulWidget {
  const StayOnboardingScreen({super.key});
  @override
  State<StayOnboardingScreen> createState() => _StayOnboardingScreenState();
}

class _StayOnboardingScreenState extends State<StayOnboardingScreen> {
  final _ctrl = StaySetupController.ensure();
  final _auth = Get.find<AuthController>();
  static final _tone = ListingTone.forest;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    _ctrl.mainBelow = args is Map && args['fromMyStays'] == true;
    PlanBindings.ensure();
    // Gated owners never build MainScreen; permanent so its later Get.put reuses this instance.
    if (!Get.isRegistered<LocationController>()) {
      Get.put(LocationController(), permanent: true);
      GlobalLocationGates.notifyReady();
    }
    _load();
  }

  Future<void> _load() async {
    if (_failed) setState(() => _failed = false);
    final ok = await _ctrl.load();
    if (!mounted) return;
    if (!ok) {
      if (!_auth.staysEnabled) {
        _auth.leaveOffTabRoute();
        return;
      }
      setState(() => _failed = true);
      return;
    }
    final s = _ctrl.stay.value;
    if (s == null || s.isDraft || (s.isRejected && _ctrl.mainBelow)) {
      if (s == null || s.isDraft) _auth.refreshProfile();
      setState(() => _ready = true);
      return;
    }
    if (_ctrl.mainBelow) {
      Get.back();
      return;
    }
    await _auth.refreshProfile();
    Get.offAllNamed(AppRoutes.main);
  }

  void _openMenu() {
    final s = _ctrl.stay.value;
    OnboardingExit.openMenu(context, isDraft: s == null || s.isDraft, hasDraft: s != null);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const StayBasicDetailsScreen(onboarding: true);
    final gated = !_ctrl.mainBelow;
    return PopScope(
      canPop: !gated,
      child: Scaffold(
        backgroundColor: ListingPalette.forest.page,
        body: Column(children: [
          StayPageHeader(
            title: StaySetupStrings.hubTitle,
            onBack: gated ? null : () => Get.back(),
            showBack: !gated,
            leadingIcon: gated ? Icons.more_vert_rounded : null,
            onLeading: gated ? _openMenu : null,
            leadingSemantics: StaySetupStrings.menuLabel,
          ),
          Expanded(child: _failed ? _error() : _skeleton()),
        ]),
      ),
    );
  }

  Widget _error() => LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: StateCard3D(
            tone: _tone,
            layout: StateLayout.tall,
            art: ListingArt.compass,
            title: "Couldn't load your stay",
            actionLabel: 'Try again',
            onAction: _load,
            minHeight: math.max(DS.s(300), box.maxHeight - DS.s(160)),
          ),
        ),
      );

  Widget _skeleton() => ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Padding(
            padding: DS.gapInsets(l: 18, t: 48, r: 18),
            child: ClipRRect(borderRadius: CardRadius.tile, child: SkeletonBox(height: DS.s(182), radius: 0)),
          ),
          for (var i = 0; i < 4; i++) const SkeletonSlimCard(),
        ],
      );
}
