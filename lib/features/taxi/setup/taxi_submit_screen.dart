import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/app_loading_overlay.dart';
import '../../../widgets/gradient_button.dart';
import '../taxi_option_sets.dart';
import 'taxi_setup_controller.dart';

class TaxiSubmitScreen extends StatefulWidget {
  const TaxiSubmitScreen({super.key});
  @override
  State<TaxiSubmitScreen> createState() => _TaxiSubmitScreenState();
}

class _TaxiSubmitScreenState extends State<TaxiSubmitScreen> {
  final _ctrl = TaxiSetupController.ensure();

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
    if (!ok || !mounted) return;
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
        backgroundColor: AppColors.scaffoldBg,
        body: Column(children: [
          Container(
            decoration: const BoxDecoration(gradient: TaxiColors.gradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 20, 20),
                child: Row(children: [
                  IconButton(
                    onPressed: () {
                      if (!_ctrl.isSaving.value) Get.back();
                    },
                    icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                  ),
                  const Text('Final Submit',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                ]),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              final t = _ctrl.taxi.value;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Check your taxi',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      const SizedBox(height: 6),
                      if (t != null) ...[
                        _summaryRow(
                            'Vehicle and contact',
                            t.identityDone ? TaxiOptionSets.step1Summary(t) : 'Add licence and date of birth',
                            AppRoutes.taxiVehicle),
                        const Divider(height: 1, color: AppColors.divider),
                        _summaryRow('Routes and fares', TaxiOptionSets.routesSummary(t), AppRoutes.taxiRoutes),
                      ],
                    ]),
                  ),
                ],
              );
            }),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(20, 12, 20, AppInsets.bottomViewPadding(context) + 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Obx(() => GradientButton(
                    onPressed: _ctrl.isSaving.value || _ctrl.taxi.value == null ? null : _submit,
                    isLoading: _ctrl.isSaving.value,
                    label: 'Submit',
                    gradient: TaxiColors.gradient,
                    shadowColor: TaxiColors.accent,
                  )),
              const SizedBox(height: 8),
              const Text('Dashboard opens after submit',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
            ]),
          ),
        ]),
      ),
      Obx(() => _ctrl.isSaving.value
          ? AppLoadingOverlay.stackChild(message: 'Submitting...', indicatorColor: TaxiColors.accent)
          : const SizedBox.shrink()),
    ]);
    return Obx(() => PopScope(canPop: !_ctrl.isSaving.value, child: body));
  }

  Widget _summaryRow(String title, String summary, String route) => InkWell(
        onTap: () => _edit(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
              ]),
            ),
            const SizedBox(width: 8),
            const Text('Edit',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: TaxiColors.accentDark)),
          ]),
        ),
      );
}
