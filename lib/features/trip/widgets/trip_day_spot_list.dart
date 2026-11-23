import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'trip_update_ask_sheet.dart';
import 'package:get/get.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_plan_result_model.dart';
import '../models/trip_spot_category.dart';
import '../screens/trip_edit_spot_sheet.dart';
import '../trip_constants.dart';
import '../trip_strings_v2_plan.dart';
import '../trip_strings_wizard.dart';
import '../utils/trip_day_timeline.dart';
import '../utils/trip_days_rules.dart';
import '../utils/trip_drag_slots.dart';
import '../utils/trip_format.dart';
import 'drag/trip_spot_drag_scope.dart';
import 'drag/trip_spot_drag_start.dart';
import 'trip_leg_header.dart';
import 'trip_leg_actions.dart';
import '../../buddy/ledger/widgets/day_spent_chip.dart';
import '../../buddy/sharing/controllers/owner_sharing_controller.dart';


class TripDaySpotList extends StatelessWidget {
  final int day;
  final bool inSection;

  const TripDaySpotList(this.day, {super.key, this.inSection = false});

  static const Key headerKey = ValueKey('day-header');
  static const Key chipsKey = ValueKey('day-chips');
  static const Key handleKey = ValueKey('spot-drag-handle');
  static const Key dropKey = ValueKey('day-drop');
  static const Key dropHighlightKey = ValueKey('day-drop-highlight');
  static const Key dropLineKey = ValueKey('day-drop-line');

  static Future<void> replace(TripPlanController c, String spotId, int day) async {
    final legIndex = c.plan.value?.legIndexOf(day) ?? 1;
    await TripLegActions.addPlaces(legIndex, pickDay: day, replaceSpotId: spotId);
  }

  static BorderRadius get _radius => DS.br(kMealsRadius);

