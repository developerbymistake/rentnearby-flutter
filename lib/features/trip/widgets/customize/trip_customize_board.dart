import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../trip_strings_customize.dart';
import '../../utils/trip_leg_draft.dart';
import 'trip_customize_day_card.dart';
import 'trip_customize_spot_row.dart';
import 'trip_remove_place_sheet.dart';

// Lays out one city's day cards in a Column; the parent supplies the Scrollable that edge auto-scroll drives.
class TripCustomizeBoard extends StatefulWidget {
  final TripLegDraft draft;
  final VoidCallback onChanged;
  final ValueChanged<int> onAddPlaces;
  final ValueChanged<int> onDeleteDay;
  final DateTime? firstDate;
  final int dayLimitMinutes;

  const TripCustomizeBoard({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onAddPlaces,
    required this.onDeleteDay,
    required this.dayLimitMinutes,
    this.firstDate,
  });

  @override
  State<TripCustomizeBoard> createState() => _TripCustomizeBoardState();
}

class _TripCustomizeBoardState extends State<TripCustomizeBoard> {
  static const double _autoScrollVelocity = 20;

  EdgeDraggingAutoScroller? _auto;
  Rect? _pointer;
  String? _selected;
  String? _dragging;
  final ValueNotifier<bool> _overSlot = ValueNotifier<bool>(false);

  TripLegDraft get _draft => widget.draft;

  @override
  void dispose() {
    _auto?.stopAutoScroll();
    _overSlot.dispose();
    super.dispose();
  }

  DateTime? _dateOf(int i) {
    final d = widget.firstDate;
    return d == null ? null : DateTime(d.year, d.month, d.day + i);
  }

  void _dragStarted(String spotId) {
    final scrollable = Scrollable.maybeOf(context);
    _auto = scrollable == null
        ? null
        : EdgeDraggingAutoScroller(scrollable, velocityScalar: _autoScrollVelocity, onScrollViewScrolled: _keepScrolling);
    setState(() {
      _selected = null;
      _dragging = spotId;
    });
  }

  void _dragUpdate(DragUpdateDetails d) {
    _pointer = Rect.fromCenter(center: d.globalPosition, width: DS.s(40), height: DS.s(56));
    _auto?.startAutoScrollIfNecessary(_pointer!);
  }

  // A finger held still sends no updates, so the scroller is fed the last pointer again after each step.
  void _keepScrolling() {
    final p = _pointer;
    if (p != null) _auto?.startAutoScrollIfNecessary(p);
  }

  void _dragEnd() {
    _auto?.stopAutoScroll();
    _auto = null;
    _pointer = null;
    _overSlot.value = false;
    if (mounted && _dragging != null) setState(() => _dragging = null);
  }

  void _drop(TripPlaceDrag d, int toDay, int slot) {
    final from = _draft.dayOfSpot(d.spotId);
    if (from == null) return;
    final fromIndex = _draft.days[from].spots.indexWhere((s) => s.id == d.spotId);
    final at = from == toDay && fromIndex < slot ? slot - 1 : slot;
    if (from == toDay && at == fromIndex) return;
    if (_draft.move(d.spotId, toDay, at) != TripDraftBlock.none) return;
    HapticFeedback.mediumImpact();
    setState(() {});
    widget.onChanged();
  }

  Future<void> _remove(String spotId) async {
    final day = _draft.dayOfSpot(spotId);
    if (day == null) return;
    final spot = _draft.days[day].spots.firstWhere((s) => s.id == spotId);
    final ok = await TripRemovePlaceSheet.show(context, spot: spot, dayLabel: TripStringsCustomize.dayLabel(_draft.firstDayNumber + day));
    if (!ok || !mounted) return;
    if (_draft.remove(spotId) != TripDraftBlock.none) return;
    setState(() => _selected = null);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _draft.dayCount; i++)
          TripCustomizeDayCard(
            key: ValueKey('customize-card-$i'),
            draft: _draft,
            dayIndex: i,
            date: _dateOf(i),
            dayLimitMinutes: widget.dayLimitMinutes,
            selectedSpotId: _selected,
            draggingSpotId: _dragging,
            onSelect: (id) => setState(() => _selected = _selected == id ? null : id),
            onRemove: _remove,
            onAddPlaces: () => widget.onAddPlaces(i),
            onDeleteDay: () => widget.onDeleteDay(i),
            onDrop: (d, slot) => _drop(d, i, slot),
            onDragStarted: _dragStarted,
            onDragUpdate: _dragUpdate,
            onDragEnd: _dragEnd,
            overSlot: _overSlot,
          ),
      ],
    );
  }
}
