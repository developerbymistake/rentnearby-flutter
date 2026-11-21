import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../design/design.dart';
import '../../../design/extra/ext_plans.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/money_format.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/plan/gate_keys.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/sheets/owner_confirm.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../calendar/taxi_calendar_widgets.dart';
import '../hub/taxi_hub_controller.dart';
import '../taxi_driver_deps.dart';
import '../widgets/taxi_widgets.dart' show TaxiPill, TaxiPillKind;
import 'choose_route_controller.dart';
import 'taxi_plan_visible_strings.dart';

/// Choose your route (o_tx_45 B): which route rings on Free after Plus ends or payment starts.
class TaxiPlanVisibleScreen extends StatefulWidget {
  const TaxiPlanVisibleScreen({super.key, this.controller});

  final ChooseRouteController? controller;

  @override
  State<TaxiPlanVisibleScreen> createState() => _TaxiPlanVisibleScreenState();
}

class _TaxiPlanVisibleScreenState extends State<TaxiPlanVisibleScreen> {
  late final ChooseRouteController c;
  late final bool _owns;
  Worker? _emptyWorker;

  @override
  void initState() {
    super.initState();
    _owns = widget.controller == null;
    c = widget.controller ?? Get.put(ChooseRouteController(), tag: ChooseRouteController.tag);
    if (!PlanGate.paymentOn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _leave(toHub: true));
      return;
    }
    _emptyWorker = ever<OwnerLoad<ChooseRouteState>>(c.load, (v) {
      if (v is OwnerLoadEmpty<ChooseRouteState>) _leave();
    });
    c.fetch();
  }

  @override
  void dispose() {
    _emptyWorker?.dispose();
    if (_owns && Get.isRegistered<ChooseRouteController>(tag: ChooseRouteController.tag)) {
      Get.delete<ChooseRouteController>(tag: ChooseRouteController.tag, force: true);
    }
    super.dispose();
  }

  void _leave({bool toHub = false}) {
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
    if (toHub) TaxiDriverDeps.openHub(section: 'routes');
  }

  Future<void> _back() async {
    final nav = Navigator.of(context);
    if (!c.dirty) {
      nav.maybePop();
      return;
    }
    if (await OwnerConfirm.discard(context) && nav.mounted) nav.pop();
  }

  Future<void> _save() async {
    final r = await c.save();
    if (!mounted) return;
    switch (r) {
      case ChooseRouteSave.done:
        TaxiDriverDeps.refreshHome();
        TaxiHubController.maybe?.reload();
        Navigator.of(context).pop();
      case ChooseRouteSave.nothingToSave:
        Navigator.of(context).pop();
      case ChooseRouteSave.offline:
      case ChooseRouteSave.failed:
        AppToast.error(OwnerSharedStrings.noConnection);
      case ChooseRouteSave.rateLimited:
        AppToast.info(OwnerSharedStrings.tooManyTries);
      case ChooseRouteSave.limit:
      case ChooseRouteSave.invalid:
      case ChooseRouteSave.notNeeded:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: OwnerLook.taxi.page,
        body: Column(
          children: [
            Obx(() {
              final s = c.state;
              return TaxiCalPageHeader(title: TaxiPlanVisibleStrings.title, subtitle: TaxiPlanVisibleStrings.sub(s?.limit ?? PlanGate.limit(PlanKey.routes)));
            }),
            Expanded(
              child: Obx(() {
                final load = c.load.value;
                c.selected.length;
                c.limitLine.value;
                return OwnerStateView<ChooseRouteState>(
                  load: load,
                  look: OwnerLook.taxi,
                  words: const OwnerStateWords(),
                  onRetry: c.fetch,
                  data: (context, s, stale) => _body(s, stale),
                );
              }),
            ),
            Obx(() {
              c.selected.length;
              final s = c.state;
              if (s == null) return const SizedBox.shrink();
              return Container(
                decoration: BoxDecoration(
                  color: DesignColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radius(22))),
                  boxShadow: DS.shadows(Ink3D.topEdge),
                ),
                padding: EdgeInsets.fromLTRB(DS.s(14), DS.s(10), DS.s(14), MediaQuery.viewPaddingOf(context).bottom + DS.s(12)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SingleFlightButton(
                    onPressed: c.ready ? _save : null,
                    builder: (ctx, onPressed, busy) => PrimaryButton(label: TaxiPlanVisibleStrings.save, tone: TaxiCal.kit, loading: busy, onPressed: onPressed),
                  ),
                  if (PlanGate.canUpgrade) ...[
                    Gap.v(8),
                    KeyedSubtree(
                      key: GateKeys.seePlus,
                      child: TaxiPill(label: OwnerSharedStrings.seePlus, kind: TaxiPillKind.outline, expand: true, onTap: PlanGate.seePlus),
                    ),
                  ],
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _body(ChooseRouteState s, bool stale) {
    final limit = c.limitLine.value;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: Gap.v(16)),
        SliverPadding(
          padding: DS.insets(l: 18, r: 18),
          sliver: SliverSemantics(
            label: TaxiPlanVisibleStrings.a11yGroup(s.target),
            sliver: SliverList.builder(
              itemCount: s.routes.length,
              itemBuilder: (context, i) {
                final r = s.routes[i];
                final on = c.selected.contains(r.id);
                final name = TaxiPlanVisibleStrings.route(r.fromName, r.toName);
                return TaxiCardSegment(
                  first: i == 0,
                  last: i == s.routes.length - 1,
                  child: Semantics(
                    button: true,
                    inMutuallyExclusiveGroup: s.target <= 1,
                    checked: on,
                    label: TaxiPlanVisibleStrings.a11yRow(name, r.roundTrip, r.fare, on),
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: stale ? null : () => c.toggle(r.id),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: DS.s(52)),
                        child: Padding(
                          padding: DS.sym(h: 16, v: 12),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w700, on ? Ink3D.title : Ink3D.grey, letterSpacing: 0)),
                                Text(TaxiPlanVisibleStrings.line(r.roundTrip, Money.exact(r.fare)), style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                              ]),
                            ),
                            Gap.h(10),
                            _Tick(on: on),
                          ]),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SliverPadding(padding: DS.insets(l: 18, r: 18), sliver: const SliverToBoxAdapter(child: TaxiShieldNote(text: TaxiPlanVisibleStrings.keptNote))),
        SliverToBoxAdapter(
          child: Padding(
            padding: DS.insets(l: 22, t: 10, r: 22),
            child: Text(
              limit == null ? TaxiPlanVisibleStrings.threeADay : (limit.isEmpty ? TaxiPlanVisibleStrings.threeADay : limit),
              style: Ink3D.text(11, limit == null ? FontWeight.w500 : FontWeight.w600, limit == null ? Ink3D.grey : OwnerLook.amber, letterSpacing: 0),
            ),
          ),
        ),
        if (stale)
          SliverToBoxAdapter(
            child: Padding(
              padding: DS.insets(l: 22, t: 8, r: 22),
              child: Text(OwnerSharedStrings.noConnection, style: Ink3D.text(11, FontWeight.w600, DesignColors.error, letterSpacing: 0)),
            ),
          ),
        SliverToBoxAdapter(child: Gap.v(24)),
      ],
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => Container(
        width: DS.s(22),
        height: DS.s(22),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: on ? PlanInk.check : null,
          color: on ? null : DesignColors.surface,
          border: on ? null : Border.all(color: DesignColors.border, width: DS.s(1.5)),
        ),
        child: on ? Icon(Icons.check_rounded, size: DS.s(15), color: DesignColors.onPrimary) : null,
      );
}