  static bool _hasExpenses(TripPlanController c) {
    final t = c.trip.value;
    if (t == null) return false;
    final live = OwnerSharingController.of(t.id)?.sharing.value;
    return (live ?? t.sharing)?.expenses.hasExpenses ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final plan = c.plan.value;
      c.result.value;
      c.trip.value;
      final d = plan?.dayAt(day);
      if (plan == null || d == null) return const SizedBox.shrink();
      final color = TripLook.dayColor(day - plan.legStart(plan.legIndexOf(day)) + 1);
      final locked = !c.canEditStructure || c.isDayPast(day);
      final editing = c.editMode.value && !locked;
      final closed = [
        for (final w in c.warningsFor(day))
          if (w.code == TripWarningCodes.closedDay) _closedText(plan, w),
      ];
      final full = !TripDaysRules.canAddOnDay(plan, day);
      final narrow = MediaQuery.sizeOf(context).width < 340;
      final artSize = narrow ? 56.0 : 63.0;
      final side = inSection ? 0.0 : DS.s(18);
      final top = DS.s(inSection ? TripLegSectionHeader.dayCardTop : 40);
      final bottomPad = inSection ? 0.0 : DS.gv(16);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: locked || c.editMode.value ? null : () => c.editMode.value = true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(side, top, side, bottomPad),
              child: _DayDropTarget(
                day: day,
                leg: plan.legIndexOf(day),
                editing: editing,
                color: color,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: DesignColors.surface,
                    borderRadius: _radius,
                    boxShadow: DS.shadows(TripLook.dayCardShadow),
                  ),
                  child: ClipRRect(
                    borderRadius: _radius,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _header(c, plan, d, color, editing, DS.s(narrow ? 78.0 : 88.0)),
                        Padding(
                          padding: EdgeInsets.only(bottom: DS.s(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (d.spots.isEmpty)
                                _emptyBody(d)
                              else
                                _spots(context, c, plan, d, color, locked, editing),
                              for (final text in closed)
                                Padding(
                                  padding: EdgeInsets.fromLTRB(DS.s(12), DS.gv(8), DS.s(12), 0),
                                  child: Row(
                                    children: [
                                      const Art3D(asset: ListingArt.clipboard, size: 20, shadowBlur: 2, shadowOffset: Offset(1, 2)),
                                      Gap.h(8),
                                      Expanded(
                                        child: Text(text, style: Ink3D.text(12, FontWeight.w600, TripLook.warningText)),
                                      ),
                                    ],
                                  ),
                                ),
                              if (editing) Padding(padding: DS.sym(h: 12), child: _editFooter(context, c, plan, d, full)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: side + DS.s(10),
              top: top - DS.s(13),
              child: IgnorePointer(
                child: Art3D(asset: ListingArt.calendar, size: artSize, halo: artSize - 1, haloColor: DesignColors.tint(DesignColors.surface, Alpha.v22)),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _emptyBody(TripDay d) => Padding(
        padding: DS.sym(v: 14),
        child: Column(
          children: [
            Art3D(asset: d.restDay ? ListingArt.bed : ListingArt.compass, size: 72),
            Gap.v(6),
            Text(
              d.restDay ? TripStringsV2Plan.restDay : TripStringsV2Plan.noPlacesThisDay,
              textAlign: TextAlign.center,
              style: Ink3D.text(13.5, FontWeight.w600, Ink3D.grey),
            ),
          ],
        ),
      );

  Widget _header(TripPlanController c, TripPlan plan, TripDay d, Color color, bool editing, double artRoom) {
    final date = c.dateOf(day);
    final dateText = date == null ? null : TripFormat.shortDate(date);
    final load = c.dayLoadMinutes(day);
    final title = TripStringsV2Plan.dayHeaderEmpty(day, dateText);
    const white = DesignColors.surface;
    return Container(
      key: headerKey,
      constraints: BoxConstraints(minHeight: DS.s(80)),
      padding: EdgeInsets.fromLTRB(artRoom, DS.s(14), DS.s(14), DS.s(14)),
      decoration: BoxDecoration(gradient: ListingTone.indigo.gradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(height: DS.s(40)),
              Container(
                width: DS.s(14),
                height: DS.s(14),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: white, width: DS.s(2.5))),
              ),
              Gap.h(8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(17, FontWeight.w700, white, height: 1.3, letterSpacing: 0),
                ),
              ),
            ],
          ),
          Gap.v(2),
          Wrap(
            key: chipsKey,
            spacing: DS.gh(10),
            runSpacing: DS.gv(8),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (d.spots.isNotEmpty) Text(TripFormat.hm(load), style: Ink3D.text(13, FontWeight.w600, white, letterSpacing: 0)),
              _pill(TripStringsV2Plan.placesCount(d.spots.length)),
              if (_hasExpenses(c)) DaySpentChip(tripId: c.trip.value!.id, day: day),
              if (editing && plan.legDayCount(d.leg) > 1)
                Tap3D(
                  onTap: () => _removeDay(c),
                  label: TripStringsV2Plan.removeDay,
                  child: _pill(TripStringsV2Plan.removeDay, fill: white, ink: TripLook.errorText),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, {Color? fill, Color? ink}) => Container(
        height: DS.s(28),
        padding: DS.sym(h: 10),
        decoration: BoxDecoration(color: fill ?? DesignColors.tint(DesignColors.surface, Alpha.v26), borderRadius: DS.circular(10)),
        child: Center(widthFactor: 1, child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w700, ink ?? DesignColors.surface, letterSpacing: 0))),
      );

  Widget _spots(
    BuildContext context,
    TripPlanController c,
    TripPlan plan,
    TripDay d,
    Color color,
    bool locked,
    bool editing,
  ) {
    final spots = d.spots;
    final known = c.result.value?.dayAt(day) != null;
    final roads = <int?>[
      for (var i = 0; i < spots.length; i++)
        i == spots.length - 1 || !known ? null : c.roadMinutesBetween(day, spots[i], spots[i + 1]),
    ];
    final drives = <int?>[
      for (var i = 0; i < roads.length; i++)
        roads[i] != null && c.roadKnown(day, spots[i], spots[i + 1]) ? roads[i] : null,
    ];
    final reserved = c.dayReservedMinutes(day);
    final starts = TripDayTimeline.starts(
      visits: [for (final s in spots) s.visitMinutes],
      roads: roads,
      reserved: reserved,
    );
    final travel = reserved > 0 && plan.legIndexOf(day) >= 2 && plan.legStart(plan.legIndexOf(day)) == day;
    final k = plan.legIndexOf(day);
    final prev = travel ? plan.legAt(k - 1)?.cityName : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (travel && prev != null)
          Container(
            margin: EdgeInsets.fromLTRB(DS.s(12), DS.s(8), DS.s(12), DS.gv(6)),
            padding: DS.sym(h: 10, v: 8),
            decoration: BoxDecoration(color: ListingTone.indigo.tint, borderRadius: DS.circular(12)),
            child: Row(
              children: [
                const Art3D(asset: ListingArt.taxi, size: 22, shadowBlur: 2, shadowOffset: Offset(1, 2)),
                Gap.h(8),
                Expanded(
                  child: Text(
                    TripStringsV2Plan.travelRow(prev, plan.legAt(k)?.cityName ?? '', TripFormat.duration(reserved)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(12, FontWeight.w600, Ink3D.title),
                  ),
                ),
              ],
            ),
          ),
        _DaySpots(
          day: day,
          spots: spots,
          color: color,
          editing: editing,
          prevDay: editing ? _neighbour(c, plan, day - 1) : null,
          nextDay: editing ? _neighbour(c, plan, day + 1) : null,
          times: [for (final t in starts) TripDayTimeline.clock(t)],
          drives: drives,
          onRemove: (id) => _removeById(context, c, id),
          onOpen: (id) {
            final s = c.plan.value?.spotById(id);
            if (s != null) _spotMenu(context, c, s);
          },
        ),
      ],
    );
  }

  int? _neighbour(TripPlanController c, TripPlan plan, int n) =>
      plan.dayAt(n) != null && plan.legIndexOf(n) == plan.legIndexOf(day) && c.canEditDay(n) ? n : null;

  void _removeById(BuildContext context, TripPlanController c, String id) {
    final d = c.plan.value?.dayAt(day);
    final i = d?.spots.indexWhere((x) => x.id == id) ?? -1;
    if (d != null && i >= 0) _remove(context, c, d, i);
  }

  void _remove(BuildContext context, TripPlanController c, TripDay d, int index) {
    final spot = d.spots[index];
    c.removeSpot(spot.id, keepEmptyDays: true);
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(
      SnackBar(
        content: const Text(TripStringsV2Plan.placeRemoved, style: TextStyle(fontFamily: FitnessAppTheme.fontName)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: TripStringsV2Plan.undo, onPressed: () => c.insertSpotAt(spot, day, index)),
      ),
    );
  }

  Widget _editFooter(BuildContext context, TripPlanController c, TripPlan plan, TripDay d, bool full) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(padding: DS.sym(v: 8), child: const Divider(height: 1, color: Ink3D.line)),
        Row(
          children: [
            Expanded(
              child: _action(
                ListingArt.roundPushpin,
                TripStringsV2Plan.addPlace,
                full ? null : () => TripLegActions.addPlaces(d.leg, pickDay: day),
              ),
            ),
            Gap.h(10),
            Expanded(
              child: _action(
                ListingArt.bed,
                d.restDay ? TripStringsV2Plan.undoRestDay : TripStringsV2Plan.makeRestDay,
                d.spots.isEmpty ? () => c.setRestDay(day, !d.restDay) : null,
              ),
            ),
          ],
        ),
        if (full)
          Banner3D(
            kind: BannerKind.warn,
            art: ListingArt.calendar,
            title: TripStringsV2Plan.dayFull,
            actionLabel: TripStringsV2Plan.addDay,
            onAction: c.canAddDay
                ? () {
                    c.addDay(afterDay: day);
                    TripUpdateAskSheet.afterDaysEdit();
                  }
                : null,
            margin: EdgeInsets.only(top: DS.gv(10)),
          ),
      ],
    );
  }

