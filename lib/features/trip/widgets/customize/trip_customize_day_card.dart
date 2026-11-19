import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';

import '../../models/trip_plan_model.dart';
import '../../trip_constants.dart';
import '../../trip_strings_customize.dart';
import '../../utils/trip_day_load.dart';
import '../../utils/trip_day_timeline.dart';
import '../../utils/trip_leg_draft.dart';
import 'trip_customize_spot_row.dart';

class TripCustomizeDayCard extends StatelessWidget {
  static const double _buttonFont = 13;
  static const double _artSize = 63;
  static const double _artLift = 13;

  final TripLegDraft draft;
  final int dayIndex;
  final DateTime? date;
  final int dayLimitMinutes;
  final bool flagged;
  final String? selectedSpotId;
  final String? draggingSpotId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRemove;
  final VoidCallback onAddPlaces;
  final VoidCallback onDeleteDay;
  final void Function(TripPlaceDrag drag, int slot) onDrop;
  final ValueChanged<String> onDragStarted;
  final DragUpdateCallback onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueNotifier<bool>? overSlot;

  const TripCustomizeDayCard({
    super.key,
    required this.draft,
    required this.dayIndex,
    required this.date,
    required this.dayLimitMinutes,
    required this.flagged,
    required this.selectedSpotId,
    this.draggingSpotId,
    required this.onSelect,
    required this.onRemove,
    required this.onAddPlaces,
    required this.onDeleteDay,
    required this.onDrop,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.overSlot,
  });

  int get dayNumber => draft.firstDayNumber + dayIndex;

  bool get frozen => draft.isFrozen(dayIndex);

  bool _accepts(TripPlaceDrag d) => draft.canDrop(d.spotId, dayIndex) == TripDraftBlock.none;

  bool get _holdsDragged => draggingSpotId != null && draft.days[dayIndex].spots.any((s) => s.id == draggingSpotId);

  int get _shownCount => draft.days[dayIndex].spots.length - (_holdsDragged ? 1 : 0);

  bool get _closedToDrop =>
      draggingSpotId != null && !frozen && !_holdsDragged && draft.days[dayIndex].spots.length >= TripConstants.maxSpotsPerDay;

  bool _over(bool accepted) {
    overSlot?.value = accepted;
    return accepted;
  }

  static ({List<int?> roads, List<int> starts}) _timeline(List<TripSpotRef> spots) {
    final roads = <int?>[
      for (var i = 0; i < spots.length; i++)
        i == spots.length - 1
            ? null
            : TripDayLoad.estimateMinutes(
                (lat: spots[i].latitude, lng: spots[i].longitude),
                (lat: spots[i + 1].latitude, lng: spots[i + 1].longitude),
              ),
    ];
    return (roads: roads, starts: TripDayTimeline.starts(visits: [for (final s in spots) s.visitMinutes], roads: roads));
  }

