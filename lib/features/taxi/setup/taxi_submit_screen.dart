import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/onboarding_closed_dialog.dart';
import '../taxi_option_sets.dart';
import 'taxi_setup_controller.dart';

class TaxiSubmitScreen extends StatefulWidget {
  const TaxiSubmitScreen({super.key});
  @override
  State<TaxiSubmitScreen> createState() => _TaxiSubmitScreenState();
}

class _TaxiSubmitScreenState extends State<TaxiSubmitScreen> with TickerProviderStateMixin {
  final _ctrl = TaxiSetupController.ensure();
  late final AnimationController _anim = SetupKit.controller(this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SetupKit.play(_anim, context);
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _edit(String route) async {
    if (_ctrl.isSaving.value) return;
    await Get.toNamed(route);
    if (mounted) _ctrl.load();
  }

  Future<void> _submit() async {
    if (_ctrl.isSaving.value) return;
    final t = _ctrl.taxi.value;
    if (t == null || !t.step1Done) {
      AppToast.warning('Complete step 1 first.');
      return;
    }
    if (!t.identityDone) {
      AppToast.warning('Add your licence and date of birth.');
      return;
    }
    if (!t.routesDone) {
      AppToast.warning('Complete step 2 first.');
      return;
    }
    final ok = await _ctrl.submit();
    if (!ok) {
      if (mounted && _ctrl.lastErrorType == 'OnboardingClosed') {
        final cur = _ctrl.taxi.value;
        final canCorrect = (cur == null || cur.isDraft) && (Get.find<AuthController>().user.value?.canCorrectRole ?? false);
        final percent = cur?.percent ?? 0;
        OnboardingClosedDialog.show(context,
            onChangeRole: canCorrect
                ? () => Get.toNamed(AppRoutes.roleSelect, arguments: {'correction': true, 'percent': percent})
                : null);
      }
      return;
    }
    if (!mounted) return;
    final auth = Get.find<AuthController>();
    AppToast.success('Submitted for review');
    if (_ctrl.mainBelow) {
      Get.until((r) => r.settings.name == AppRoutes.main);
      auth.switchToTab(AppTabs.taxi);
      return;
    }
    Get.offAllNamed(AppRoutes.main);
    WidgetsBinding.instance.addPostFrameCallback((_) => auth.switchToTab(AppTabs.taxi));
  }

  @override
  Widget build(BuildContext context) {
    final body = Stack(children: [
      Scaffold(
        backgroundColor: FitnessAppTheme.background,
        body: Column(children: [
          ModuleHeader(
            title: 'Final Submit',
            tone: KitTone.taxi,
            onBack: () {
              if (!_ctrl.isSaving.value) Get.back();
            },
            leadingAsset: SetupAssets.key,
          ),
          Expanded(
            child: Obx(() {
              final t = _ctrl.taxi.value;
              return ListView(
                padding: const EdgeInsets.all(KitMetrics.gutter),
                children: [
                  SetupEntrance(
                    controller: _anim,
                    index: 0,
                    count: 3,
                    child: SetupCard(
                      title: 'Check your taxi',
                      child: Column(children: [
                        if (t != null) ...[
                          SetupEntrance(
                            controller: _anim,
                            index: 1,
                            count: 3,
                            child: _summaryRow(
                                'Vehicle and contact',
                                t.identityDone ? TaxiOptionSets.step1Summary(t) : 'Add licence and date of birth',
                                AppRoutes.taxiVehicle,
                                TravelIcon.taxi,
                                SetupKit.sunrise),
                          ),
                          const Divider(height: 1, color: FitnessAppTheme.spacer),
                          SetupEntrance(
                            controller: _anim,
                            index: 2,
                            count: 3,
                            child: _summaryRow('Routes and fares', TaxiOptionSets.routesSummary(t),
                                AppRoutes.taxiRoutes, TravelIcon.route, SetupKit.rose),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ],
              );
            }),
          ),
          SetupFooter(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Obx(() => PickButton(
                    onPressed: _ctrl.isSaving.value || _ctrl.taxi.value == null ? null : _submit,
                    isLoading: _ctrl.isSaving.value,
                    label: 'Submit',
                    gradient: PickKit.taxiGradient,
                    shadowColor: PickKit.taxiDark,
                  )),
              const SizedBox(height: 8),
              Text('Dashboard opens after submit', style: TripKit.text(12, color: FitnessAppTheme.lightText)),
            ]),
          ),
        ]),
      ),
      Obx(() => _ctrl.isSaving.value ? const SetupBusy(message: 'Submitting...') : const SizedBox.shrink()),
    ]);
    return Obx(() => PopScope(canPop: !_ctrl.isSaving.value, child: body));
  }

  Widget _summaryRow(String title, String summary, String route, String asset, LinearGradient g) => InkWell(
        onTap: () => _edit(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: g),
              child: Image.asset(asset),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TripKit.text(14)),
                const SizedBox(height: 2),
                Text(summary,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: TripKit.text(12, color: FitnessAppTheme.grey)),
              ]),
            ),
            const SizedBox(width: 8),
            Text('Edit', style: TripKit.text(13, weight: FontWeight.w600, color: FitnessAppTheme.nearlyDarkBlue)),
          ]),
        ),
      );
}