  void _removeDay(TripPlanController c) {
    final r = c.removeDay(day);
    final text = switch (r) {
      TripDayRemoveBlock.none => null,
      TripDayRemoveBlock.placesDontFit => TripStringsV2Plan.removePlacesFirst,
      TripDayRemoveBlock.lastDay => TripStringsV2Plan.lastDay,
      TripDayRemoveBlock.readOnly => TripStringsV2Plan.readOnlyDay,
    };
    if (text != null) {
      _toast(text);
    } else {
      TripUpdateAskSheet.afterDaysEdit();
    }
  }

  void _toast(String text) {
    final m = Get.context == null ? null : ScaffoldMessenger.maybeOf(Get.context!);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(SnackBar(content: Text(text, style: const TextStyle(fontFamily: FitnessAppTheme.fontName))));
  }

  Widget _action(String art, String label, VoidCallback? onTap) {
    final tone = ListingTone.indigo;
    return Opacity(
      opacity: onTap == null ? Alpha.v45 : 1,
      child: Tap3D(
        onTap: onTap,
        label: label,
        child: Container(
          constraints: BoxConstraints(minHeight: DS.s(44)),
          padding: DS.sym(h: 6, v: 6),
          decoration: BoxDecoration(color: tone.tint, borderRadius: DS.circular(24)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Art3D(asset: art, size: 20, shadowBlur: 2, shadowOffset: const Offset(1, 2)),
              Gap.h(5),
              Flexible(
                child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w600, tone.text)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _spotMenu(BuildContext context, TripPlanController c, TripSpotRef s) async {
    final tone = ListingTone.indigo;
    final choice = await SheetFrame.show<String>(
      context,
      builder: (sheetCtx) => SheetFrame(
        title: s.name,
        tone: tone,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetOptionCard(tone: tone, art: ListingArt.roundPushpin, title: TripStringsWizard.replacePlace, onTap: () => Navigator.pop(sheetCtx, 'replace')),
            SheetOptionCard(tone: tone, art: ListingArt.calendar, title: TripStringsWizard.moveToDay, onTap: () => Navigator.pop(sheetCtx, 'move')),
            SheetOptionCard(tone: tone, art: ListingArt.clipboard, title: TripStringsWizard.removePlace, onTap: () => Navigator.pop(sheetCtx, 'remove')),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'replace':
        await replace(c, s.id, day);
      case 'move':
        await TripEditSpotSheet.show(context, s.id);
      case 'remove':
        final i = c.plan.value?.dayAt(day)?.spots.indexWhere((x) => x.id == s.id) ?? -1;
        if (i >= 0) _remove(context, c, c.plan.value!.dayAt(day)!, i);
    }
  }

  String _closedText(TripPlan plan, TripWarning w) {
    final id = w.spotId;
    final name = id == null ? null : plan.spotById(id)?.name;
    return name == null ? w.message : TripStringsWizard.closedThatDay(name);
  }
}


typedef _RowFields = (TripSpotRef, int, String, int?, bool, bool, Color, int?, int?);

typedef _PendingDrop = ({
  TripPlanController controller,
  SliverReorderableListState list,
  ScaffoldMessengerState? messenger,
  List<TripSpotRef> spots,
  int day,
  int from,
  int to,
});

class _DaySpots extends StatefulWidget {
  final int day;
  final List<TripSpotRef> spots;
  final Color color;
  final bool editing;
  final int? prevDay;
  final int? nextDay;
  final List<String> times;
  final List<int?> drives;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onOpen;

  const _DaySpots({
    required this.day,
    required this.spots,
    required this.color,
    required this.editing,
    this.prevDay,
    this.nextDay,
    required this.times,
    required this.drives,
    required this.onRemove,
    required this.onOpen,
  });

  @override
  State<_DaySpots> createState() => _DaySpotsState();
}

class _DaySpotsState extends State<_DaySpots> with AutomaticKeepAliveClientMixin {
  final Map<String, (_RowFields, _StopItem)> _cache = {};
  final ValueNotifier<TripDragState?> _ownDrag = ValueNotifier(null);
  TripSpotDragScopeState? _scope;
  TripTrackedDrag? _drag;
  List<Rect> _rows = const [];
  double _liftTop = 0;
  double _liftLeft = 0;
  int _insert = 0;
  int _endInsert = 0;
  Timer? _settling;
  _PendingDrop? _dropping;

  ValueNotifier<TripDragState?> get _notifier => _scope?.drag ?? _ownDrag;

  TripPlanController get _c => TripPlanController.to;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  bool get wantKeepAlive => _drag != null;

  bool _canStart() => _drag == null && _settling == null && !(_scope?.active ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = TripSpotDragScope.maybeOf(context);
    if (scope != _scope) {
      _scope = scope;
      _cache.clear();
    }
  }

  @override
  void didUpdateWidget(_DaySpots old) {
    super.didUpdateWidget(old);
    final held = _drag;
    final drop = _dropping;
    if (held == null && drop == null) return;
    final sameOrder = _sameOrder(old.spots, widget.spots);
    if (sameOrder && old.editing == widget.editing) return;
    _drag = null;
    _dropping = null;
    _rows = const [];
    _settling?.cancel();
    _settling = null;
    final list = held?.list ?? drop?.list;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (list != null && list.mounted) list.cancelReorder();
      if (mounted) {
        if (held != null) {
          _scope?.stopAutoScroll();
          _scope?.end();
        }
        _clearNumbers();
        updateKeepAlive();
      }
      if (drop != null && sameOrder) _finishDrop(drop);
    });
  }

  @override
  void dispose() {
    final drop = _dropping;
    if (drop != null) {
      final scope = _scope;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scope != null && scope.mounted && scope.drag.value?.day == drop.day) scope.drag.value = null;
        _finishDrop(drop);
      });
    }
    if (_drag != null) _endSession();
    _settling?.cancel();
    _ownDrag.dispose();
    super.dispose();
  }

  _StopItem _row(int i) {
    final s = widget.spots[i];
    final last = i == widget.spots.length - 1;
    final fields = (s, i, widget.times[i], widget.drives[i], !last, widget.editing, widget.color, widget.prevDay, widget.nextDay);
    final hit = _cache[s.id];
    if (hit != null && hit.$1 == fields) return hit.$2;
    final row = _StopItem(
      key: ValueKey(s.id),
      day: widget.day,
      index: i,
      spot: s,
      color: widget.color,
      time: widget.times[i],
      driveMinutes: widget.drives[i],
      showDrive: !last,
      editing: widget.editing,
      prevDay: widget.prevDay,
      nextDay: widget.nextDay,
      drag: _notifier,
      onRemove: widget.onRemove,
      onOpen: widget.editing ? widget.onOpen : null,
      onMoveBy: _moveBy,
      onMoveToDay: _moveToNeighbour,
      onLift: _lift,
      onMove: _move,
      onRelease: _release,
      onCancel: _cancel,
      onDrop: _drop,
      canStart: _canStart,
    );
    _cache[s.id] = (fields, row);
    return row;
  }

  RenderBox? get _box {
    final b = context.findRenderObject();
    return b is RenderBox && b.attached && b.hasSize ? b : null;
  }

  void _lift(TripTrackedDrag d) {
    final box = _box;
    if (box == null) return;
    _drag = d;
    updateKeepAlive();
    final origin = box.localToGlobal(Offset.zero);
    _liftTop = origin.dy;
    _liftLeft = origin.dx;
    _rows = _rowRects(box);
    _insert = d.index;
    _endInsert = d.index;
    final scope = _scope;
    final id = widget.spots[d.index].id;
    if (scope != null) {
      scope.begin(day: widget.day, from: d.index, canDrop: (to) => _c.canDropOn(id, to), owner: this);
    } else {
      _notifier.value = TripDragState(day: widget.day, from: d.index, slot: d.index);
    }
    TripDragHaptics.lift();
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null) _scope?.startAutoScroll(scrollable, _refeed);
  }

