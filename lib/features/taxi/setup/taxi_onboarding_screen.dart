import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/location_controller.dart';
import '../../../design/design.dart';
import '../../../widgets/global_location_gates.dart';
import '../../owner_core/onboarding/onboarding_exit.dart';
import '../../owner_core/plan/plan_bindings.dart';
import 'taxi_setup_controller.dart';
import 'taxi_vehicle_screen.dart';

enum _GateView { loading, failed, wizard }

class TaxiOnboardingScreen extends StatefulWidget {
  const TaxiOnboardingScreen({super.key});
  @override
  State<TaxiOnboardingScreen> createState() => _TaxiOnboardingScreenState();
}

class _TaxiOnboardingScreenState extends State<TaxiOnboardingScreen> {
  static final ListingTone _tone = ListingTone.coral;
  final _ctrl = TaxiSetupController.ensure();
  final _auth = Get.find<AuthController>();
  _GateView _view = _GateView.loading;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    _ctrl.mainBelow = args is Map && args['fromMyTaxi'] == true;
    // Gated drivers never build MainScreen; permanent so its later Get.put reuses this instance.
    if (!Get.isRegistered<LocationController>()) {
      Get.put(LocationController(), permanent: true);
      GlobalLocationGates.notifyReady();
    }
    PlanBindings.ensure();
    _load();
  }

  Future<void> _load() async {
    if (_view != _GateView.loading) setState(() => _view = _GateView.loading);
    final ok = await _ctrl.load();
    if (!mounted) return;
    if (!ok) {
      if (!_auth.taxisEnabled) {
        _auth.leaveOffTabRoute();
        return;
      }
      setState(() => _view = _GateView.failed);
      return;
    }
    final t = _ctrl.taxi.value;
    if (t == null || t.isDraft || (t.isRejected && _ctrl.mainBelow)) {
      if (!_ctrl.mainBelow && (t == null || t.isDraft)) _auth.refreshProfile();
      setState(() => _view = _GateView.wizard);
      return;
    }
    if (_ctrl.mainBelow) {
      Get.back();
      return;
    }
    await _auth.refreshProfile();
    Get.offAllNamed(AppRoutes.main);
  }

  @override
  Widget build(BuildContext context) {
    switch (_view) {
      case _GateView.wizard:
        return const TaxiVehicleScreen(onboarding: true);
      case _GateView.loading:
      case _GateView.failed:
        return PopScope(
          canPop: _ctrl.mainBelow,
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
                    onBack: _ctrl.mainBelow ? () => Get.back() : null,
                    leadingIcon: _ctrl.mainBelow ? null : Icons.more_vert_rounded,
                    leadingSemantics: _ctrl.mainBelow ? null : 'Menu',
                    onLeading: _ctrl.mainBelow ? null : () => _menu(context),
                  ),
                  Expanded(child: _view == _GateView.failed ? _failed() : _skeleton()),
                ]),
              ),
            ),
          ),
        );
    }
  }

  void _menu(BuildContext context) {
    final t = _ctrl.taxi.value;
    OnboardingExit.openMenu(context, isDraft: t == null || t.isDraft, hasDraft: t != null);
  }

  Widget _failed() => ListView(
        padding: EdgeInsets.only(top: DS.s(60), bottom: DS.s(24)),
        children: [
          StateCard3D(
            tone: _tone,
            art: ListingArt.clipboard,
            title: "Couldn't load your taxi",
            actionLabel: 'Try again',
            onAction: _load,
            layout: StateLayout.tall,
          ),
        ],
      );

  Widget _skeleton() => Padding(
        padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(16), DS.s(18), 0),
        child: Column(children: [
          SkeletonBox(height: DS.s(160), radius: DS.radius(8)),
          Gap.v(16),
          SkeletonBox(height: DS.s(78), radius: DS.radius(8)),
          Gap.v(16),
          SkeletonBox(height: DS.s(78), radius: DS.radius(8)),
          Gap.v(16),
          SkeletonBox(height: DS.s(78), radius: DS.radius(8)),
        ]),
      );
}
