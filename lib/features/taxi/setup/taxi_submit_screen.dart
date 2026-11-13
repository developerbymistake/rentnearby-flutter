import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_taxi_owner.dart';
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
  static final ListingTone _tone = ListingTone.coral;
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
        backgroundColor: ListingPalette.coral.page,
        body: KitStatusBar(
          lightIcons: false,
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              PageHeader3D(
                tone: _tone,
                title: 'Final Submit',
                art: ListingArt.key,
                inlineTitle: true,
                onBack: () {
                  if (!_ctrl.isSaving.value) Get.back();
                },
              ),
              Expanded(
                child: Obx(() {
                  final t = _ctrl.taxi.value;
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      SetupEntrance(controller: _anim, index: 0, count: 3, child: TitleRow3D(title: 'Check your taxi', tone: _tone)),
                      if (t != null) ...[
                        SetupEntrance(
                          controller: _anim,
                          index: 1,
                          count: 3,
                          child: TaxiStepCard3D(
                            tone: ListingTone.cF,
                            art: ListingArt.taxi,
                            step: 'Step 1',
                            title: 'Vehicle and contact',
                            subtitle: t.identityDone ? TaxiOptionSets.step1Summary(t) : 'Add licence and date of birth',
                            icon: TaxiStepIcon.edit,
                            onTap: () => _edit(AppRoutes.taxiVehicle),
                          ),
                        ),
                        SetupEntrance(
                          controller: _anim,
                          index: 2,
                          count: 3,
                          child: TaxiStepCard3D(
                            tone: ListingTone.cC,
                            art: ListingArt.compass,
                            step: 'Step 2',
                            title: 'Routes and fares',
                            subtitle: TaxiOptionSets.routesSummary(t),
                            icon: TaxiStepIcon.edit,
                            onTap: () => _edit(AppRoutes.taxiRoutes),
                          ),
                        ),
                      ],
                    ],
                  );
                }),
              ),
            ]),
          ),
        ),
        bottomNavigationBar: Obx(() => FormFooter(
              tone: _tone,
              top: const ToastDock(),
              primaryLabel: 'Submit',
              primaryLoading: _ctrl.isSaving.value,
              onPrimary: _ctrl.isSaving.value || _ctrl.taxi.value == null ? null : _submit,
              note: 'Dashboard opens after submit',
            )),
      ),
      Obx(() => _ctrl.isSaving.value ? const SetupBusy(message: 'Submitting...', tone: KitTone.taxi, art: ListingArt.key) : const SizedBox.shrink()),
    ]);
    return Obx(() => PopScope(canPop: !_ctrl.isSaving.value, child: body));
  }
}