  List<Rect> _rowRects(RenderBox list) {
    final rects = List<Rect>.filled(widget.spots.length, Rect.zero);
    void visit(Element e) {
      final w = e.widget;
      if (w is _StopItem) {
        final r = e.renderObject;
        if (r is RenderBox && r.hasSize && w.index < rects.length) {
          rects[w.index] = list.globalToLocal(r.localToGlobal(Offset.zero)) & r.size;
        }
        return;
      }
      e.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return rects;
  }

  void _move(TripTrackedDrag d) {
    if (d != _drag) return;
    _recompute();
    _feedScroller();
  }

  void _refeed() {
    final d = _drag;
    if (d == null) return;
    d.refeed();
    _recompute();
    _feedScroller();
  }

  void _recompute() {
    final d = _drag;
    final box = _box;
    if (d == null || box == null || _rows.isEmpty) return;
    final shift = box.localToGlobal(Offset.zero).dy - _liftTop;
    final next = TripDragSlots.next(rows: _rows, from: d.index, insert: _insert, proxyTop: _rows[d.index].top + d.dy - shift);
    final before = TripDragSlots.position(_insert, d.index);
    _insert = next;
    final slot = TripDragSlots.position(next, d.index);
    final scope = _scope;
    final proxy = _proxyRect();
    if (scope != null && proxy != null) {
      scope.update(slot: slot, proxy: proxy);
      return;
    }
    if (slot == before) return;
    TripDragHaptics.slot();
    _notifier.value = TripDragState(day: widget.day, from: d.index, slot: slot);
  }

  Rect? _proxyRect() {
    final d = _drag;
    if (d == null || _rows.isEmpty) return null;
    final r = _rows[d.index];
    return Rect.fromLTWH(_liftLeft + r.left, _liftTop + r.top + d.dy, r.width, r.height);
  }

  void _feedScroller() {
    final proxy = _proxyRect();
    if (proxy != null) _scope?.feed(proxy);
  }

  VoidCallback? _drop(TripTrackedDrag d) {
    final scope = _scope;
    if (d != _drag || scope == null) return null;
    final s = scope.drag.value;
    switch (scope.dropKind) {
      case TripDropKind.source:
        return null;
      case TripDropKind.outside:
        return () {};
      case TripDropKind.target:
        final to = s?.targetDay;
        if (s == null || to == null || d.index >= widget.spots.length) return () {};
        final id = widget.spots[d.index].id;
        final index = s.refused ? null : s.targetIndex;
        return () => _moveTo(id, to, index);
    }
  }

  void _moveToNeighbour(String id, int to) {
    final n = _c.plan.value?.dayAt(to)?.spots.length ?? 0;
    _moveTo(id, to, _c.canDropOn(id, to) ? (to < widget.day ? n : 0) : null);
  }

  void _moveTo(String id, int to, int? index) {
    final c = _c;
    if (index == null) {
      c.moveSpot(id, to);
      return;
    }
    final m = ScaffoldMessenger.maybeOf(context);
    final snap = c.snapshotDays([widget.day, to]);
    if (!c.moveSpot(id, to, index: index)) return;
    TripDragHaptics.drop();
    _showUndo(m, TripStringsV2Plan.movedToDay(to), snap);
  }

  void _onReorderEnd(int insert) {
    _endInsert = insert;
    final from = _drag?.index;
    if (from != null && TripDragSlots.position(insert, from) != from) TripDragHaptics.drop();
  }

  void _release(TripTrackedDrag d) {
    if (d != _drag) return;
    final from = d.index;
    final to = TripDragSlots.position(_endInsert, from);
    final reduce = _reduceMotion;
    _endSession(keepNumbers: !reduce && to != from);
    if (!reduce && to != from) {
      _settling?.cancel();
      _settling = Timer(TripConstants.dragSettleGuard, () {
        _settling = null;
        _dropping = null;
        if (mounted && _drag == null) _clearNumbers();
      });
    }
    if (reduce) {
      d.list.cancelReorder();
      _commit(from, to);
    } else if (to != from) {
      _dropping = (
        controller: _c,
        list: d.list,
        messenger: ScaffoldMessenger.maybeOf(context),
        spots: widget.spots,
        day: widget.day,
        from: from,
        to: to,
      );
    }
  }

  void _cancel(TripTrackedDrag d) {
    if (d == _drag) _endSession();
  }

  void _endSession({bool keepNumbers = false}) {
    _scope?.stopAutoScroll();
    _scope?.end();
    _drag = null;
    _rows = const [];
    if (!keepNumbers) _clearNumbers();
    if (mounted) updateKeepAlive();
  }

  void _clearNumbers() {
    if (_notifier.value?.day == widget.day) _notifier.value = null;
  }

  void _settled() {
    _settling?.cancel();
    _settling = null;
  }

  void _onReorderItem(int from, int to) {
    _settled();
    _dropping = null;
    _clearNumbers();
    _commit(from, to);
  }

  void _moveBy(String id, int delta) {
    final i = _c.plan.value?.dayAt(widget.day)?.spots.indexWhere((s) => s.id == id) ?? -1;
    if (i >= 0) _commit(i, i + delta);
  }

  void _commit(int from, int to) {
    if (from == to) return;
    final c = _c;
    final snap = c.snapshotDays([widget.day]);
    if (!c.reorderTo(widget.day, from, to)) return;
    _showUndo(ScaffoldMessenger.maybeOf(context), TripStringsV2Plan.orderChanged, snap);
  }

  static bool _sameOrder(List<TripSpotRef> a, List<TripSpotRef> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  // The list went away or changed before the drop settled; the indexes are only valid on the order they were taken from.
  static void _finishDrop(_PendingDrop p) {
    final c = p.controller;
    final now = c.isClosed ? null : c.plan.value?.dayAt(p.day)?.spots;
    if (now == null || !_sameOrder(now, p.spots)) return;
    final snap = c.snapshotDays([p.day]);
    if (!c.reorderTo(p.day, p.from, p.to)) return;
    final m = p.messenger;
    if (m == null || !m.mounted) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        content: const Text(TripStringsV2Plan.orderChanged, style: TextStyle(fontFamily: FitnessAppTheme.fontName)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: TripStringsV2Plan.undo, onPressed: () => c.restoreDays(snap)),
      ),
    );
  }

