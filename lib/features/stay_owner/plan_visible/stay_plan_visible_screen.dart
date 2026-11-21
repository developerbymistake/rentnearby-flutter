import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../owner_core/data/owner_error_types.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/sheets/owner_confirm.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../../stay/setup/stay_setup_controller.dart';
import '../calendar/data/stay_calendar_apis.dart';
import '../calendar/models/stay_calendar_models.dart';
import '../calendar/widgets/stay_calendar_widgets.dart';
import '../stay_owner_deps.dart';
import '../strings/stay_special_price_strings.dart';
import '../widgets/stay_widgets.dart';

class StayPlanVisibleController extends GetxController {
  StayPlanVisibleController({this.api = const StayPlanVisibleApi()});

  static const String tag = 'stay-plan-visible';

  final StayPlanVisibleApi api;
  final load = Rx<OwnerLoad<StayPlanVisibleState>>(const OwnerLoadLoading());
  final photoIds = <String>[].obs;
  final roomIds = <String>[].obs;
  final errorLine = RxnString();
  final LatestOnly _latest = LatestOnly();
  final SingleFlight<OwnerResult<Map<String, dynamic>>> _save = SingleFlight();
  List<String> _startPhotos = const [];
  List<String> _startRooms = const [];

  StayPlanVisibleState? get state => load.value.valueOrNull;

  bool get dirty => photoIds.join(',') != _startPhotos.join(',') || roomIds.join(',') != _startRooms.join(',');

  bool get ready {
    final s = state;
    if (s == null) return false;
    return photoIds.length == s.photoTarget && roomIds.length == s.roomTarget;
  }

  Future<void> fetch() async {
    final id = _latest.next();
    final r = await api.load();
    if (isClosed || !_latest.isLatest(id)) return;
    if (r is OwnerOk<Map<String, dynamic>>) {
      final s = StayPlanVisibleState.fromJson(r.value, photoLimit: PlanGate.limit(PlanKey.photos), roomLimit: PlanGate.limit(PlanKey.roomTypes));
      if (!s.somethingHidden || !PlanGate.paymentOn) {
        load.value = const OwnerLoadEmpty();
        return;
      }
      _startPhotos = s.photos.map((p) => p.id).where(s.visiblePhotoIds.contains).toList();
      _startRooms = s.rooms.map((p) => p.id).where(s.visibleRoomIds.contains).toList();
      photoIds.assignAll(_startPhotos);
      roomIds.assignAll(_startRooms);
      load.value = OwnerLoadData(s);
      return;
    }
    load.value = OwnerLoads.from<StayPlanVisibleState>(switch (r) {
      OwnerRefused() => r.cast<StayPlanVisibleState>(),
      OwnerOffline() => OwnerOffline<StayPlanVisibleState>(),
      OwnerFailed(:final message) => OwnerFailed<StayPlanVisibleState>(message: message),
      OwnerOk() => OwnerFailed<StayPlanVisibleState>(message: ''),
    });
  }

  void togglePhoto(String id) {
    final s = state;
    if (s == null) return;
    if (photoIds.contains(id)) {
      photoIds.remove(id);
    } else if (photoIds.length < s.photoTarget) {
      final order = [for (final p in s.photos) p.id];
      photoIds.add(id);
      photoIds.sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    }
  }

  void toggleRoom(String id) {
    final s = state;
    if (s == null) return;
    if (roomIds.contains(id)) {
      roomIds.remove(id);
    } else if (roomIds.length < s.roomTarget) {
      final order = [for (final r in s.rooms) r.id];
      roomIds.add(id);
      roomIds.sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    }
  }

  Future<OwnerResult<Map<String, dynamic>>> save() async {
    errorLine.value = null;
    final r = await _save.run(() => api.save(photoIds: photoIds.toList(), roomIds: roomIds.toList()));
    if (isClosed) return r;
    if (r is OwnerRefused<Map<String, dynamic>>) {
      errorLine.value = switch (r.type) {
        OwnerErrorTypes.planVisibleInvalid => StayPlanVisibleStrings.invalid,
        OwnerErrorTypes.planVisibleLimit => StayPlanVisibleStrings.threeADay,
        OwnerErrorTypes.planVisibleNotNeeded => StayPlanVisibleStrings.notNeeded,
        _ => r.message ?? OwnerSharedStrings.noConnection,
      };
      if (r.type == OwnerErrorTypes.planVisibleNotNeeded) load.value = const OwnerLoadEmpty();
    }
    return r;
  }

  @override
  void onClose() {
    _latest.cancel();
    super.onClose();
  }
}

class StayPlanVisibleScreen extends StatefulWidget {
  const StayPlanVisibleScreen({super.key, this.controller});

  final StayPlanVisibleController? controller;

  @override
  State<StayPlanVisibleScreen> createState() => _StayPlanVisibleScreenState();
}

class _StayPlanVisibleScreenState extends State<StayPlanVisibleScreen> {
  late final StayPlanVisibleController c;
  late final bool _owns;

  @override
  void initState() {
    super.initState();
    _owns = widget.controller == null;
    c = widget.controller ?? Get.put(StayPlanVisibleController(), tag: StayPlanVisibleController.tag);
    c.fetch();
  }

  @override
  void dispose() {
    if (_owns && Get.isRegistered<StayPlanVisibleController>(tag: StayPlanVisibleController.tag)) {
      Get.delete<StayPlanVisibleController>(tag: StayPlanVisibleController.tag, force: true);
    }
    super.dispose();
  }

  Future<void> _back() async {
    final nav = Navigator.of(context);
    if (!c.dirty) {
      nav.pop();
      return;
    }
    if (await OwnerConfirm.discard(context) && nav.mounted) nav.pop();
  }