  Widget? _preview() {
    final id = draggingSpotId;
    final from = id == null ? null : draft.dayOfSpot(id);
    if (id == null || from == null) return null;
    final spots = draft.days[from].spots;
    final i = spots.indexWhere((s) => s.id == id);
    return TripCustomizeSpotRow(
      spot: spots[i],
      day: from,
      index: i,
      color: TripLook.dayColor(draft.firstDayNumber + from),
      time: TripDayTimeline.clock(_timeline(spots).starts[i]),
      driveMinutes: null,
      preview: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final spots = draft.days[dayIndex].spots;
    final radius = DS.br(kMealsRadius);
    Widget card(bool hover) => DecoratedBox(
          key: ValueKey('customize-day-$dayIndex'),
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: radius,
            boxShadow: DS.shadows(TripLook.dayCardShadow),
          ),
          position: DecorationPosition.background,
          child: DecoratedBox(
            key: flagged ? ValueKey('customize-day-error-$dayIndex') : null,
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: flagged ? Border.all(color: DesignColors.error, width: DS.s(3), strokeAlign: BorderSide.strokeAlignOutside) : null,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(_shownCount),
                  Padding(
                    padding: EdgeInsets.only(bottom: DS.s(8)),
                    child: _closedToDrop
                        ? Padding(
                            padding: DS.sym(h: 14, v: 12),
                            child: const TripCustomizeDashedNote(TripStringsCustomize.dayFullDrop),
                          )
                        : spots.isEmpty
                            ? _empty(hover)
                            : _rows(hover),
                  ),
                ],
              ),
            ),
          ),
        );
    final body = frozen
        ? Opacity(opacity: Alpha.v55, child: card(false))
        : DragTarget<TripPlaceDrag>(
            onWillAcceptWithDetails: (det) => _over(_accepts(det.data)),
            onLeave: (_) => _over(false),
            onAcceptWithDetails: (det) {
              _over(false);
              onDrop(det.data, spots.length);
            },
            builder: (context, cand, rej) => card(cand.isNotEmpty),
          );
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (flagged)
          Container(
            margin: DS.insets(l: 18, t: 28, r: 18),
            padding: DS.sym(h: 16, v: 12),
            decoration: BoxDecoration(color: DesignColors.dayFullChip, borderRadius: DS.br(TripCustomizeLook.errorRadius)),
            child: Text(TripStringsCustomize.emptyDayError(dayNumber), style: Ink3D.text(13, FontWeight.w600, TripLook.badText, height: 1.4)),
          ),
        Padding(
          padding: EdgeInsets.only(top: DS.gv(flagged ? 44 : 48)),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              body,
              Positioned(
                left: DS.s(10),
                top: -DS.s(_artLift),
                child: IgnorePointer(
                  child: Opacity(
                    opacity: frozen ? Alpha.v55 : 1,
                    child: Art3D(asset: ListingArt.calendar, size: _artSize, halo: _artSize - 1, haloColor: DesignColors.whiteSoft),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return flagged ? _RevealOnShow(child: column) : column;
  }

  Widget _header(int count) {
    const white = DesignColors.surface;
    final load = draft.estimateMinutes(dayIndex, without: _holdsDragged ? draggingSpotId : null);
    final full = count >= TripConstants.maxSpotsPerDay;
    return Container(
      padding: DS.insets(l: 88, t: 12, r: 14, b: 14),
      decoration: BoxDecoration(gradient: ListingTone.indigo.gradient),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: DS.s(2)),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: DS.s(40)),
                  child: Row(
                    children: [
                      Container(
                        width: DS.s(14),
                        height: DS.s(14),
                        decoration: BoxDecoration(color: TripLook.dayColor(dayNumber), shape: BoxShape.circle, border: Border.all(color: white, width: DS.s(2.5))),
                      ),
                      Gap.h(8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            TripStringsCustomize.dayTitle(dayNumber, date),
                            maxLines: 1,
                            style: Ink3D.text(17, FontWeight.w700, white, height: 1.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Gap.v(2),
                Wrap(
                  spacing: DS.gh(10),
                  runSpacing: DS.gv(8),
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(TripStringsCustomize.span(load), style: Ink3D.text(13, FontWeight.w600, white)),
                    full
                        ? _pill(TripStringsCustomize.full, fill: DesignColors.dayFullChip, ink: TripLook.badText)
                        : _pill(TripStringsCustomize.placesChip(count)),
                  ],
                ),
              ],
            ),
            ),
          ),
          Gap.h(10),
          if (frozen) SizedBox(width: DS.s(40)) else _menu(),
        ],
      ),
    );
  }

  Widget _menu() {
    return MenuAnchor(
      alignmentOffset: Offset(0, DS.s(6)),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        elevation: const WidgetStatePropertyAll(8),
        backgroundColor: const WidgetStatePropertyAll(DesignColors.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: DS.circular(12))),
      ),
      menuChildren: [
        MenuItemButton(
          onPressed: onDeleteDay,
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(0, DS.s(40))),
            padding: WidgetStatePropertyAll(DS.sym(h: 20)),
          ),
          child: Text(TripStringsCustomize.deleteDay, style: Ink3D.text(13, FontWeight.w700, TripLook.badText)),
        ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: TripStringsCustomize.dayMenu,
        child: GestureDetector(
          key: ValueKey('customize-day-menu-$dayIndex'),
          behavior: HitTestBehavior.opaque,
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          child: Container(
            width: DS.s(40),
            height: DS.s(40),
            decoration: BoxDecoration(color: DesignColors.surface, shape: BoxShape.circle, boxShadow: DS.shadows(TripCustomizeLook.dayMenu)),
            child: Icon(Icons.more_vert_rounded, size: DS.s(18), color: ListingTone.indigo.text),
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, {Color? fill, Color? ink}) => Container(
        height: DS.s(28),
        padding: DS.sym(h: 10),
        decoration: BoxDecoration(color: fill ?? DesignColors.tint(DesignColors.surface, Alpha.v26), borderRadius: DS.circular(10)),
        child: Center(
          widthFactor: 1,
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w700, ink ?? DesignColors.surface)),
        ),
      );

  Widget _empty(bool hover) {
    final rest = draft.days[dayIndex].restDay;
    return Padding(
      padding: DS.insets(l: 16, t: 20, r: 16, b: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hover) ...[const _InsertLine(), _DropZone(child: _preview())],
          Text(
            rest ? TripStringsCustomize.restDay : TripStringsCustomize.noPlacesYet,
            textAlign: TextAlign.center,
            style: Ink3D.text(15, FontWeight.w700, Ink3D.title),
          ),
          Gap.v(4),
          Text(TripStringsCustomize.addOrDelete, textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText)),
          if (!frozen) ...[
            Gap.v(14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: GradientPillButton(
                    key: ValueKey('customize-empty-add-$dayIndex'),
                    tone: ListingTone.indigo,
                    label: TripStringsCustomize.addPlaces,
                    expand: false,
                    height: 40,
                    fontSize: _buttonFont,
                    shadows: TripCustomizeLook.softPill,
                    onTap: onAddPlaces,
                  ),
                ),
                Gap.h(12),
                Flexible(child: _deleteButton()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _deleteButton() => Tap3D(
        tapKey: ValueKey('customize-empty-delete-$dayIndex'),
        onTap: onDeleteDay,
        label: TripStringsCustomize.deleteDay,
        child: Container(
          constraints: BoxConstraints(minHeight: DS.s(40)),
          padding: DS.sym(h: 20),
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: DS.circular(20),
            border: Border.all(color: DesignColors.dangerLine, width: DS.s(1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                TripStringsCustomize.deleteDay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ink3D.text(_buttonFont, FontWeight.w700, TripLook.badText),
              ),
            ],
          ),
        ),
      );

  Widget _addRow() => Padding(
        padding: DS.insets(l: 14, t: 12, r: 14, b: 16),
        child: Tap3D(
          tapKey: ValueKey('customize-add-$dayIndex'),
          onTap: onAddPlaces,
          label: TripStringsCustomize.addPlaces,
          child: CustomPaint(
            painter: TripDashBox(TripLook.rail, DS.s(1), fill: DesignColors.addRowFill),
            child: Container(
              constraints: BoxConstraints(minHeight: DS.s(44)),
              alignment: Alignment.center,
              padding: DS.sym(h: 12),
              child: Text(
                TripStringsCustomize.addPlacesRow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ink3D.text(12.5, FontWeight.w700, ListingTone.indigo.text),
              ),
            ),
          ),
        ),
      );

  Widget _rows(bool hoverEnd) {
    final spots = draft.days[dayIndex].spots;
    final (:roads, :starts) = _timeline(spots);
    final color = TripLook.dayColor(dayNumber);
    final full = _shownCount >= TripConstants.maxSpotsPerDay;
    int? drive(int i) {
      if (i < 0 || i + 1 >= spots.length) return null;
      if (spots[i].id == draggingSpotId || spots[i + 1].id == draggingSpotId) return null;
      final m = roads[i];
      return m != null && m > 0 ? m : null;
    }

    Widget row(int i) {
      final s = spots[i];
      final r = TripCustomizeSpotRow(
        spot: s,
        day: dayIndex,
        index: i,
        color: color,
        time: TripDayTimeline.clock(starts[i]),
        driveMinutes: frozen ? drive(i) : null,
        frozen: frozen,
        selected: selectedSpotId == s.id,
        onTap: () => onSelect(s.id),
        onRemove: () => onRemove(s.id),
        onDragStarted: () => onDragStarted(s.id),
        onDragUpdate: onDragUpdate,
        onDragEnd: onDragEnd,
        liftHidden: overSlot,
      );
      if (frozen) return r;
      return DragTarget<TripPlaceDrag>(
        key: ValueKey('customize-slot-${s.id}'),
        onWillAcceptWithDetails: (det) => det.data.spotId == s.id || _over(_accepts(det.data)),
        onLeave: (_) => _over(false),
        onAcceptWithDetails: (det) {
          _over(false);
          if (det.data.spotId != s.id) onDrop(det.data, i);
        },
        builder: (context, cand, rej) {
          final line = cand.any((d) => d != null && d.spotId != s.id);
          final before = line ? null : drive(i - 1);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (before != null) TripCustomizeSpotRow.driveRow(context, before),
              if (line) ...[const _InsertLine(), _DropZone(child: _preview())],
              r,
            ],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < spots.length; i++) row(i),
        if (hoverEnd) ...[const _InsertLine(), _DropZone(child: _preview())],
        if (!frozen && !full) _addRow(),
      ],
    );
  }
}