  void _showUndo(ScaffoldMessengerState? m, String text, List<TripDay> snap) {
    final c = _c;
    m?.hideCurrentSnackBar();
    m?.showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontFamily: FitnessAppTheme.fontName)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: TripStringsV2Plan.undo, onPressed: () => c.restoreDays(snap)),
      ),
    );
  }

  Widget _proxy(Widget child, int index, Animation<double> animation) {
    final lifted = DecoratedBox(
      decoration: BoxDecoration(borderRadius: DS.circular(10), boxShadow: DS.shadows(TripLook.dayCardShadow)),
      child: ClipRRect(borderRadius: DS.circular(10), child: child),
    );
    if (_reduceMotion) return lifted;
    return AnimatedBuilder(
      animation: animation,
      builder: (_, c) => Transform.scale(scale: 1 + TripConstants.dragLiftScale * Curves.easeOut.transform(animation.value), child: c),
      child: lifted,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ids = {for (final s in widget.spots) s.id};
    _cache.removeWhere((id, _) => !ids.contains(id));
    if (!widget.editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [for (var i = 0; i < widget.spots.length; i++) _row(i)],
      );
    }
    return ReorderableList(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.spots.length,
      itemBuilder: (_, i) => _row(i),
      onReorderItem: _onReorderItem,
      onReorderEnd: _onReorderEnd,
      proxyDecorator: _proxy,
    );
  }
}