  Future<void> _save() async {
    final r = await c.save();
    if (!mounted) return;
    switch (r) {
      case OwnerOk():
        StayOwnerDeps.refreshHome();
        if (Get.isRegistered<StaySetupController>()) Get.find<StaySetupController>().load();
        Navigator.of(context).pop();
      case OwnerOffline():
      case OwnerFailed():
        AppToast.error(OwnerSharedStrings.noConnection);
      case OwnerRefused():
        if (r.rateLimited) AppToast.info(OwnerSharedStrings.tooManyTries);
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
        backgroundColor: OwnerLook.stay.page,
        body: Column(
          children: [
            Obx(() {
              c.load.value;
              return StayCalHeader(
                title: StayPlanVisibleStrings.title,
                subtitle: StayPlanVisibleStrings.sub(PlanGate.limit(PlanKey.photos), PlanGate.limit(PlanKey.roomTypes)),
                onBack: _back,
              );
            }),
            Expanded(
              child: Obx(() {
                final load = c.load.value;
                c.photoIds.length;
                c.roomIds.length;
                c.errorLine.value;
                return OwnerStateView<StayPlanVisibleState>(
                  load: load,
                  look: OwnerLook.stay,
                  words: const OwnerStateWords(emptyTitle: StayPlanVisibleStrings.notNeeded),
                  onRetry: c.fetch,
                  data: (context, s, stale) => _body(s),
                );
              }),
            ),
            Obx(() {
              c.photoIds.length;
              c.roomIds.length;
              final show = c.state != null;
              if (!show) return const SizedBox.shrink();
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
                    builder: (ctx, onPressed, busy) => PrimaryButton(label: StayPlanVisibleStrings.save, tone: StayCalKit.green, loading: busy, onPressed: onPressed),
                  ),
                  if (PlanGate.canUpgrade) ...[
                    Gap.v(8),
                    StayPill(label: StayPlanVisibleStrings.seePlus, kind: StayPillKind.outline, expand: true, onTap: PlanGate.seePlus),
                  ],
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _body(StayPlanVisibleState s) {
    final cover = c.photoIds.isEmpty ? null : c.photoIds.first;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _title(StayPlanVisibleStrings.photos, StayPlanVisibleStrings.chosen(c.photoIds.length, s.photoTarget)),
        ),
        SliverPadding(
          padding: DS.insets(l: 18, r: 18),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: DS.gv(8), crossAxisSpacing: DS.gh(8), childAspectRatio: 1.35),
            itemCount: s.photos.length,
            itemBuilder: (context, i) {
              final p = s.photos[i];
              final on = c.photoIds.contains(p.id);
              return _PhotoTile(photo: p, index: i, on: on, cover: p.id == cover, onTap: () => c.togglePhoto(p.id));
            },
          ),
        ),
        SliverToBoxAdapter(child: _title(StayPlanVisibleStrings.roomTypes, StayPlanVisibleStrings.chosen(c.roomIds.length, s.roomTarget))),
        SliverList.builder(
          itemCount: s.rooms.length,
          itemBuilder: (context, i) {
            final r = s.rooms[i];
            final on = c.roomIds.contains(r.id);
            return StayCardSegment(
              first: i == 0,
              last: i == s.rooms.length - 1,
              child: Semantics(
                button: true,
                toggled: on,
                label: r.name,
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => c.toggleRoom(r.id),
                  child: Padding(
                    padding: DS.sym(h: 16, v: 12),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.name, style: Ink3D.text(12.5, FontWeight.w700, on ? Ink3D.title : Ink3D.grey, letterSpacing: 0)),
                          Text(StayPlanVisibleStrings.perNight(r.price), style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                        ]),
                      ),
                      _Tick(on: on),
                    ]),
                  ),
                ),
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: StayNote(text: StayPlanVisibleStrings.keptNote)),
        const SliverToBoxAdapter(child: StaySmallLine(text: StayPlanVisibleStrings.threeADay)),
        if (c.errorLine.value != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: DS.insets(l: 22, t: 8, r: 22),
              child: Text(c.errorLine.value ?? '', style: Ink3D.text(11, FontWeight.w600, DesignColors.error, letterSpacing: 0)),
            ),
          ),
        SliverToBoxAdapter(child: Gap.v(24)),
      ],
    );
  }

  Widget _title(String title, String meter) => Padding(
        padding: DS.insets(l: 22, t: 18, r: 22, b: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(title, style: Ink3D.text(15, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
          Gap.h(8),
          Text(meter, style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
        ]),
      );
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
          color: on ? StayLook.greenText : DesignColors.surface,
          border: on ? null : Border.all(color: DesignColors.border, width: DS.s(1.5)),
        ),
        child: on ? Icon(Icons.check_rounded, size: DS.s(15), color: DesignColors.onPrimary) : null,
      );
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.index, required this.on, required this.cover, required this.onTap});

  final PlanVisiblePhoto photo;
  final int index;
  final bool on;
  final bool cover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        toggled: on,
        label: StayPlanVisibleStrings.photoA11y(index, on),
        excludeSemantics: true,
        child: InkWell(
          borderRadius: DS.circular(12),
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, box) => ClipRRect(
              borderRadius: DS.circular(12),
              child: Stack(children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: on ? Alpha.full : Alpha.v55,
                    child: KitPhoto(url: photo.url, width: box.maxWidth, height: box.maxHeight, tone: StayCalKit.green),
                  ),
                ),
                Positioned(top: DS.s(6), right: DS.s(6), child: _Tick(on: on)),
                if (cover)
                  Positioned(
                    left: DS.s(6),
                    bottom: DS.s(6),
                    child: Container(
                      padding: DS.sym(h: 6, v: 2),
                      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(6)),
                      child: Text(StayPlanVisibleStrings.cover, style: Ink3D.text(9, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      );
}
