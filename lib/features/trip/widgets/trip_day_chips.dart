import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'trip_ui.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';

class TripDayChips extends StatefulWidget {
  static const int all = 0;

  final int dayCount;
  final int selected;
  final ValueChanged<int> onChanged;
  final bool includeAll;
  final bool compact;
  final bool allFirst;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;

  const TripDayChips({
    super.key,
    required this.dayCount,
    required this.selected,
    required this.onChanged,
    this.includeAll = false,
    this.compact = false,
    this.allFirst = false,
    this.controller,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<TripDayChips> createState() => _TripDayChipsState();
}

class _TripDayChipsState extends State<TripDayChips> {
  static const double _fade = 16;

  final _keys = <int, GlobalKey>{};
  ScrollController? _own;
  bool _atStart = true;
  bool _atEnd = true;

  ScrollController get _scroll => widget.controller ?? (_own ??= ScrollController());

  GlobalKey _keyOf(int day) => _keys.putIfAbsent(day, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    if (widget.compact) _afterFrame();
  }

  @override
  void didUpdateWidget(TripDayChips old) {
    super.didUpdateWidget(old);
    if (!widget.compact) return;
    if (old.dayCount != widget.dayCount) _keys.removeWhere((d, _) => d > widget.dayCount);
    if (old.selected != widget.selected || old.dayCount != widget.dayCount) _afterFrame();
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  void _afterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateEdges();
      final ctx = _keys[widget.selected]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
      );
    });
  }

  void _updateEdges() {
    if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) return;
    final pos = _scroll.position;
    final start = pos.pixels <= pos.minScrollExtent + 1;
    final end = pos.pixels >= pos.maxScrollExtent - 1;
    if (start != _atStart || end != _atEnd) {
      setState(() {
        _atStart = start;
        _atEnd = end;
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.compact ? _buildCompact() : _buildDefault();

  Widget _buildDefault() {
    final dayCount = widget.dayCount;
    final selected = widget.selected;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: widget.controller,
      padding: widget.padding,
      child: Row(
        children: [
          for (var d = 1; d <= dayCount; d++) ...[
            if (d > 1) const SizedBox(width: 10),
            TripChoiceChip(
              label: 'Day $d',
              selected: selected == d,
              activeColor: TripLook.dayColor(d),
              onTap: () => widget.onChanged(d),
            ),
          ],
          if (widget.includeAll) ...[
            const SizedBox(width: 8),
            TripChoiceChip(
              label: 'All',
              selected: selected == TripDayChips.all,
              activeColor: TripLook.accentDark,
              onTap: () => widget.onChanged(TripDayChips.all),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompact() {
    final numeric = widget.dayCount > 3;
    final order = <int>[
      if (widget.includeAll && widget.allFirst) TripDayChips.all,
      for (var d = 1; d <= widget.dayCount; d++) d,
      if (widget.includeAll && !widget.allFirst) TripDayChips.all,
    ];
    final row = Row(
      children: [
        for (var i = 0; i < order.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          _compactChip(order[i], numeric),
        ],
      ],
    );
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _updateEdges();
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _updateEdges();
          return false;
        },
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) {
            final w = rect.width <= 0 ? 1.0 : rect.width;
            final f = (_fade / w).clamp(0.0, 0.5);
            return LinearGradient(
              colors: [
                _atStart ? FitnessAppTheme.white : Colors.transparent,
                FitnessAppTheme.white,
                FitnessAppTheme.white,
                _atEnd ? FitnessAppTheme.white : Colors.transparent,
              ],
              stops: [0, f, 1 - f, 1],
            ).createShader(rect);
          },
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _scroll,
            padding: widget.padding,
            child: row,
          ),
        ),
      ),
    );
  }

  Widget _compactChip(int day, bool numeric) {
    final isAll = day == TripDayChips.all;
    final label = isAll ? 'All' : (numeric ? '$day' : 'Day $day');
    return KeyedSubtree(
      key: _keyOf(day),
      child: ChipCP(
        tone: ListingTone.indigo,
        art: isAll ? ListingArt.worldMap : ListingArt.calendar,
        label: label,
        off: widget.selected != day,
        onTap: () => widget.onChanged(day),
      ),
    );
  }
}

class TripDayMultiChips extends StatelessWidget {
  final int dayCount;
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final String Function(int day)? groupOf;
  final List<int>? disabledDays;

  const TripDayMultiChips({
    super.key,
    required this.dayCount,
    required this.selected,
    required this.onToggle,
    this.groupOf,
    this.disabledDays,
  });

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<int>>{};
    for (var d = 1; d <= dayCount; d++) {
      groups.putIfAbsent(groupOf?.call(d) ?? '', () => []).add(d);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in groups.entries) ...[
          if (e.key.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Text(
                e.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: FitnessAppTheme.fontName, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: TripLook.textLight),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in e.value)
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
                  child: TripChoiceChip(
                    label: 'Day $d',
                    selected: selected.contains(d),
                    muted: disabledDays?.contains(d) ?? false,
                    activeColor: TripLook.dayColor(d),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    onTap: () {
                      if (!(disabledDays?.contains(d) ?? false)) onToggle(d);
                    },
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
