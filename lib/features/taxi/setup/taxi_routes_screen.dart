import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_taxi_owner.dart';
import '../../../utils/app_toast.dart';
import '../../owner_core/data/owner_args.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../owner_core/plan/gate_keys.dart';
import '../../owner_core/plan/owner_inactive.dart';
import '../../owner_core/plan/owner_manage_card.dart';
import '../../../controllers/plan_controller.dart';
import '../../owner_core/plan/plan_bindings.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_limit_sheet.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/plan/soft_lock.dart';
import '../../../utils/money_format.dart';
import '../../taxi_driver/hub/taxi_hub_controller.dart';
import '../../taxi_driver/hub/taxi_hub_sheets.dart';
import '../../taxi_driver/strings/taxi_gate_strings.dart';
import '../../taxi_driver/strings/taxi_hub_strings.dart';
import '../../taxi_driver/plan/taxi_plan_strings.dart';
import '../../taxi_driver/taxi_driver_deps.dart';
import '../models/taxi_owner_model.dart';
import '../../taxi_driver/strings/taxi_setup_strings.dart';
import '../taxi_option_sets.dart';
import 'taxi_rate_form.dart';
import 'taxi_routes_form.dart';
import 'taxi_setup_controller.dart';

class TaxiRoutesScreen extends StatefulWidget {
  const TaxiRoutesScreen({super.key, this.manage});

  final bool? manage;
  @override
  State<TaxiRoutesScreen> createState() => _TaxiRoutesScreenState();
}

class _TaxiRoutesScreenState extends State<TaxiRoutesScreen> with TickerProviderStateMixin {
  static final ListingTone _tone = ListingTone.coral;
  late final AnimationController _anim = SetupKit.controller(this);
  final _ctrl = TaxiSetupController.ensure();
  final _form = TaxiRoutesFormController(onboarding: false);
  final _rate = TaxiRateFormController();
  bool _savingRate = false;

  static const _max = TaxiOptionSets.maxRoutes;

  late final bool _manage = widget.manage ?? OwnerArgs.isManage(Get.arguments);
  TaxiHubController? _hub;
  bool _ownsHub = false;

  List<TaxiRouteDraft> get _routes => _form.routes;

  int get _planMax {
    final l = PlanGate.limit(PlanKey.routes);
    return l <= 0 ? 1 : (l > _max ? _max : l);
  }

  bool get _planFull => _routes.length >= _planMax;

  bool get _extraBlocked => PlanGate.loaded && _routes.isNotEmpty && _planFull;

  // Mirrors the server rule: adding above the plan value is refused, keeping an over-limit set passes.
  Future<bool> _planAllowsSave() async {
    if (!PlanGate.loaded) return true;
    if (_routes.length <= _planMax) return true;
    if (_routes.length <= (_ctrl.taxi.value?.routes.length ?? 0)) return true;
    if (PlanGate.canUpgrade) {
      await PlanGate.showLimit(context, TaxiGateStrings.routeGate());
    } else {
      AppToast.info(TaxiGateStrings.upTo(_planMax));
    }
    return false;
  }

  Future<void> _routeLimitRefused() async {
    final data = _ctrl.lastErrorData;
    if (data['canUpgrade'] == true) {
      final limit = data['limit'];
      await PlanLimitSheet.show(context, TaxiGateStrings.routeGate(free: limit is int ? limit : null));
      return;
    }
    final msg = _ctrl.lastErrorMessage;
    AppToast.info(msg != null && msg.isNotEmpty ? msg : TaxiGateStrings.upTo(_planMax));
  }

  Worker? _planWorker;

