import 'stay_page_header.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/onboarding_closed_dialog.dart';
import 'stay_option_sets.dart';
import 'stay_setup_controller.dart';

class StaySubmitScreen extends StatefulWidget {
  const StaySubmitScreen({super.key});
  @override
  State<StaySubmitScreen> createState() => _StaySubmitScreenState();
}

class _StaySubmitScreenState extends State<StaySubmitScreen> {
  final _ctrl = StaySetupController.ensure();
  static final _tone = ListingTone.forest;

  Future<void> _edit(String route) async {
    await Get.toNamed(route);
    if (mounted) _ctrl.load();
  }

  Future<void> _submit() async {
    if (_ctrl.isSaving.value) return;
    final s = _ctrl.stay.value;
    if (s != null && !s.registrationDone) {
      AppToast.warning('Add your registration details.');
      return;
    }
    final ok = await _ctrl.submit();
    if (!ok) {
      if (mounted && _ctrl.lastErrorType == 'OnboardingClosed') {
        final st = _ctrl.stay.value;
        final canCorrect = (st == null || st.isDraft) && (Get.find<AuthController>().user.value?.canCorrectRole ?? false);
        final percent = st?.setupPercent ?? 0;
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
        backgroundColor: ListingPalette.forest.page,
        body: Column(children: [
          StayPageHeader(title: 'Final Submit', subtitle: 'Review and submit', onBack: () => Get.back(), asset: SetupAssets.key),
          Expanded(
            child: Obx(() {
              final s = _ctrl.stay.value;
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  FormSectionCard(
                    tone: _tone,
                    art: ListingArt.key,
                    title: 'Check your stay',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (s != null) ...[
                        _summaryRow('Basic details', s.registrationDone ? StayOptionSets.basicSummary(s) : 'Add registration details',
                            AppRoutes.stayBasicDetails, SetupAssets.hotel,
                            bad: !s.registrationDone),
                        _summaryRow('Rooms', StayOptionSets.roomsSummary(s), AppRoutes.stayRooms, SetupAssets.bed),
                        _summaryRow('Rules', StayOptionSets.rulesSummary(s), AppRoutes.stayRules, SetupAssets.clipboard),
                      ],
                    ]),
                  ),
                ],
              );
            }),
          ),
        ]),
        bottomNavigationBar: Obx(() => FormFooter(
              tone: _tone,
              primaryLabel: 'Submit',
              onPrimary: _ctrl.isSaving.value || _ctrl.stay.value == null ? null : _submit,
              primaryLoading: _ctrl.isSaving.value,
              note: 'Dashboard opens after submit',
            )),
      ),
      Obx(() => _ctrl.isSaving.value ? const StayBusy(message: 'Submitting...', art: SetupAssets.key) : const SizedBox.shrink()),
    ]);
    return Obx(() => PopScope(canPop: !_ctrl.isSaving.value, child: body));
  }

  Widget _summaryRow(String title, String summary, String route, String asset, {bool bad = false}) => Tap3D(
        onTap: () => _edit(route),
        child: SummaryRow3D(
          tone: _tone,
          art: asset,
          title: title,
          detail: summary,
          detailBad: bad,
          actionLabel: 'Edit',
          onAction: () => _edit(route),
          divider: true,
        ),
      );
}
