import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';

import '../../trip_constants.dart';
import '../../trip_strings_customize.dart';
import '../../utils/trip_day_load.dart';
import '../../utils/trip_day_timeline.dart';
import '../../utils/trip_leg_draft.dart';
import 'trip_customize_spot_row.dart';

class TripCustomizeDayCard extends StatelessWidget {
  static const double _buttonFont = 14;

  final TripLegDraft draft;
  final int dayIndex;
  final DateTime? date;
  final int dayLimitMinutes;
  final bool flagged;
  final String? selectedSpotId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRemove;
  final VoidCallback onAddPlaces;
  final VoidCallback onDeleteDay;
  final void Function(TripPlaceDrag drag, int slot) onDrop;
  final VoidCallback onDragStarted;
  final DragUpdateCallback onDragUpdate;
  final VoidCallback onDragEnd;

  const TripCustomizeDayCard({
    super.key,
    required this.draft,
    required this.dayIndex,
    required this.date,
    required this.dayLimitMinutes,
    required this.flagged,
    required this.selectedSpotId,
    required this.onSelect,
    required this.onRemove,
    required this.onAddPlaces,
    required this.onDeleteDay,
    required this.onDrop,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  int get dayNumber => draft.firstDayNumber + dayIndex;

  bool get frozen => draft.isFrozen(dayIndex);

  bool _accepts(TripPlaceDrag d) => draft.canDrop(d.spotId, dayIndex) == TripDraftBlock.none;

  @override
  Widget build(BuildContext context) {
    final spots = draft.days[dayIndex].spots;
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final artSize = narrow ? 62.0 : 72.0;
    final radius = DS.br(kMealsRadius);
    Widget card(bool hover, bool refused) => DecoratedBox(
          key: ValueKey('customize-day-$dayIndex'),
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: radius,
            boxShadow: [BoxShadow(color: ListingTone.indigo.shadow, offset: DS.shadowOffset(const Offset(1.1, 6)), blurRadius: DS.shadowBlur(14))],
          ),
          position: DecorationPosition.background,
          child: DecoratedBox(
            key: flagged ? ValueKey('customize-day-error-$dayIndex') : null,
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: flagged ? Border.all(color: TripLook.error, width: DS.s(2.5)) : null,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(context, spots.length, DS.s(narrow ? 84.0 : 96.0)),
                  Stack(
                    children: [
                      Padding(
                        padding: DS.insets(l: 12, t: 10, r: 12, b: 12),
                        child: spots.isEmpty ? _empty(hover) : _rows(context, hover),
                      ),
                      if (refused)
                        Positioned.fill(
                          child: Container(
                            color: DesignColors.surface.withValues(alpha: Alpha.v92),
                            padding: DS.all(12),
                            alignment: Alignment.center,
                            child: const TripCustomizeDashedNote(TripStringsCustomize.dayFullDrop),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
    final body = frozen
        ? Opacity(opacity: Alpha.v55, child: card(false, false))
        : DragTarget<TripPlaceDrag>(
            onWillAcceptWithDetails: (det) => _accepts(det.data),
            onAcceptWithDetails: (det) => onDrop(det.data, spots.length),
            builder: (context, cand, rej) => card(cand.isNotEmpty, rej.isNotEmpty),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (flagged)
          Container(
            margin: DS.insets(l: 18, t: 8, r: 18),
            padding: DS.sym(h: 16, v: 12),
            decoration: BoxDecoration(color: TripLook.errorSurface, borderRadius: DS.circular(16)),
            child: Text(TripStringsCustomize.emptyDayError(dayNumber), style: Ink3D.text(13, FontWeight.w600, TripLook.errorText)),
          ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(30), DS.s(16), DS.gv(16)), child: body),
            Positioned(
              left: DS.s(20),
              top: 0,
              child: IgnorePointer(
                child: Opacity(
                  opacity: frozen ? Alpha.v55 : 1,
                  child: Art3D(asset: ListingArt.calendar, size: artSize, halo: artSize + 4, haloColor: DesignColors.tint(DesignColors.surface, Alpha.v22)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _header(BuildContext context, int count, double artRoom) {
    const white = DesignColors.surface;
    final load = draft.estimateMinutes(dayIndex);
    final full = count >= TripConstants.maxSpotsPerDay;
    final busy = count > 0 && TripDayLoad.isOver(load, dayLimitMinutes);
    return Container(
      constraints: BoxConstraints(minHeight: DS.s(80)),
      padding: EdgeInsets.fromLTRB(artRoom, DS.s(12), DS.s(10), DS.s(12)),
      decoration: BoxDecoration(gradient: ListingTone.indigo.gradient),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: DS.s(14),
                      height: DS.s(14),
                      decoration: BoxDecoration(color: TripLook.dayColor(dayNumber), shape: BoxShape.circle, border: Border.all(color: white, width: DS.s(2.5))),
                    ),
                    Gap.h(8),
                    Expanded(
                      child: Text(
                        TripStringsCustomize.dayTitle(dayNumber, date),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Ink3D.text(16, FontWeight.w700, white, height: 1.25),
                      ),
                    ),
                  ],
                ),
                Gap.v(6),
                Wrap(
                  spacing: DS.gh(8),
                  runSpacing: DS.gv(4),
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(TripStringsCustomize.span(load), style: Ink3D.text(12.5, FontWeight.w600, white)),
                    full
                        ? _pill(TripStringsCustomize.full, fill: TripLook.errorSurface, ink: TripLook.errorText)
                        : _pill(TripStringsCustomize.placesChip(count)),
                    if (busy) _pill(TripStringsCustomize.busyDay, fill: TripLook.warningSurface, ink: TripLook.warningText),
                  ],
                ),
              ],
            ),
          ),
          if (!frozen) _menu(context),
        ],
      ),
    );
  }

  Widget _menu(BuildContext context) {
    return PopupMenuButton<int>(
      key: ValueKey('customize-day-menu-$dayIndex'),
      tooltip: TripStringsCustomize.dayMenu,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: DS.circular(14)),
      color: DesignColors.surface,
      onSelected: (_) => onDeleteDay(),
      itemBuilder: (_) => [
        PopupMenuItem<int>(
          value: 0,
          child: Text(TripStringsCustomize.deleteDay, style: Ink3D.text(14, FontWeight.w600, TripLook.errorText)),
        ),
      ],
      child: Container(
        width: DS.s(36),
        height: DS.s(36),
        decoration: BoxDecoration(color: DesignColors.surface, shape: BoxShape.circle, boxShadow: DS.shadows(Form3D.onCard)),
        child: Icon(Icons.more_vert_rounded, size: DS.s(20), color: ListingTone.indigo.text),
      ),
    );
  }

  Widget _pill(String text, {Color? fill, Color? ink}) => Container(
        padding: DS.sym(h: 10, v: 3),
        decoration: BoxDecoration(color: fill ?? DesignColors.tint(DesignColors.surface, Alpha.v26), borderRadius: DS.circular(10)),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w700, ink ?? DesignColors.surface)),
      );