class _StopItem extends StatelessWidget {
  final int day;
  final int index;
  final TripSpotRef spot;
  final Color color;
  final String time;
  final int? driveMinutes;
  final bool showDrive;
  final bool editing;
  final int? prevDay;
  final int? nextDay;
  final ValueListenable<TripDragState?> drag;
  final ValueChanged<String> onRemove;
  final ValueChanged<String>? onOpen;
  final void Function(String id, int delta) onMoveBy;
  final void Function(String id, int day) onMoveToDay;
  final TripDragCallback onLift;
  final TripDragCallback onMove;
  final TripDragCallback onRelease;
  final TripDragCallback onCancel;
  final TripDropDecision onDrop;
  final bool Function() canStart;

  const _StopItem({
    super.key,
    required this.day,
    required this.index,
    required this.spot,
    required this.color,
    required this.time,
    required this.driveMinutes,
    required this.showDrive,
    required this.editing,
    required this.prevDay,
    required this.nextDay,
    required this.drag,
    required this.onRemove,
    required this.onOpen,
    required this.onMoveBy,
    required this.onMoveToDay,
    required this.onLift,
    required this.onMove,
    required this.onRelease,
    required this.onCancel,
    required this.onDrop,
    required this.canStart,
  });

  Widget _dragStart({required bool delayed, required Widget child, HitTestBehavior behavior = HitTestBehavior.deferToChild}) =>
      TripSpotDragStart(
        index: index,
        delayed: delayed,
        delay: TripConstants.dragHoldDelay,
        behavior: behavior,
        onLift: onLift,
        onMove: onMove,
        onRelease: onRelease,
        onCancel: onCancel,
        onDrop: onDrop,
        canStart: canStart,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final drive = driveMinutes;
    final open = onOpen;
    final timeW = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3).scale(DS.s(66));
    final Widget row = InkWell(
      onTap: open == null ? null : () => open(spot.id),
      borderRadius: DS.circular(10),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: DS.s(60)),
        child: Padding(
          padding: DS.insets(l: 12, t: 8, r: 8, b: 8),
          child: Row(
            children: [
              if (editing)
                Padding(
                  padding: EdgeInsets.only(right: DS.s(4)),
                  child: Icon(Icons.drag_indicator_rounded, size: DS.s(20), color: TripLook.textHint),
                ),
              SizedBox(
                width: timeW,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(time, maxLines: 1, softWrap: false, style: Ink3D.text(12.5, FontWeight.w600, Ink3D.sub, letterSpacing: 0)),
                ),
              ),
              Container(
                width: DS.s(26),
                height: DS.s(26),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: _StopBadge(day: day, index: index, drag: drag),
              ),
              Gap.h(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(spot.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                    Text(
                      '${TripSpotCategory.label(spot.category)} · ${TripFormat.hm(spot.visitMinutes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText, letterSpacing: 0),
                    ),
                  ],
                ),
              ),
              if (editing)
                IconButton(
                  onPressed: () => onRemove(spot.id),
                  tooltip: TripStringsV2Plan.removePlace,
                  constraints: BoxConstraints(minWidth: DS.s(44), minHeight: DS.s(44)),
                  icon: Container(
                    width: DS.s(32),
                    height: DS.s(32),
                    decoration: BoxDecoration(color: TripLook.errorSurface, shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: DS.s(18), color: TripLook.error),
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.only(left: DS.s(10)),
                  child: Art3D(asset: TripSpotLook.assetOf(spot.category), size: 30, shadowBlur: 2, shadowOffset: const Offset(1, 3)),
                ),
            ],
          ),
        ),
      ),
    );
    final body = Material(
      color: DesignColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (editing)
            Stack(
              fit: StackFit.passthrough,
              children: [
                row,
                Positioned(
                  key: TripDaySpotList.handleKey,
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: DS.s(44, scaled: false),
                  child: Semantics(
                    label: TripStringsV2Plan.dragHandle,
                    child: _dragStart(delayed: false, behavior: HitTestBehavior.translucent, child: const SizedBox.expand()),
                  ),
                ),
              ],
            )
          else
            row,
          if (showDrive)
            Padding(
              padding: EdgeInsets.only(left: DS.s(editing ? 24 : 0) + timeW + DS.s(20)),
              child: Container(
                padding: EdgeInsets.only(left: DS.s(18), top: DS.s(3), bottom: DS.s(3)),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: ListingTone.indigo.g2.withValues(alpha: Alpha.v30), width: DS.s(2))),
                ),
                child: drive == null
                    ? SizedBox(height: DS.s(14))
                    : Row(
                        children: [
                          const Art3D(asset: ListingArt.taxi, size: 16, shadowBlur: 0, shadowAlpha: 0),
                          Gap.h(8),
                          Text(TripFormat.duration(drive), style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText, letterSpacing: 0)),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
    if (!editing) return body;
    return Semantics(
      customSemanticsActions: {
        if (index > 0) const CustomSemanticsAction(label: TripStringsV2Plan.moveUp): () => onMoveBy(spot.id, -1),
        if (showDrive) const CustomSemanticsAction(label: TripStringsV2Plan.moveDown): () => onMoveBy(spot.id, 1),
        if (prevDay case final p?) const CustomSemanticsAction(label: TripStringsV2Plan.moveToPreviousDay): () => onMoveToDay(spot.id, p),
        if (nextDay case final n?) const CustomSemanticsAction(label: TripStringsV2Plan.moveToNextDay): () => onMoveToDay(spot.id, n),
      },
      child: _dragStart(delayed: true, child: body),
    );
  }
}