  void _watchPlan() {
    PlanBindings.ensure();
    if (!Get.isRegistered<PlanController>()) return;
    final pc = Get.find<PlanController>();
    _planWorker = everAll([pc.loaded, pc.myPlan], (_) {
      if (!mounted) return;
      // The blank extra form was opened on the pre-plan limit; close it once the real limit says full.
      setState(() {
        if (_form.formOpen && _form.editingIndex == null && _form.formBlank && _extraBlocked) _form.formOpen = false;
      });
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (_manage) {
      _hub = TaxiHubController.maybe;
      if (_hub == null) {
        _hub = Get.put(TaxiHubController(), tag: TaxiHubController.tag);
        _ownsHub = true;
      }
    }
    _form.seed(_ctrl.taxi.value);
    _watchPlan();
    _form.formOpen = !_manage && _routes.length < _max && !_extraBlocked;
    _rate.seed(_ctrl.taxi.value);
    _form.addListener(_changed);
    _rate.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SetupKit.play(_anim, context);
    });
  }

  @override
  void dispose() {
    if (_ownsHub && Get.isRegistered<TaxiHubController>(tag: TaxiHubController.tag)) Get.delete<TaxiHubController>(tag: TaxiHubController.tag, force: true);
    _planWorker?.dispose();
    _anim.dispose();
    _form.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<bool> _persistRate({required bool quiet}) async {
    if (_savingRate || _ctrl.isSaving.value) return false;
    final error = _rate.check();
    if (error != null) {
      AppToast.error(error);
      return false;
    }
    setState(() => _savingRate = true);
    final ok = await _ctrl.saveLocalRate(dayRate: _rate.dayRate, kmPerDay: _rate.kmPerDay);
    if (!mounted) return ok;
    setState(() => _savingRate = false);
    if (ok) _rate.seed(_ctrl.taxi.value);
    if (ok && !quiet) AppToast.success('Rate saved');
    return ok;
  }

  void _addAnother() {
    if (_addPlanFull) {
      if (PlanGate.canUpgrade) PlanGate.showLimit(context, TaxiGateStrings.routeGate());
      return;
    }
    if (_form.count >= _max) {
      AppToast.warning('You can add up to 10 routes');
      return;
    }
    if (_form.formOpen) {
      if (_form.formBlank) {
        AppToast.info('Fill this route first');
        return;
      }
      if (!_form.commitForm()) return;
    }
    _form.openForm();
  }

  Future<void> _save() async {
    if (_ctrl.isSaving.value || _savingRate) return;
    FocusScope.of(context).unfocus();
    if (!_form.commitForm()) return;
    if (_manage && _manageTaxi == null) {
      await _hub?.reload(force: true);
      if (!mounted || _manageTaxi == null) return;
      _form.replaceRoutes(_manageRoutes, keepDrafts: true);
      AppToast.info('Routes loaded. Check and save again.');
      return;
    }
    final rateDirty = _rate.editable && _rate.dirty;
    if (_routes.isEmpty && !rateDirty) {
      AppToast.error('Add at least one route');
      _form.openForm();
      _form.reveal(_form.formKey);
      return;
    }
    final rateError = _rate.editable && !_manage ? _rate.check() : null;
    if (rateError != null) {
      AppToast.error(rateError);
      return;
    }
    if (rateDirty && !await _persistRate(quiet: _routes.isNotEmpty)) return;
    if (!mounted) return;
    if (_routes.isEmpty) {
      Get.back();
      return;
    }
    if (!await _planAllowsSave() || !mounted) return;
    final ok = await _ctrl.saveRoutes(_form.payload(), quietLimit: true);
    if (!mounted) return;
    if (!ok) {
      if (_ctrl.lastErrorType == TaxiSetupController.routeLimitType) await _routeLimitRefused();
      return;
    }
    if (Get.isRegistered<PlanController>()) Get.find<PlanController>().invalidate().ignore();
    if (_manage) {
      setState(() => _form.dirty = false);
      await _hub?.reload(force: true);
      TaxiDriverDeps.refreshHome();
      AppToast.success('Routes saved');
      return;
    }
    Get.back();
    AppToast.success('Routes saved');
  }

  Future<void> _confirmDiscard() async {
    final ok = await showTaxiOwnerDialog(
      context,
      art: ListingArt.clipboard,
      title: 'Discard changes?',
      body: 'Unsaved changes will be lost.',
      cancelLabel: 'Keep Editing',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (ok == true) Get.back();
  }

  void _onBack() {
    if (_ctrl.isSaving.value) return;
    if (_form.dirty || !_form.formBlank || _rate.dirty) {
      _confirmDiscard();
    } else {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Stack(children: [
        Scaffold(
          backgroundColor: ListingPalette.coral.page,
          body: KitStatusBar(
            lightIcons: false,
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                _manage ? Obx(() => _header(TaxiHubStrings.usedOfRoutes((_hub?.load.value.valueOrNull ?? _ctrl.taxi.value)?.routes.length ?? 0, _planMax))) : _header(TaxiSetupStrings.routesStep),
                Expanded(
                  child: _manage ? _manageBody() : ListView(
                    padding: EdgeInsets.only(bottom: DS.s(24)),
                    children: [
                      SetupEntrance(controller: _anim, index: 0, count: 5, child: _meterCard()),
                      SetupEntrance(controller: _anim, index: 1, count: 5, child: TaxiRouteSummaries(controller: _form, tone: _tone)),
                      SetupEntrance(
                        controller: _anim,
                        index: 2,
                        count: 5,
                        child: Column(children: [TaxiRouteFormCard(controller: _form, tone: _tone), _addRow()]),
                      ),
                      SetupEntrance(controller: _anim, index: 3, count: 5, child: _tipRow()),
                      SetupEntrance(controller: _anim, index: 4, count: 5, child: TaxiLocalRateCard(controller: _rate, tone: _tone)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          bottomNavigationBar: _manage && !_form.formOpen ? null : Obx(() => FormFooter(
                tone: _tone,
                top: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const ToastDock(),
                  if (PlanGate.loaded)
                    Padding(
                      padding: EdgeInsets.only(bottom: DS.gv(8)),
                      child: Text(
                        TaxiSetupStrings.footerMeter(_routes.length, _planMax, free: PlanGate.canUpgrade),
                        key: const ValueKey('routes_footer_meter'),
                        textAlign: TextAlign.center,
                        style: Ink3D.text(12, FontWeight.w600, Form3D.muted, letterSpacing: 0),
                      ),
                    ),
                ]),
                primaryLabel: _form.formOpen ? TaxiSetupStrings.saveRoute : TaxiSetupStrings.save,
                primaryLoading: _ctrl.isSaving.value,
                onPrimary: _ctrl.isSaving.value ? null : _save,
              )),
        ),
        Obx(() => _ctrl.isSaving.value
            ? SetupBusy(message: _savingRate ? 'Saving rate...' : 'Saving routes...', tone: KitTone.taxi, art: ListingArt.compass)
            : const SizedBox.shrink()),
      ]),
    );
  }

  Widget _header(String subtitle) => PageHeader3D(
        tone: _tone,
        title: TaxiSetupStrings.routesTitle,
        subtitle: subtitle,
        art: ListingArt.compass,
        inlineTitle: true,
        onBack: _onBack,
      );

  Widget _meterCard() {
    if (!PlanGate.loaded) {
      return FormSectionCard(
        key: const ValueKey('routes_meter_skeleton'),
        tone: _tone,
        art: ListingArt.flag,
        title: TaxiSetupStrings.routes,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SkeletonBox(height: DS.s(6), radius: DS.radius(6)),
          Gap.v(10),
          SkeletonBox(height: DS.s(12), width: DS.s(160), radius: DS.radius(6)),
        ]),
      );
    }
    final used = _routes.length;
    final limit = _planMax;
    final free = PlanGate.canUpgrade;
    final full = free && _planFull;
    final p = ListingPalette.coral;
    return FormSectionCard(
      tone: _tone,
      art: ListingArt.flag,
      title: TaxiSetupStrings.routes,
      trailing: Container(
        key: const ValueKey('routes_meter_chip'),
        padding: DS.sym(h: 9, v: 3),
        decoration: BoxDecoration(color: p.tint, borderRadius: DS.br(CardRadius.pill)),
        child: Text(TaxiSetupStrings.meterChip(used, limit, free: free), style: Ink3D.text(11, FontWeight.w700, p.text, letterSpacing: 0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: DS.br(CardRadius.pill),
          child: LinearProgressIndicator(
            value: limit <= 0 ? 0 : (used / limit).clamp(0.0, 1.0),
            minHeight: DS.s(6),
            backgroundColor: p.page,
            valueColor: AlwaysStoppedAnimation(p.g2),
          ),
        ),
        Gap.v(10),
        Row(children: [
          Expanded(
            child: Text(
              full && _form.formOpen ? TaxiGateStrings.lineFree(limit, TaxiGateStrings.plusRoutes) : TaxiSetupStrings.savedLine(used, limit, free: free),
              key: const ValueKey('routes_meter_line'),
              style: FieldMessage.helperStyle.copyWith(fontSize: DS.f(12)),
            ),
          ),
          if (full && _form.formOpen) ...[Gap.h(8), SeePlusButton(taxi: true, onPressed: () => PlanGate.showLimit(context, TaxiGateStrings.routeGate()))],
        ]),
      ]),
    );
  }

  Widget _tipRow() {
    if (!PlanGate.canUpgrade || !_planFull || _form.formOpen) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(20), DS.s(18), 0),
      child: KeyedSubtree(
        key: GateKeys.softCard,
        child: SoftLock.row(
          text: TaxiGateStrings.freePlanTip(_planMax, TaxiGateStrings.plusRoutes),
          taxi: true,
          onTap: () => PlanGate.showLimit(context, TaxiGateStrings.routeGate()),
        ),
      ),
    );
  }

  bool get _addPlanFull => PlanGate.loaded && _form.count >= _planMax;

  TaxiOwnerModel? get _manageTaxi => _hub?.taxi ?? _ctrl.taxi.value;

  List<TaxiRouteModel> get _manageRoutes => _manageTaxi?.routes ?? const [];

  bool get _manageFull => (PlanGate.loaded && _manageRoutes.length >= _planMax) || _manageRoutes.length >= _max;

  bool _reviewLocked() {
    if (_manageTaxi?.isPendingReview != true) return false;
    AppToast.info(TaxiHubStrings.underReview);
    return true;
  }

  // PUT /taxis/me/routes replaces the whole set: never seed the form from a list that was not loaded.
  void _openManageForm() {
    if (_manageTaxi == null) {
      _hub?.reload(force: true);
      return;
    }
    if (_reviewLocked()) return;
    if (_form.formOpen) {
      _form.reveal(_form.formKey);
      return;
    }
    _form.replaceRoutes(_manageRoutes);
    _form.clearForm();
    _form.openForm();
    _form.reveal(_form.formKey);
  }

  Widget _manageBody() {
    final hub = _hub;
    return Obx(() {
      final t = hub?.load.value.valueOrNull ?? _ctrl.taxi.value;
      if (t == null) {
        return ListView(
          padding: DS.insets(l: 18, t: 12, r: 18, b: 24),
          children: [
            OwnerStateView<TaxiOwnerModel>(
              key: const ValueKey('routes_manage_state'),
              load: hub?.load.value ?? const OwnerLoadLoading<TaxiOwnerModel>(),
              look: OwnerLook.taxi,
              words: const OwnerStateWords(),
              data: (_, __, ___) => const SizedBox.shrink(),
              onRetry: () => hub?.reload(force: true),
            ),
          ],
        );
      }
      final routes = t.routes;
      final hidden = t.hiddenRoutes;
      final full = _manageFull;
      final free = PlanGate.limit(PlanKey.routes);
      return ListView(
        padding: EdgeInsets.only(bottom: DS.s(24)),
        children: [
          Padding(
            padding: DS.insets(l: 18, t: 12, r: 18),
            child: SoftLock.strip(
              text: TaxiGateStrings.lineFree(free, TaxiGateStrings.plusRoutes),
              taxi: true,
              onTap: () => PlanGate.showLimit(context, TaxiGateStrings.routeGate()),
            ),
          ),
          for (var i = 0; i < routes.length; i++) _manageCard(i + 1, routes[i]),
          for (var i = 0; i < hidden.length; i++)
            OwnerInactiveCard(
              taxi: true,
              eyebrow: TaxiHubStrings.routeEyebrow(routes.length + i + 1),
              title: TaxiHubStrings.routeTitleOf(hidden[i].fromName, hidden[i].toName),
              sub: '${TaxiHubStrings.fareLine(Money.exact(hidden[i].fare))} · ${hidden[i].roundTrip ? TaxiHubStrings.roundTrip : TaxiHubStrings.oneWay}',
              reason: TaxiGateStrings.routeInactive(free),
              editLabels: const [TaxiHubStrings.editFare, TaxiHubStrings.editRouteTitle],
              busy: hub?.busy.value ?? false,
              onDelete: () => hub?.deleteHiddenRoute(hidden[i].id),
            ),
          if (hidden.isNotEmpty)
            Padding(
              padding: DS.insets(l: 18, t: 10, r: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextLink(label: TaxiPlanStrings.chooseYourRoute, tone: KitTone.taxiDriver, onTap: () => TaxiDriverDeps.openChooseRoute()),
              ),
            ),
          TaxiRouteFormCard(controller: _form, tone: _tone),
          Padding(
            padding: DS.insets(l: 18, t: 18, r: 18),
            child: KeyedSubtree(
              key: const ValueKey('routes_manage_add'),
              child: GradientPillButton(
                tone: ListingTone.coral,
                label: TaxiHubStrings.addRoute,
                enabled: PlanGate.addEnabled(full),
                onTap: () => PlanGate.addTap(context, full: full, gate: TaxiGateStrings.routeGate, onAdd: _openManageForm),
              ),
            ),
          ),
          if (full && !PlanGate.canUpgrade)
            Padding(
              padding: DS.insets(l: 18, t: 8, r: 18),
              child: Text(
                TaxiGateStrings.upTo(PlanGate.loaded ? _planMax : _max),
                key: const ValueKey('routes_manage_full_line'),
                textAlign: TextAlign.center,
                style: FieldMessage.helperStyle.copyWith(fontSize: DS.f(12)),
              ),
            ),
        ],
      );
    });
  }

  Widget _manageCard(int n, TaxiRouteModel r) {
    final hub = _hub;
    return OwnerManageCard(
      eyebrow: TaxiHubStrings.routeEyebrow(n),
      chip: r.roundTrip ? TaxiHubStrings.roundTrip : TaxiHubStrings.oneWay,
      title: TaxiHubStrings.routeTitleOf(r.fromName, r.toName),
      sub: TaxiHubStrings.fareLine(Money.exact(r.fare)),
      actions: hub == null
          ? const []
          : [
              GradientPillButton(tone: ListingTone.coral, label: TaxiHubStrings.editFare, height: 42, fontSize: 12.5, onTap: () => TaxiEditFareSheet.show(context, hub, r)),
              WhitePillButton(tone: ListingTone.coral, label: TaxiHubStrings.editRouteTitle, height: 42, fontSize: 12.5, onTap: () => TaxiEditRouteSheet.show(context, hub, r)),
              WhitePillButton(tone: ListingTone.coral, label: TaxiHubStrings.delete, height: 42, fontSize: 12.5, danger: true, onTap: () => TaxiRouteActions.delete(context, hub, r)),
            ],
    );
  }

  Widget _addRow() {
    final n = _form.count;
    final soft = _addPlanFull && PlanGate.canUpgrade;
    final enabled = soft || (!_addPlanFull && n < _max);
    return KeyedSubtree(
      key: soft ? const ValueKey('routes_add_locked') : null,
      child: DashedAddRow3D(
        tone: _tone,
        label: TaxiGateStrings.addAnother,
        trailing: soft ? TaxiSetupStrings.plus : (PlanGate.loaded ? '$n of $_planMax' : (n >= _max ? 'Limit reached' : null)),
        enabled: enabled,
        onTap: _addAnother,
      ),
    );
  }
}
