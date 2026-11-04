import 'package:flutter/material.dart';
import '../../../widgets/selectable_chip.dart';
import '../trip_colors.dart';

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
        curve: Curves.easeOut,
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
            if (d > 1) const SizedBox(width: 8),
            SelectableChip(
              label: 'Day $d',
              selected: selected == d,
              activeColor: TripColors.dayColor(d),
              onTap: () => widget.onChanged(d),
            ),
          ],
          if (widget.includeAll) ...[
            const SizedBox(width: 8),
            SelectableChip(
              label: 'All',
              selected: selected == TripDayChips.all,
              activeColor: TripColors.accentDark,
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
          if (i > 0) const SizedBox(width: 8),
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
                _atStart ? Colors.white : Colors.transparent,
                Colors.white,
                Colors.white,
                _atEnd ? Colors.white : Colors.transparent,
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
    void tap() => widget.onChanged(day);
    return GestureDetector(
      key: _keyOf(day),
      behavior: HitTestBehavior.opaque,
      onTap: tap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44),
          child: SelectableChip(
            label: label,
            selected: widget.selected == day,
            activeColor: isAll ? TripColors.accentDark : TripColors.dayColor(day),
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
            onTap: tap,
          ),
        ),
      ),
    );
  }
}
