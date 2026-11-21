import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_taxi_owner.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/onboarding_closed_dialog.dart';
import '../../taxi_driver/strings/taxi_setup_strings.dart';
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
    AppToast.success(TaxiSetupStrings.submittedToast);
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
        backgroundColor: ListingPalette.coral.page,
        body: KitStatusBar(
          lightIcons: false,
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              PageHeader3D(
                tone: _tone,
                title: TaxiSetupStrings.submitTitle,
                subtitle: TaxiSetupStrings.submitStep,
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
                    padding: EdgeInsets.only(bottom: DS.s(24)),
                    children: [
                      SetupEntrance(
                        controller: _anim,
                        index: 0,
                        count: 3,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(14), DS.s(18), 0),
                          child: Column(children: [
                            Art3D(asset: ListingArt.clipboard, size: 72),
                            Gap.v(8),
                            Text(TaxiSetupStrings.checkYourTaxi, textAlign: TextAlign.center, style: Ink3D.text(22, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                            Gap.v(4),
                            Text(TaxiSetupStrings.afterApproval, textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                          ]),
                        ),
                      ),
                      if (t != null) ...[
                        SetupEntrance(
                          controller: _anim,
                          index: 1,
                          count: 3,
                          child: _summary(
                            key: const ValueKey('submit_vehicle'),
                            art: ListingArt.taxi,
                            title: TaxiSetupStrings.step1Title,
                            onTap: () => _edit(AppRoutes.taxiVehicle),
                            rows: [
                              (TaxiSetupStrings.vehicle, t.vehicleTypeName),
                              (TaxiSetupStrings.seats, t.seats?.toString()),
                              (TaxiSetupStrings.plate, t.plateDisplay),
                              (TaxiSetupStrings.phone, t.contactPhone == null ? null : TaxiSetupStrings.phoneDisplay(t.contactPhone!)),
                              (TaxiSetupStrings.base, t.locality.isEmpty ? null : t.locality),
                            ],
                            warning: t.identityDone ? null : TaxiSetupStrings.addLicence,
                          ),
                        ),
                        SetupEntrance(
                          controller: _anim,
                          index: 2,
                          count: 3,
                          child: _summary(
                            key: const ValueKey('submit_routes'),
                            art: ListingArt.flag,
                            title: TaxiSetupStrings.routesTitle,
                            onTap: () => _edit(AppRoutes.taxiRoutes),
                            rows: [
                              (TaxiSetupStrings.routes, '${t.routes.length}'),
                              (TaxiSetupStrings.localDayRate, t.localDayRate == null ? null : TaxiSetupStrings.dayRate(t.localDayRate!, t.localDayKm)),
                            ],
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
              primaryLabel: TaxiSetupStrings.submitForReview,
              primaryLoading: _ctrl.isSaving.value,
              onPrimary: _ctrl.isSaving.value || _ctrl.taxi.value == null ? null : _submit,
            )),
      ),
      Obx(() => _ctrl.isSaving.value ? const SetupBusy(message: TaxiSetupStrings.submitting, tone: KitTone.taxi, art: ListingArt.key) : const SizedBox.shrink()),
    ]);
    return Obx(() => PopScope(canPop: !_ctrl.isSaving.value, child: body));
  }

  Widget _summary({required Key key, required String art, required String title, required VoidCallback onTap, required List<(String, String?)> rows, String? warning}) {
    final shown = [for (final r in rows) (r.$1, r.$2 == null || r.$2!.isEmpty ? TaxiSetupStrings.missing : r.$2!)];
    return Padding(
      key: key,
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(18), DS.s(18), 0),
      child: Tap3D(
        onTap: onTap,
        label: '${TaxiSetupStrings.edit} $title',
        child: Container(
          padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(14), DS.s(16), DS.s(6)),
          decoration: BoxDecoration(color: Colors.white, borderRadius: DS.br(TaxiOwnerLook.card), boxShadow: DS.shadows(ShadowTokens.elev1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Art3D(asset: art, size: 26),
              Gap.h(10),
              Expanded(child: Text(title, style: Ink3D.text(15, FontWeight.w700, Ink3D.title, letterSpacing: 0))),
            ]),
            Gap.v(6),
            for (var i = 0; i < shown.length; i++) KeyValueRow(label: shown[i].$1, value: shown[i].$2, divider: i < shown.length - 1 || warning != null),
            if (warning != null)
              Padding(
                padding: EdgeInsets.symmetric(vertical: DS.gv(10)),
                child: Text(warning, style: Ink3D.text(12.5, FontWeight.w600, Form3D.errorText, letterSpacing: 0)),
              ),
          ]),
        ),
      ),
    );
  }
}
