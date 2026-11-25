import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_details.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/money_format.dart';
import '../../../widgets/tab_header.dart';
import '../../owner_core/data/owner_args.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../taxi/models/taxi_owner_model.dart';
import '../../taxi/setup/taxi_setup_controller.dart';
import '../home/taxi_driver_home_screen.dart';
import '../strings/taxi_hub_strings.dart';
import '../strings/taxi_photo_strings.dart';
import '../widgets/taxi_widgets.dart';
import 'taxi_display_photo_action.dart';
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
  late final TaxiSetupController _setup;
  bool _owns = false;
  final _scroll = ScrollController();
  final _routesKey = GlobalKey();
  final _localKey = GlobalKey();
  Worker? _targetWorker;

  @override
  void initState() {
    super.initState();
    _setup = TaxiSetupController.ensure();
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
    final children = <Widget>[];
    if (stale || _c.staleNotice.value) children.add(const OwnerStaleLine(text: TaxiHubStrings.showingLast));
    if (t.shownReportCount > 0) {
      children.add(TaxiRowsCard(rows: [
        TaxiRowData(
          art: ListingArt.warning,
          tint: TaxiLook.artTintRed,
          title: TaxiHubStrings.reports(t.shownReportCount),
          trailing: TaxiPill(label: TaxiHubStrings.view, kind: TaxiPillKind.outline, onTap: () => _push(AppRoutes.listingReports, args: {'listingId': t.id, 'listingType': 'Taxi', 'title': t.plateDisplay ?? TaxiHubStrings.taxiFallback})),
        ),
      ]));
    }
    children.add(TaxiPreviewCard(
      taxi: t,
      onView: t.isApproved && t.slug != null ? () => Get.toNamed(AppRoutes.taxiDetail, arguments: {'slug': t.slug, 'id': t.id}) : null,
    ));

    final first = t.routes.isEmpty ? null : t.routes.first;
    void openRoutes() => _push(AppRoutes.taxiRoutes, args: OwnerArgs.manage);
    children.add(KeyedSubtree(key: _routesKey, child: TaxiSectionTitle(title: TaxiHubStrings.routesTitle, meter: TaxiHubStrings.routeChip(t.routes.length))));
    children.add(TaxiRowsCard(margin: DS.insets(l: 18, t: 8, r: 18), rows: [
      TaxiRowData(
        art: ListingArt.pushpin,
        title: TaxiHubStrings.yourRoutes,
        sub: first == null ? null : TaxiHubStrings.routesLine(TaxiHubStrings.routeTitleOf(first.fromName, first.toName), t.routes.length - 1, t.minFare == null ? null : Money.exact(t.minFare ?? 0)),
        onTap: openRoutes,
        trailing: TaxiPill(label: TaxiHubStrings.open, kind: TaxiPillKind.outline, onTap: openRoutes),
      ),
    ]));

    children.add(KeyedSubtree(key: _localKey, child: const TaxiSectionTitle(title: TaxiHubStrings.localTitle)));
    children.add(TaxiRowsCard(margin: DS.insets(l: 18, t: 8, r: 18), rows: [_localRow(context, t)]));

    children.add(const TaxiSectionTitle(title: TaxiHubStrings.photosTitle));
    children.add(_PhotosCard(taxi: t, uploading: _setup.displayUploading));

    children.add(const TaxiSectionTitle(title: TaxiHubStrings.detailsTitle));
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
      padding: DS.insets(t: 6),
      child: Obx(() => TaxiDeleteRow(title: TaxiHubStrings.deleteTaxi, sub: TaxiHubStrings.removeListing, busy: _c.deleting.value, onDelete: () => _confirmDelete(t))),
    ));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
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

class _PhotosCard extends StatelessWidget {
  const _PhotosCard({required this.taxi, required this.uploading});

  final TaxiOwnerModel taxi;
  final RxBool uploading;

  @override
  Widget build(BuildContext context) {
    final url = taxi.displayPhotoUrl;
    return Padding(
      padding: DS.insets(l: 18, t: 8, r: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.white, borderRadius: TaxiLook.cardRadius(36), boxShadow: DS.shadows(Ink3D.softShadow)),
        child: Padding(
          padding: DS.insets(l: 16, t: 14, r: 16, b: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(TaxiPhotoStrings.photoCardTitle, style: Ink3D.text(13, FontWeight.w600, Ink3D.title, letterSpacing: 0))),
                  Gap.h(8),
                  Obx(() => TaxiPill(
                        label: TaxiPhotoStrings.manage,
                        kind: TaxiPillKind.outline,
                        busy: uploading.value,
                        onTap: () => TaxiDisplayPhotoAction.change(context),
                      )),
                ],
              ),
              Gap.v(12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Thumb(
                    label: TaxiPhotoStrings.displayTitle,
                    sub: url == null ? TaxiPhotoStrings.add : TaxiPhotoStrings.change,
                    tint: TaxiLook.artTintRed,
                    onTap: () => TaxiDisplayPhotoAction.change(context),
                    child: url == null ? Art3D(asset: ListingArt.camera, size: 34) : PhotoCircle(url: url, art: ListingArt.taxi, size: 56, photoSize: 56, artSize: 40),
                  ),
                  Gap.h(14),
                  _Thumb(
                    label: TaxiPhotoStrings.plateProof,
                    sub: TaxiPhotoStrings.private,
                    tint: TaxiLook.artTintAmber,
                    onTap: () => AppToast.info(TaxiPhotoStrings.plateLockedToast),
                    child: Art3D(asset: ListingArt.locked, size: 34),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.label, required this.sub, required this.tint, required this.onTap, required this.child});

  final String label;
  final String sub;
  final Color tint;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$label, $sub',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: DS.s(72),
            child: Column(
              children: [
                Container(
                  width: DS.s(56),
                  height: DS.s(56),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: tint, borderRadius: DS.circular(14)),
                  child: child,
                ),
                Gap.v(4),
                Text(label, textAlign: TextAlign.center, style: Ink3D.text(11, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                Text(sub, textAlign: TextAlign.center, style: Ink3D.text(11, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
              ],
            ),
          ),
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