class _StopBadge extends StatefulWidget {
  final int day;
  final int index;
  final ValueListenable<TripDragState?> drag;

  const _StopBadge({required this.day, required this.index, required this.drag});

  @override
  State<_StopBadge> createState() => _StopBadgeState();
}

class _StopBadgeState extends State<_StopBadge> {
  late int _n = _number();

  int _number() {
    final s = widget.drag.value;
    return s == null || s.day != widget.day ? widget.index : TripDragSlots.displayIndex(widget.index, s.from, s.slot);
  }

  void _onDrag() {
    final n = _number();
    if (n != _n) setState(() => _n = n);
  }

  @override
  void initState() {
    super.initState();
    widget.drag.addListener(_onDrag);
  }

  @override
  void didUpdateWidget(_StopBadge old) {
    super.didUpdateWidget(old);
    if (old.drag != widget.drag) {
      old.drag.removeListener(_onDrag);
      widget.drag.addListener(_onDrag);
    }
    _n = _number();
  }

  @override
  void dispose() {
    widget.drag.removeListener(_onDrag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text('${_n + 1}', style: Ink3D.text(12.5, FontWeight.w700, DesignColors.surface, letterSpacing: 0));
}

class _DayDropTarget extends StatefulWidget {
  final int day;
  final int leg;
  final bool editing;
  final Color color;
  final Widget child;

  const _DayDropTarget({required this.day, required this.leg, required this.editing, required this.color, required this.child});

  @override
  State<_DayDropTarget> createState() => _DayDropTargetState();
}

class _DayDropTargetState extends State<_DayDropTarget> implements TripDayDropTarget {
  TripSpotDragScopeState? _scope;
  int? _registered;
  (bool, int)? _look;
  List<Rect>? _rows;
  double? _headerBottom;

  @override
  int get day => widget.day;

  @override
  int get leg => widget.leg;

  RenderBox? get _box {
    final b = context.findRenderObject();
    return b is RenderBox && b.attached && b.hasSize ? b : null;
  }

  @override
  Rect? get globalRect {
    final box = _box;
    if (box == null) return null;
    final m = box.getTransformTo(null);
    // A kept-alive card scrolled out of the list gets a zero transform.
    if (m.determinant() == 0) return null;
    return MatrixUtils.transformRect(m, Offset.zero & box.size);
  }

  @override
  List<Rect> rowRects() {
    final box = _box;
    if (box == null) return const [];
    final origin = box.localToGlobal(Offset.zero);
    return [for (final r in _localRows(box)) r.shift(origin)];
  }

  List<Rect> _localRows(RenderBox card) {
    final cached = _rows;
    if (cached != null) return cached;
    final rows = <int, Rect>{};
    void visit(Element e) {
      final w = e.widget;
      if (w is _StopItem) {
        final r = e.renderObject;
        if (r is RenderBox && r.attached && r.hasSize) rows[w.index] = card.globalToLocal(r.localToGlobal(Offset.zero)) & r.size;
        return;
      }
      if (w.key == TripDaySpotList.headerKey) {
        final r = e.renderObject;
        if (r is RenderBox && r.attached && r.hasSize) _headerBottom = card.globalToLocal(r.localToGlobal(Offset(0, r.size.height))).dy;
      }
      e.visitChildren(visit);
    }

    context.visitChildElements(visit);
    final list = [for (final k in rows.keys.toList()..sort()) rows[k]!];
    _rows = list;
    return list;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = TripSpotDragScope.maybeOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(_DayDropTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day || oldWidget.editing != widget.editing) _sync();
  }

  void _sync() {
    final scope = _scope;
    final want = scope != null && widget.editing ? widget.day : null;
    if (want == _registered) return;
    _unregister();
    if (want != null && scope != null) {
      scope.register(want, this);
      scope.drag.addListener(_onDrag);
      _registered = want;
    }
  }

  void _unregister() {
    final r = _registered;
    if (r == null) return;
    _scope?.unregister(r, this);
    _scope?.drag.removeListener(_onDrag);
    _registered = null;
    _rows = null;
    _look = null;
  }

  void _onDrag() {
    final s = _scope?.drag.value;
    if (s == null) {
      _rows = null;
      _headerBottom = null;
    }
    final look = s != null && s.isTarget(widget.day) ? (s.refused, s.targetIndex) : null;
    if (look == _look) return;
    setState(() => _look = look);
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }

  double? _lineY() {
    final look = _look;
    final box = _box;
    if (look == null || look.$1 || box == null) return null;
    final rows = _localRows(box);
    if (rows.isEmpty) return _headerBottom == null ? null : _headerBottom! + DS.gv(6);
    return look.$2 < rows.length ? rows[look.$2].top : rows.last.bottom;
  }

  @override
  Widget build(BuildContext context) {
    final look = _look;
    final y = _lineY();
    final line = DS.s(3);
    return Stack(
      key: TripDaySpotList.dropKey,
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: look == null
                ? const SizedBox.shrink()
                : Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          key: TripDaySpotList.dropHighlightKey,
                          decoration: BoxDecoration(
                            borderRadius: TripDaySpotList._radius,
                            border: Border.all(color: look.$1 ? TripLook.error : ListingPalette.indigo.line, width: DS.s(2)),
                          ),
                        ),
                      ),
                      if (y != null)
                        Positioned(
                          left: DS.s(12),
                          right: DS.s(12),
                          top: y - line / 2,
                          height: line,
                          child: DecoratedBox(key: TripDaySpotList.dropLineKey, decoration: BoxDecoration(color: widget.color, borderRadius: DS.circular(2))),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
