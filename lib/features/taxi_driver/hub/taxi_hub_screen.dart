import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_details.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/money_format.dart';
import '../../../widgets/tab_header.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/plan/gate_keys.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../taxi/models/taxi_owner_model.dart';
import '../home/taxi_driver_home_screen.dart';
import '../strings/taxi_gate_strings.dart';
import '../strings/taxi_hub_strings.dart';
import '../taxi_driver_deps.dart';
import '../widgets/taxi_widgets.dart';
import 'taxi_hub_controller.dart';
import 'taxi_hub_sheets.dart';
import 'taxi_preview_card.dart';

class TaxiHubScreen extends StatefulWidget {
  const TaxiHubScreen({super.key, this.root = false, this.controller});

  final bool root;
  final TaxiHubController? controller;

  @override
  State<TaxiHubScreen> createState() => _TaxiHubScreenState();
}

class _TaxiHubScreenState extends State<TaxiHubScreen> {
  late final TaxiHubController _c;
  bool _owns = false;
  final _scroll = ScrollController();
  final _routesKey = GlobalKey();
  final _localKey = GlobalKey();
  Worker? _targetWorker;

  @override
  void initState() {
    super.initState();
    final given = widget.controller ?? TaxiHubController.maybe;
    if (given != null) {
      _c = given;
    } else {
      _c = Get.put(TaxiHubController(), tag: TaxiHubController.tag);
      _owns = true;
    }
    _targetWorker = ever<String?>(_c.scrollTarget, (t) {
      if (t == null) return;
      _c.scrollTarget.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = t == 'local' ? _localKey : _routesKey;
        final ctx = key.currentContext;
        if (ctx != null && ctx.mounted) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250));
      });
    });
  }

  @override
  void dispose() {
    _targetWorker?.dispose();
    _scroll.dispose();
    if (_owns && Get.isRegistered<TaxiHubController>(tag: TaxiHubController.tag)) Get.delete<TaxiHubController>(tag: TaxiHubController.tag, force: true);
    super.dispose();
  }

  Future<void> _push(String route, {Object? args}) async {
    await Get.toNamed(route, arguments: args);
    if (mounted) _c.reload();
  }

  bool _locked(TaxiOwnerModel t) {
    if (!t.isPendingReview) return false;
    AppToast.info(TaxiHubStrings.underReview);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ListingPalette.coral.page,
      body: Obx(() {
        final load = _c.load.value;
        final t = load.valueOrNull;
        final subtitle = t != null ? (t.plateDisplay ?? t.numberPlate ?? '') : (load is OwnerLoadEmpty<TaxiOwnerModel> ? TaxiHubStrings.noTaxiYet : '');
        return TabHeaderFrame(
          title: TaxiHubStrings.title,
          subtitle: subtitle,
          color: ListingPalette.coral.page,
          child: RefreshIndicator(
            color: ListingPalette.coral.g2,
            onRefresh: _c.reload,
            child: SingleChildScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.only(bottom: BarMetrics.bodyBottomOf(context) + DS.s(8)),
              child: _body(context, load),
            ),
          ),
        );
      }),
    );
  }

  Widget _body(BuildContext context, OwnerLoad<TaxiOwnerModel> load) {
    return switch (load) {
      OwnerLoadLoading<TaxiOwnerModel>() => const _HubSkeleton(),
      OwnerLoadEmpty<TaxiOwnerModel>() => TaxiErrorCard(
          art: ListingArt.taxi,
          title: TaxiHubStrings.noTaxiYet,
          message: TaxiHubStrings.noTaxiBody,
          action: TaxiHubStrings.setUpTaxi,
          onAction: TaxiHomeActions.startSetup,
          margin: DS.insets(l: 18, t: 28, r: 18),
        ),
      OwnerLoadData<TaxiOwnerModel>(:final value, :final stale) => _content(context, value, stale),
      _ => TaxiErrorCard(
          art: ListingArt.warning,
          title: TaxiHubStrings.couldNotLoad,
          message: TaxiHubStrings.checkConnection,
          action: TaxiHubStrings.tryAgain,
          onAction: _c.reload,
          margin: DS.insets(l: 18, t: 28, r: 18),
        ),
    };
  }

  Widget _content(BuildContext context, TaxiOwnerModel t, bool stale) {
    final limit = t.routesMeter?.limit ?? t.meter('Routes')?.limit ?? PlanGate.limit(PlanKey.routes);
    final used = t.routes.length;
    final locked = PlanGate.canUpgrade && used >= limit;
    final off = !PlanGate.paymentOn;
    final children = <Widget>[];
    if (stale || _c.staleNotice.value) children.add(const OwnerStaleLine(text: TaxiHubStrings.showingLast));
    if (t.shownReportCount > 0) {
      children.add(TaxiRowsCard(rows: [
        TaxiRowData(
          art: ListingArt.warning,
          tint: TaxiLook.artTintRed,
          title: TaxiHubStrings.reports(t.shownReportCount),
          trailing: TaxiPill(label: TaxiHubStrings.view, kind: TaxiPillKind.white, onTap: () => _push(AppRoutes.listingReports, args: {'listingId': t.id, 'listingType': 'Taxi', 'title': t.plateDisplay ?? TaxiHubStrings.taxiFallback})),
        ),
      ]));
    }
    children.add(TaxiPreviewCard(
      taxi: t,
      onView: t.isApproved && t.slug != null ? () => Get.toNamed(AppRoutes.taxiDetail, arguments: {'slug': t.slug, 'id': t.id}) : null,
      onShare: t.isApproved && t.slug != null ? () => TaxiHomeActions.share(context) : null,
    ));

    children.add(KeyedSubtree(key: _routesKey, child: TaxiLabel(text: off ? TaxiHubStrings.routesHeaderOff(used) : TaxiHubStrings.routesHeader(used, limit))));
    final rows = <TaxiRowData>[
      for (final r in t.routes) _routeRow(context, t, r, used),
      for (final r in t.hiddenRoutes)
        TaxiRowData(
          art: ListingArt.locked,
          tint: TaxiLook.artTintAmber,
          locked: true,
          title: TaxiHubStrings.routeTitleOf(r.fromName, r.toName),
          sub: TaxiHubStrings.hiddenOnFree,
          onTap: () => TaxiDriverDeps.openChooseRoute(),
        ),
    ];
    if (!t.isPendingReview) {
      final plus = TaxiGateStrings.plusRoutes;
      final more = plus - limit;
      if (locked) {
        rows.add(TaxiRowData(
          art: ListingArt.locked,
          tint: TaxiLook.artTintAmber,
          locked: true,
          title: TaxiGateStrings.moreRoutes(more < 1 ? 1 : more),
          sub: TaxiGateStrings.addUpTo(plus),
          onTap: PlanGate.seePlus,
          trailing: KeyedSubtree(key: GateKeys.softRow, child: TaxiPill(label: TaxiHubStrings.seePlus, kind: TaxiPillKind.coral, onTap: PlanGate.seePlus)),
        ));
      } else if (used >= limit && used > 0) {
        rows.add(TaxiRowData(
          art: ListingArt.compass,
          title: TaxiHubStrings.addRoute,
          sub: TaxiHubStrings.allUsed(limit),
          trailing: const _FullChip(),
        ));
      } else if (used < limit) {
        rows.add(TaxiRowData(
          art: ListingArt.compass,
          title: TaxiHubStrings.addRoute,
          sub: used > 1 ? TaxiHubStrings.usedOf(used, limit) : null,
          onTap: () => _push(AppRoutes.taxiRoutes),
          trailing: TaxiPill(label: TaxiHubStrings.add, kind: TaxiPillKind.outline, onTap: () => _push(AppRoutes.taxiRoutes)),
        ));
      }
    }
    children.add(TaxiRowsCard(rows: rows, margin: DS.insets(l: 18, t: 8, r: 18)));

    children.add(KeyedSubtree(key: _localKey, child: const TaxiLabel(text: TaxiHubStrings.localHeader)));
    children.add(TaxiRowsCard(margin: DS.insets(l: 18, t: 8, r: 18), rows: [_localRow(context, t)]));

    children.add(const TaxiLabel(text: TaxiHubStrings.vehicleHeader));
    children.add(TaxiRowsCard(margin: DS.insets(l: 18, t: 8, r: 18), rows: [
      TaxiRowData(
        art: DetailArt.automobile,
        tint: TaxiLook.artTintRed,
        title: TaxiHubStrings.vehicleLine(t.vehicleTypeName ?? TaxiHubStrings.taxiFallback, t.seats),
        sub: TaxiHubStrings.vehicleHint,
        trailing: TaxiPill(label: TaxiHubStrings.edit, kind: TaxiPillKind.outline, onTap: () => _editVehicle(t)),
        onTap: () => _editVehicle(t),
      ),
    ]));

    children.add(Padding(
      padding: DS.insets(l: 18, t: 20, r: 18),
      child: Obx(() => TaxiPill(label: TaxiHubStrings.deleteTaxi, kind: TaxiPillKind.danger, expand: true, busy: _c.deleting.value, onTap: () => _confirmDelete(t))),
    ));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  TaxiRowData _routeRow(BuildContext context, TaxiOwnerModel t, TaxiRouteModel r, int used) {
    void editFare() {
      if (_locked(t)) return;
      TaxiEditFareSheet.show(context, _c, r);
    }

    return TaxiRowData(
      art: ListingArt.pushpin,
      title: TaxiHubStrings.routeTitleOf(r.fromName, r.toName),
      sub: TaxiHubStrings.routeSub(r.roundTrip, Money.exact(r.fare)),
      onTap: editFare,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TaxiPill(label: TaxiHubStrings.editFare, kind: TaxiPillKind.outline, onTap: editFare),
          _RouteMenu(
            onEdit: () {
              if (_locked(t)) return;
              TaxiEditRouteSheet.show(context, _c, r);
            },
            onDelete: () => _deleteRoute(context, t, r, used),
          ),
        ],
      ),
    );
  }

  TaxiRowData _localRow(BuildContext context, TaxiOwnerModel t) {
    void edit() {
      if (_locked(t)) return;
      TaxiLocalRateSheet.show(context, _c);
    }

    final trailing = TaxiPill(label: TaxiHubStrings.edit, kind: TaxiPillKind.outline, onTap: edit);
    if (!t.hasLocalRate) {
      return TaxiRowData(art: ListingArt.mountain, tint: TaxiLook.artTintAmber, title: TaxiHubStrings.localNotSet, sub: TaxiHubStrings.localNotSetSub, trailing: trailing, onTap: edit);
    }
    return TaxiRowData(
      art: ListingArt.mountain,
      tint: TaxiLook.artTintAmber,
      title: TaxiHubStrings.dayRateLine(Money.exact(t.localDayRate ?? 0)),
      sub: t.localDayKm == null ? null : TaxiHubStrings.kmLine(t.localDayKm ?? 0),
      trailing: trailing,
      onTap: edit,
    );
  }

  void _editVehicle(TaxiOwnerModel t) {
    if (_locked(t)) return;
    _push(AppRoutes.taxiVehicle);
  }

  Future<void> _deleteRoute(BuildContext context, TaxiOwnerModel t, TaxiRouteModel r, int used) async {
    if (_locked(t)) return;
    if (used <= 1) {
      AppToast.info(TaxiHubStrings.lastRoute);
      return;
    }
    final ok = await TaxiConfirm.ask(
      context,
      title: TaxiHubStrings.deleteRouteTitle,
      body: TaxiHubStrings.deleteRouteBody,
      confirm: TaxiHubStrings.deleteRouteConfirm,
      cancel: TaxiHubStrings.keep,
    );
    if (!ok) return;
    await _c.saveRoutes([for (final x in t.routes) if (x.id != r.id) x.toPayload()], TaxiHubStrings.routeDeleted);
  }

  Future<void> _confirmDelete(TaxiOwnerModel t) async {
    final n = t.activeBookingCount;
    final ok = await TaxiConfirm.ask(
      context,
      title: TaxiHubStrings.deleteTitle,
      body: '${TaxiHubStrings.deleteBody}${n > 0 ? TaxiHubStrings.deleteBookings(n) : ''}',
      confirm: TaxiHubStrings.delete,
      cancel: TaxiHubStrings.keep,
    );
    if (ok) await _c.deleteTaxi();
  }
}

