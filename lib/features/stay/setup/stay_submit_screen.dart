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
import 'stay_option_sets.dart';
import 'stay_setup_controller.dart';

class StaySubmitScreen extends StatefulWidget {
  const StaySubmitScreen({super.key});
  @override
  State<StaySubmitScreen> createState() => _StaySubmitScreenState();
}

class _StaySubmitScreenState extends State<StaySubmitScreen> {
  final _ctrl = StaySetupController.ensure();

  Future<void> _edit(String route) async {
    await Get.toNamed(route);
    if (mounted) _ctrl.load();
  }

  Future<void> _submit() async {
    final ok = await _ctrl.submit();
    if (!ok || !mounted) return;
    final auth = Get.find<AuthController>();
    AppToast.success('Submitted for review');
    if (_ctrl.mainBelow) {
      Get.until((r) => r.settings.name == AppRoutes.main);
      auth.switchToTab(AppTabs.stays);
      return;
    }
    Get.offAllNamed(AppRoutes.main);
    WidgetsBinding.instance.addPostFrameCallback((_) => auth.switchToTab(AppTabs.stays));
  }

  @override
  Widget build(BuildContext context) {
    final body = Stack(children: [
      Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Column(children: [
          Container(
            decoration: const BoxDecoration(gradient: StayColors.gradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 20, 20),
                child: Row(children: [
                  IconButton(
                    onPressed: () => Get.back(),
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
              final s = _ctrl.stay.value;
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
                      const Text('Check your stay',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      const SizedBox(height: 6),
                      if (s != null) ...[
                        _summaryRow('Basic details', StayOptionSets.basicSummary(s), AppRoutes.stayBasicDetails),
                        const Divider(height: 1, color: AppColors.divider),
                        _summaryRow('Rooms', StayOptionSets.roomsSummary(s), AppRoutes.stayRooms),
                        const Divider(height: 1, color: AppColors.divider),
                        _summaryRow('Rules', StayOptionSets.rulesSummary(s), AppRoutes.stayRules),
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
                    onPressed: _ctrl.isSaving.value || _ctrl.stay.value == null ? null : _submit,
                    isLoading: _ctrl.isSaving.value,
                    label: 'Submit',
                    gradient: StayColors.gradient,
                    shadowColor: StayColors.accent,
                  )),
              const SizedBox(height: 8),
              const Text('Dashboard opens after submit',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
            ]),
          ),
        ]),
      ),
      Obx(() => _ctrl.isSaving.value
          ? AppLoadingOverlay.stackChild(message: 'Submitting...')
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
              ]),
            ),
            const SizedBox(width: 8),
            const Text('Edit',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: StayColors.accentDark)),
          ]),
        ),
      );
}