  Widget _empty(bool hover) {
    final rest = draft.days[dayIndex].restDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hover) const _InsertLine(),
        Gap.v(4),
        Text(
          rest ? TripStringsCustomize.restDay : TripStringsCustomize.noPlacesYet,
          textAlign: TextAlign.center,
          style: Ink3D.text(15, FontWeight.w700, Ink3D.title),
        ),
        Gap.v(4),
        Text(TripStringsCustomize.addOrDelete, textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.sub)),
        if (!frozen) ...[
          Gap.v(14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: DS.gh(12),
            runSpacing: DS.gv(10),
            children: [
              GradientPillButton(
                key: ValueKey('customize-empty-add-$dayIndex'),
                tone: ListingTone.indigo,
                label: TripStringsCustomize.addPlaces,
                expand: false,
                height: 44,
                fontSize: _buttonFont,
                onTap: onAddPlaces,
              ),
              WhitePillButton(
                key: ValueKey('customize-empty-delete-$dayIndex'),
                tone: ListingTone.indigo,
                label: TripStringsCustomize.deleteDay,
                danger: true,
                expand: false,
                height: 44,
                fontSize: _buttonFont,
                onTap: onDeleteDay,
              ),
            ],
          ),
        ],
        Gap.v(4),
      ],
    );
  }

  Widget _rows(BuildContext context, bool hoverEnd) {
    final spots = draft.days[dayIndex].spots;
    final roads = <int?>[
      for (var i = 0; i < spots.length; i++)
        i == spots.length - 1
            ? null
            : TripDayLoad.estimateMinutes(
                (lat: spots[i].latitude, lng: spots[i].longitude),
                (lat: spots[i + 1].latitude, lng: spots[i + 1].longitude),
              ),
    ];
    final starts = TripDayTimeline.starts(visits: [for (final s in spots) s.visitMinutes], roads: roads);
    final color = TripLook.dayColor(dayNumber);
    final full = spots.length >= TripConstants.maxSpotsPerDay;
    Widget row(int i) {
      final s = spots[i];
      final r = TripCustomizeSpotRow(
        spot: s,
        day: dayIndex,
        index: i,
        color: color,
        time: TripDayTimeline.clock(starts[i]),
        driveMinutes: roads[i],
        frozen: frozen,
        selected: selectedSpotId == s.id,
        onTap: () => onSelect(s.id),
        onRemove: () => onRemove(s.id),
        onDragStarted: onDragStarted,
        onDragUpdate: onDragUpdate,
        onDragEnd: onDragEnd,
      );
      if (frozen) return r;
      return DragTarget<TripPlaceDrag>(
        key: ValueKey('customize-slot-${s.id}'),
        onWillAcceptWithDetails: (det) => det.data.spotId == s.id || _accepts(det.data),
        onAcceptWithDetails: (det) {
          if (det.data.spotId != s.id) onDrop(det.data, i);
        },
        builder: (context, cand, rej) {
          final line = cand.any((d) => d != null && d.spotId != s.id);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [if (line) const _InsertLine(), r],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < spots.length; i++) row(i),
        if (hoverEnd) const _InsertLine(),
        if (!frozen && !full)
          Padding(
            padding: EdgeInsets.only(top: DS.gv(10)),
            child: DashedAddRow3D(
              key: ValueKey('customize-add-$dayIndex'),
              tone: ListingTone.indigo,
              label: TripStringsCustomize.addPlaces,
              onTap: onAddPlaces,
              margin: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}

class _InsertLine extends StatelessWidget {
  const _InsertLine();

  @override
  Widget build(BuildContext context) {
    final color = ListingTone.indigo.button;
    return Padding(
      key: const ValueKey('customize-insert-line'),
      padding: DS.sym(v: 6),
      child: Row(
        children: [
          Container(width: DS.s(10), height: DS.s(10), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          Expanded(child: Container(height: DS.s(3), decoration: BoxDecoration(color: color, borderRadius: DS.circular(2)))),
        ],
      ),
    );
  }
}