class _RouteMenu extends StatelessWidget {
  const _RouteMenu({required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
        tooltip: TaxiHubStrings.moreOptions,
        icon: Icon(Icons.more_vert_rounded, size: DS.s(22), color: Ink3D.grey),
        onSelected: (v) => v == 0 ? onEdit() : onDelete(),
        itemBuilder: (_) => [
          PopupMenuItem(value: 0, child: Text(TaxiHubStrings.menuEditRoute)),
          PopupMenuItem(value: 1, child: Text(TaxiHubStrings.menuDeleteRoute)),
        ],
      );
}

class _FullChip extends StatelessWidget {
  const _FullChip();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: OwnerLook.greySoft, borderRadius: DS.circular(10)),
        child: Padding(
          padding: DS.sym(h: 10, v: 4),
          child: Text(TaxiHubStrings.full, style: Ink3D.text(11, FontWeight.w700, Ink3D.grey, letterSpacing: 0)),
        ),
      );
}

class _HubSkeleton extends StatelessWidget {
  const _HubSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.insets(l: 18, t: 24, r: 18),
        child: Column(
          children: [
            SkeletonBox(height: DS.s(160), radius: DS.radius(24)),
            Gap.v(20),
            SkeletonBox(height: DS.s(140), radius: DS.radius(24)),
            Gap.v(16),
            SkeletonBox(height: DS.s(90), radius: DS.radius(24)),
          ],
        ),
      );
}