class _InsertLine extends StatelessWidget {
  const _InsertLine();

  @override
  Widget build(BuildContext context) {
    final color = ListingTone.indigo.g2;
    final dot = DS.s(9);
    return Padding(
      key: const ValueKey('customize-insert-line'),
      padding: DS.insets(l: 84, t: 8, r: 14, b: 8),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          Container(height: DS.s(3), decoration: BoxDecoration(color: color, borderRadius: DS.circular(2))),
          Positioned(
            left: -DS.s(5),
            child: Container(width: dot, height: dot, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ),
        ],
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  final Widget? child;

  const _DropZone({this.child});

  @override
  Widget build(BuildContext context) {
    final c = child;
    return Padding(
      key: const ValueKey('customize-drop-zone'),
      padding: DS.sym(h: 8, v: 6),
      child: CustomPaint(
        painter: TripDashBox(ListingTone.indigo.g2, DS.s(1), fill: ListingPalette.indigo.tint, radius: DS.circular(14)),
        child: c == null
            ? SizedBox(height: DS.s(TripCustomizeSpotRow.liftedHeight + 16))
            : Padding(padding: DS.sym(h: 4, v: 10), child: c),
      ),
    );
  }
}

class _RevealOnShow extends StatefulWidget {
  final Widget child;

  const _RevealOnShow({required this.child});

  @override
  State<_RevealOnShow> createState() => _RevealOnShowState();
}

class _RevealOnShowState extends State<_RevealOnShow> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
