import 'stay_page_header.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/onboarding_closed_dialog.dart';
import '../../../utils/money_format.dart';
import '../../stay_owner/strings/stay_setup_strings.dart';
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
      if (mounted && (_ctrl.lastErrorType == 'OnboardingClosed' || _ctrl.lastErrorType == 'StayOutsideDistrict')) {
        final st = _ctrl.stay.value;
        final canCorrect = (st == null || st.isDraft) && (Get.find<AuthController>().user.value?.canCorrectRole ?? false);
        final percent = st?.setupPercent ?? 0;
        OnboardingClosedDialog.show(context,
            body: StaySetupStrings.notOpenBody,
            onChangeRole: canCorrect
                ? () => Get.toNamed(AppRoutes.roleSelect, arguments: {'correction': true, 'percent': percent})
                : null);
      }
      return;
    }
    if (!mounted) return;
    final auth = Get.find<AuthController>();
    AppToast.success(StaySetupStrings.submittedToast);
    if (_ctrl.mainBelow) {
      Get.until((r) => r.settings.name == AppRoutes.main);
      auth.switchToTab(AppTabs.home);
      return;
    }
    Get.offAllNamed(AppRoutes.main);
    WidgetsBinding.instance.addPostFrameCallback((_) => auth.switchToTab(AppTabs.home));
  }

  @override
  Widget build(BuildContext context) {
    final body = Stack(children: [
      Scaffold(
        backgroundColor: ListingPalette.forest.page,
        body: Column(children: [
          StayPageHeader(title: StaySetupStrings.submitTitle, subtitle: StaySetupStrings.submitStep, onBack: () => Get.back(), asset: SetupAssets.key),
          Expanded(
            child: Obx(() {
              final s = _ctrl.stay.value;
              return ListView(
                padding: EdgeInsets.only(bottom: DS.s(24)),
                children: [
                  FormSectionCard(
                    tone: _tone,
                    art: ListingArt.key,
                    title: StaySetupStrings.checkYourStay,
                    hint: StaySetupStrings.almostDone,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (s != null) ...[
                        _summaryRow('Basic details', s.registrationDone ? StaySetupStrings.basicSummary(s.name ?? 'Stay', s.stayTypeName ?? 'Stay', s.photos.length) : 'Add registration details',
                            AppRoutes.stayBasicDetails, SetupAssets.hotel,
                            bad: !s.registrationDone),
                        _summaryRow('Rooms', StaySetupStrings.roomsSummary([for (final r in s.rooms) (r.label, Money.exact(r.pricePerNight))]), AppRoutes.stayRooms, SetupAssets.bed),
                        _summaryRow('Rules', s.rules == null ? '' : StaySetupStrings.rulesSummary(s.rules!.checkInTime, s.rules!.checkOutTime, s.rules!.cancellationPolicy), AppRoutes.stayRules, SetupAssets.clipboard),
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
              primaryLabel: StaySetupStrings.submit,
              onPrimary: _ctrl.isSaving.value || _ctrl.stay.value == null ? null : _submit,
              primaryLoading: _ctrl.isSaving.value,
              note: StaySetupStrings.dashboardOpens,
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
