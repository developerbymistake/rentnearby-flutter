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

class _StaySubmitScreenState extends State<StaySubmitScreen> with TickerProviderStateMixin {
  final _ctrl = StaySetupController.ensure();
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
        backgroundColor: DesignColors.scaffold,
        body: Column(children: [
          StayPageHeader(
            title: 'Final Submit',
            onBack: () => Get.back(),
            asset: SetupAssets.key,
            animation: templateInterval(_anim, 0, 2),
          ),
          Expanded(
            child: Obx(() {
              final s = _ctrl.stay.value;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SetupEntrance(
                    controller: _anim,
                    index: 0,
                    count: 4,
                    child: SectionTile(
 tone: KitTone.stay,
 margin: const EdgeInsets.only(bottom: 16),
                      title: 'Check your stay',
                      child: Column(children: [
                        if (s != null) ...[
                          SetupEntrance(
                            controller: _anim,
                            index: 1,
                            count: 4,
                            child: _summaryRow(
                                'Basic details',
                                s.registrationDone ? StayOptionSets.basicSummary(s) : 'Add registration details',
                                AppRoutes.stayBasicDetails,
                                SetupAssets.hotel,
                                SetupKit.sky),
                          ),
                          const Divider(height: 1, color: DesignColors.dividerSoft),
                          SetupEntrance(
                            controller: _anim,
                            index: 2,
                            count: 4,
                            child: _summaryRow('Rooms', StayOptionSets.roomsSummary(s), AppRoutes.stayRooms,
                                SetupAssets.bed, SetupKit.rose),
                          ),
                          const Divider(height: 1, color: DesignColors.dividerSoft),
                          SetupEntrance(
                            controller: _anim,
                            index: 3,
                            count: 4,
                            child: _summaryRow('Rules', StayOptionSets.rulesSummary(s), AppRoutes.stayRules,
                                SetupAssets.clipboard, SetupKit.sunrise),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ],
              );
            }),
          ),
          StayFooter(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Obx(() => PrimaryButton(
 tone: KitTone.stay,
                    onPressed: _ctrl.isSaving.value || _ctrl.stay.value == null ? null : _submit,
                    loading: _ctrl.isSaving.value,
                    label: 'Submit',
                  )),
              const SizedBox(height: 8),
              Text('Dashboard opens after submit', style: TripKit.text(12, color: DesignColors.textSecondary)),
            ]),
          ),
        ]),
      ),
      Obx(() => _ctrl.isSaving.value ? const StayBusy(message: 'Submitting...') : const SizedBox.shrink()),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TripKit.text(12, color: DesignColors.textGrey)),
              ]),
            ),
            const SizedBox(width: 8),
            Text('Edit', style: TripKit.text(13, weight: FontWeight.w600, color: DesignColors.primary)),
          ]),
        ),
      );
}
