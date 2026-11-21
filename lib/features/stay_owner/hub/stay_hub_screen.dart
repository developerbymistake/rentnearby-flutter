import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/money_format.dart';
import '../../../widgets/tab_header.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/plan/gate_keys.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../stay/models/stay_owner_model.dart';
import '../home/stay_owner_home_screen.dart';
import '../strings/stay_format.dart';
import '../strings/stay_gate_strings.dart';
import '../strings/stay_hub_strings.dart';
import '../widgets/stay_widgets.dart';
import 'stay_edit_price_sheet.dart';
import 'stay_hub_controller.dart';
import 'stay_preview_card.dart';

class StayHubScreen extends StatefulWidget {
  const StayHubScreen({super.key, this.root = false, this.controller});

  final bool root;
  final StayHubController? controller;

  @override
  State<StayHubScreen> createState() => _StayHubScreenState();
}

class _StayHubScreenState extends State<StayHubScreen> {
  late final StayHubController _c;
  bool _owns = false;
  final _scroll = ScrollController();
  final _roomsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final given = widget.controller ?? StayHubController.maybe;
    if (given != null) {
      _c = given;
    } else {
      _c = Get.put(StayHubController(), tag: StayHubController.tag);
      _owns = true;
    }
    ever<String?>(_c.scrollTarget, (t) {
      if (t == null) return;
      _c.scrollTarget.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _roomsKey.currentContext;
        if (t == 'rooms' && ctx != null && ctx.mounted) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250));
      });
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    if (_owns && Get.isRegistered<StayHubController>(tag: StayHubController.tag)) Get.delete<StayHubController>(tag: StayHubController.tag, force: true);
    super.dispose();
  }

  Future<void> _push(String route, {Object? args}) async {
    await Get.toNamed(route, arguments: args);
    if (mounted) _c.reload();
  }

  bool _locked(StayOwnerModel s) {
    if (!s.isPendingReview) return false;
    AppToast.info(StayHubStrings.underReview);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ListingPalette.forest.page,
      body: Obx(() {
        final load = _c.load.value;
        final s = load.valueOrNull;
        final subtitle = s != null ? (s.name ?? '') : (load is OwnerLoadEmpty<StayOwnerModel> ? StayHubStrings.noStayYet : '');
        return TabHeaderFrame(
          title: StayHubStrings.title,
          subtitle: subtitle,
          color: ListingPalette.forest.page,
          child: RefreshIndicator(
            color: ListingPalette.forest.g2,
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

  Widget _body(BuildContext context, OwnerLoad<StayOwnerModel> load) {
    return switch (load) {
      OwnerLoadLoading<StayOwnerModel>() => const _HubSkeleton(),
      OwnerLoadEmpty<StayOwnerModel>() => StayErrorCard(
          art: ListingArt.stay,
          title: StayHubStrings.noStayYet,
          message: StayHubStrings.noStayBody,
          action: StayHubStrings.setUpStay,
          onAction: _setUp,
          margin: DS.insets(l: 18, t: 28, r: 18),
        ),
      OwnerLoadData<StayOwnerModel>(:final value) => _content(context, value),
      _ => StayErrorCard(
          art: ListingArt.warning,
          title: StayHubStrings.couldNotLoad,
          message: StayHubStrings.checkConnection,
          action: StayHubStrings.tryAgain,
          onAction: _c.reload,
          margin: DS.insets(l: 18, t: 28, r: 18),
        ),
    };
  }

  void _setUp() {
    if (Get.isRegistered<AuthController>()) Get.find<AuthController>().setOwnerShellEmpty(false);
    Get.offAllNamed(AppRoutes.staySetup);
  }

  Widget _content(BuildContext context, StayOwnerModel s) {
    final roomLimit = s.meter('RoomTypes')?.limit ?? PlanGate.limit(PlanKey.roomTypes);
    final photoLimit = s.meter('Photos')?.limit ?? PlanGate.limit(PlanKey.photos);
    final roomsLocked = PlanGate.locks(PlanKey.roomTypes, s.rooms.length);
    final photosLocked = PlanGate.locks(PlanKey.photos, s.photos.length);
    final children = <Widget>[];

    final strip = _strip(s);
    if (strip != null) children.add(strip);
    if (s.reportCount > 0) {
      children.add(StayRowsCard(rows: [
        StayRowData(
          art: ListingArt.warning,
          tint: StayLook.artTintRed,
          title: StayHubStrings.reports(s.reportCount),
          trailing: StayPill(label: StayHubStrings.view, kind: StayPillKind.white, onTap: () => _push(AppRoutes.listingReports, args: {'listingId': s.id, 'listingType': 'Stay', 'title': s.name ?? StayHubStrings.stayFallback})),
        ),
      ]));
    }
    children.add(StayPreviewCard(
      stay: s,
      onView: s.isApproved ? () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': s.id}) : null,
      onShare: s.isApproved && s.slug != null ? () => StayHomeActions.share(context) : null,
    ));

    children.add(KeyedSubtree(key: _roomsKey, child: StaySectionTitle(title: StayHubStrings.roomsAndPrices, meter: StayHubStrings.meter(s.rooms.length, roomLimit))));
    final roomRows = <StayRowData>[
      for (final r in s.rooms)
        StayRowData(
          art: ListingArt.bed,
          title: r.label,
          sub: StayHubStrings.roomSub(Money.exact(r.pricePerNight), r.maxGuests),
          onTap: () => _editPrice(context, s, r),
          trailing: StayPill(label: StayHubStrings.editPrice, kind: StayPillKind.white, onTap: () => _editPrice(context, s, r)),
        ),
      for (final r in s.hiddenRooms)
        StayRowData(
          art: ListingArt.locked,
          tint: StayLook.artTintAmber,
          locked: true,
          title: r.label,
          sub: StayHubStrings.hiddenOnFree,
        ),
    ];
    if (!s.isPendingReview) {
      if (roomsLocked) {
        roomRows.add(StayRowData(
          art: ListingArt.locked,
          tint: StayLook.artTintAmber,
          locked: true,
          title: StayHubStrings.addRoomType,
          sub: StayHubStrings.plusCanList(PlanKeys.plusSeed[PlanKey.roomTypes] ?? roomLimit),
          onTap: () => PlanGate.showLimit(context, StayGateStrings.roomGate()),
          trailing: KeyedSubtree(key: GateKeys.softRow, child: StayPill(label: StayHubStrings.seePlus, kind: StayPillKind.indigo, onTap: () => PlanGate.showLimit(context, StayGateStrings.roomGate()))),
        ));
      } else if (s.rooms.length < roomLimit) {
        roomRows.add(StayRowData(
          art: ListingArt.bed,
          title: StayHubStrings.addRoomType,
          sub: s.rooms.length > 1 ? StayHubStrings.usedOf(s.rooms.length, roomLimit) : null,
          onTap: () => _push(AppRoutes.stayRooms),
          trailing: StayPill(label: StayHubStrings.add, kind: StayPillKind.outline, onTap: () => _push(AppRoutes.stayRooms)),
        ));
      }
    }
    children.add(StayRowsCard(rows: roomRows, margin: DS.insets(l: 18, t: 12, r: 18)));

    children.add(StaySectionTitle(title: StayHubStrings.specialPrices, meter: _specialMeter(s)));
    children.add(StayRowsCard(rows: [_specialRow(s)], margin: DS.insets(l: 18, t: 12, r: 18)));

    children.add(StaySectionTitle(title: StayHubStrings.photos, meter: StayHubStrings.meter(s.photos.length, photoLimit)));
    children.add(_photosCard(context, s, photoLimit, photosLocked));

    children.add(StaySectionTitle(title: StayHubStrings.calendar, meter: StayHubStrings.bookingsThisMonth(s.calendarRow?.thisMonthCount ?? 0)));
    children.add(StayRowsCard(rows: [_calendarRow(s)], margin: DS.insets(l: 18, t: 12, r: 18)));

    children.add(const StaySectionTitle(title: StayHubStrings.stayDetails));
    children.add(StayRowsCard(margin: DS.insets(l: 18, t: 12, r: 18), rows: [
      StayRowData(
        art: ListingArt.memo,
        title: StayHubStrings.basicDetails,
        sub: s.pendingEdit != null ? StayHubStrings.basicDetailsPending : StayHubStrings.basicDetailsSub,
        trailing: StayPill(label: StayHubStrings.edit, kind: StayPillKind.outline, onTap: () => _editBasic(s)),
        onTap: () => _editBasic(s),
      ),
      StayRowData(
        art: ListingArt.clipboard,
        title: StayHubStrings.rules,
        sub: StayHubStrings.rulesSub,
        trailing: StayPill(label: StayHubStrings.edit, kind: StayPillKind.outline, onTap: () => _editRules(s)),
        onTap: () => _editRules(s),
      ),
      StayRowData(
        art: ListingArt.key,
        title: StayHubStrings.upiWhatsApp,
        sub: StayHubStrings.upiWhatsAppSub,
        trailing: StayPill(label: StayHubStrings.edit, kind: StayPillKind.outline, onTap: () => _push(AppRoutes.stayShareDetails)),
        onTap: () => _push(AppRoutes.stayShareDetails),
      ),
    ]));

    children.add(Padding(
      padding: DS.insets(l: 18, t: 20, r: 18),
      child: Obx(() => StayPill(label: StayHubStrings.deleteStay, kind: StayPillKind.danger, expand: true, busy: _c.deleting.value, onTap: () => _confirmDelete(s))),
    ));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget? _strip(StayOwnerModel s) {
    final pending = s.pendingEdit;
    if (pending != null) {
      final words = [if (pending.touchesName) 'Name', if (pending.touchesRegistration) 'Registration', if (pending.touchesLocation) 'Location'];
      final text = words.length == 1 ? StayHubStrings.pendingStrip(words.first, s.name ?? '') : StayHubStrings.pendingStripMany;
      return StayStrip(art: ListingArt.memo, text: text, fill: StayLook.indigoSoft, ink: StayLook.indigoText);
    }
    final result = s.lastEditResult;
    if (result == null) return null;
    if (result.approved) {
      final nameOnly = result.fieldsChanged.length == 1 && result.fieldsChanged.first == 'name';
      return StayStrip(art: ListingArt.stay, text: StayHubStrings.approvedStrip(nameOnly ? s.name : null), fill: StayLook.greenSoft, ink: StayLook.greenText);
    }
    return StayStrip(
      art: ListingArt.warning,
      text: StayHubStrings.rejectedStrip(result.reason),
      fill: StayLook.redSoft,
      ink: StayLook.redText,
      action: StayHubStrings.editAgain,
      onAction: () => _push(AppRoutes.stayLiveEdit),
    );
  }

  String _specialMeter(StayOwnerModel s) {
    final row = s.specialPricesRow;
    final limit = row?.limit ?? PlanGate.limit(PlanKey.specialPrices);
    return StayHubStrings.meter(row?.count ?? 0, limit);
  }

  StayRowData _specialRow(StayOwnerModel s) {
    final row = s.specialPricesRow;
    final first = row?.first;
    final open = StayPill(label: StayHubStrings.open, kind: StayPillKind.outline, onTap: () => _push(AppRoutes.staySpecialPrices));
    void tap() => _push(AppRoutes.staySpecialPrices);
    if (row == null || row.count == 0 || first == null) {
      return StayRowData(art: ListingArt.diyaLamp, tint: StayLook.artTintAmber, title: StayHubStrings.specialPrices, sub: StayHubStrings.noSpecialPrices, trailing: open, onTap: tap);
    }
    final from = first.dateFrom;
    final range = from == null ? '' : StayFormat.rangeTo(from, first.dateTo);
    if (row.count == 1) {
      final p = first.percent;
      final dir = p == null || first.direction == PriceDirection.unknown ? null : (first.direction == PriceDirection.lower ? StayHubStrings.percentLower(p) : StayHubStrings.percentHigher(p));
      return StayRowData(
        art: ListingArt.diyaLamp,
        tint: StayLook.artTintAmber,
        title: first.label,
        sub: [range, ?dir].where((e) => e.isNotEmpty).join(' · '),
        trailing: open,
        onTap: tap,
      );
    }
    return StayRowData(
      art: ListingArt.diyaLamp,
      tint: StayLook.artTintAmber,
      title: StayHubStrings.specialCount(row.count),
      sub: StayHubStrings.specialNext(first.label, range),
      trailing: open,
      onTap: tap,
    );
  }

  StayRowData _calendarRow(StayOwnerModel s) {
    final row = s.calendarRow;
    final date = row?.nextDate;
    String? sub;
    if (date != null) {
      final label = row?.nextLabel;
      sub = label == null ? StayHubStrings.nextBookingDateOnly(StayFormat.day(date)) : StayHubStrings.nextBooking(StayFormat.day(date), label);
    }
    void tap() => _push(AppRoutes.stayCalendar);
    return StayRowData(
      art: ListingArt.calendar,
      title: StayHubStrings.bookingsCalendar,
      sub: sub,
      trailing: StayPill(label: StayHubStrings.open, kind: StayPillKind.outline, onTap: tap),
      onTap: tap,
    );
  }

  Widget _photosCard(BuildContext context, StayOwnerModel s, int limit, bool locked) {
    final tiles = <Widget>[
      for (final p in s.photos) _PhotoTile(url: p.url),
      for (final p in s.hiddenPhotos) _PhotoTile(url: p.url, hidden: true),
    ];
    if (!s.isPendingReview) {
      if (locked) {
        tiles.add(_LockTile(onTap: () => PlanGate.showLimit(context, StayGateStrings.photoGate())));
      } else if (s.photos.length < limit) {
        tiles.add(_AddTile(onTap: () => _managePhotos(s)));
      }
    }
    return Padding(
      padding: DS.insets(l: 18, t: 12, r: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.white, borderRadius: StayLook.cardRadius(68), boxShadow: DS.shadows(Ink3D.softShadow)),
        child: Padding(
          padding: DS.sym(h: 16, v: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(StayHubStrings.photosOf(s.photos.length, limit), style: Ink3D.text(13, FontWeight.w700, Ink3D.body, letterSpacing: 0))),
                  StayPill(label: StayHubStrings.manage, kind: StayPillKind.outline, onTap: () => _managePhotos(s)),
                ],
              ),
              Gap.v(8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: DS.s(72), crossAxisSpacing: DS.gh(10), mainAxisSpacing: DS.gv(10)),
                itemCount: tiles.length,
                itemBuilder: (_, i) => tiles[i],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _managePhotos(StayOwnerModel s) {
    if (_locked(s)) return;
    _push(AppRoutes.stayBasicDetails, args: const {'section': 'photos'});
  }

  void _editBasic(StayOwnerModel s) {
    if (_locked(s)) return;
    _push(s.isApproved ? AppRoutes.stayLiveEdit : AppRoutes.stayBasicDetails);
  }

  void _editRules(StayOwnerModel s) {
    if (_locked(s)) return;
    _push(AppRoutes.stayRules);
  }

  Future<void> _editPrice(BuildContext context, StayOwnerModel s, StayRoomModel r) async {
    if (_locked(s)) return;
    await StayEditPriceSheet.show(context, _c, r);
  }

  Future<void> _confirmDelete(StayOwnerModel s) async {
    final n = s.confirmedBookingCount;
    final ok = await Dialog3D.show<bool>(
      context,
      builder: (c) => Dialog3D(
        tone: ListingTone.forest,
        art: ListingArt.warning,
        title: StayHubStrings.deleteTitle,
        body: '${StayHubStrings.deleteBody}${n > 0 ? StayHubStrings.deleteBookings(n) : ''}',
        familyCorner: true,
        tight: true,
        titleSize: 18,
        actions: [
          StayPill(label: StayHubStrings.delete, kind: StayPillKind.danger, expand: true, onTap: () => Navigator.of(c).pop(true)),
          Gap.v(8),
          StayPill(label: StayHubStrings.keep, kind: StayPillKind.white, expand: true, onTap: () => Navigator.of(c).pop(false)),
        ],
      ),
    );
    if (ok == true) await _c.deleteStay();
  }
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

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.url, this.hidden = false});

  final String url;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: DS.circular(14),
          gradient: LinearGradient(colors: [ListingPalette.forest.g1.withValues(alpha: Alpha.scrim), ListingPalette.forest.g2.withValues(alpha: Alpha.soft)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: ClipRRect(
          borderRadius: DS.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url.isNotEmpty) KitPhoto(url: url, width: box.maxWidth, height: box.maxHeight) else Center(child: ExcludeSemantics(child: Art3D(asset: ListingArt.mountain, size: 31))),
              if (hidden) Center(child: Art3D(asset: ListingArt.locked, size: 26)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockTile extends StatelessWidget {
  const _LockTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '${StayGateStrings.addPhoto}, needs Plus',
        excludeSemantics: true,
        child: InkWell(
          key: GateKeys.softRow,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(color: StayLook.amberSoft, borderRadius: DS.circular(14), border: Border.all(color: OwnerLook.stay.lockLine, width: DS.s(2))),
            child: Center(child: Art3D(asset: ListingArt.locked, size: 26)),
          ),
        ),
      );
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: StayHubStrings.addTile,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(color: StayLook.amberSoft, borderRadius: DS.circular(14), border: Border.all(color: OwnerLook.stay.lockLine, width: DS.s(2))),
            child: Center(child: Text('+ ${StayHubStrings.addTile}', style: Ink3D.text(11, FontWeight.w700, StayLook.amberText, letterSpacing: 0))),
          ),
        ),
      );
}
