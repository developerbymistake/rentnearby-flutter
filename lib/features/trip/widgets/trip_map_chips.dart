import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../widgets/selectable_chip.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_colors.dart';
import '../trip_strings_mca_a3.dart';
import '../trip_strings_mcd_a2.dart';
import '../utils/trip_map_rules.dart';

class TripMapChips extends StatefulWidget {
  final ValueChanged<int> onDay;
  final ValueChanged<int> onLeg;
  final VoidCallback onAll;
  final EdgeInsetsGeometry padding;

  const TripMapChips({
    super.key,
    required this.onDay,
    required this.onLeg,
    required this.onAll,
    this.padding = EdgeInsets.zero,
  });

  static const int _nameMax = 10;

  static String shortName(String name) =>
      name.length <= _nameMax ? name : '${name.substring(0, _nameMax).trimRight()}…';

  @override
  State<TripMapChips> createState() => _TripMapChipsState();
}

class _TripMapChipsState extends State<TripMapChips> {
  static const double _fade = 16;
  static const String _allKey = 'all';

  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};
  bool _atStart = true;
  bool _atEnd = true;
  String? _lastSelected;

  GlobalKey _keyOf(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _afterFrame(String selected) {
    if (_lastSelected == selected) return;
    _lastSelected = selected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateEdges();
      final ctx = _keys[selected]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(ctx, alignment: 0.5, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
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
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final p = c.plan.value;
      final focus = c.mapFocus;
      final leg = c.selectedMapLeg.value;
      final day = c.selectedMapDay.value;
      if (p == null) return const SizedBox.shrink();
      final selected = switch (focus) {
        TripMapFocus.all => _allKey,
        TripMapFocus.city => 'c$leg',
        TripMapFocus.day => 'd$day',
      };
      _afterFrame(selected);
      final chips = <Widget>[
        _chip(
          id: _allKey,
          label: TripStringsMcdA2.all,
          selected: focus == TripMapFocus.all,
          color: TripColors.accentDark,
          onTap: widget.onAll,
        ),
      ];
      for (final l in p.legs) {
        final k = l.index;
        final start = p.legStart(k);
        final end = p.legEnd(k);
        if (start < 1) continue;
        if (p.isSingleDayLeg(k)) {
          chips.add(_chip(
            id: 'd$start',
            label: TripStringsMcdA2.dayCity(start, TripMapChips.shortName(l.cityName)),
            selected: focus == TripMapFocus.day && day == start,
            color: TripColors.dayColor(start),
            onTap: () => widget.onDay(start),
          ));
          continue;
        }
        final range = TripStringsMcaA3.dayRange(start, end);
        chips.add(Semantics(
          button: true,
          label: TripStringsMcdA2.citySemantics(l.cityName, range),
          excludeSemantics: true,
          child: _chip(
            id: 'c$k',
            label: TripMapChips.shortName(l.cityName),
            selected: focus == TripMapFocus.city && leg == k,
            color: TripColors.accentDark,
            icon: Iconsax.location,
            onTap: () => widget.onLeg(k),
          ),
        ));
        for (var d = start; d <= end; d++) {
          if (p.legIndexOf(d) != k) continue;
          chips.add(_chip(
            id: 'd$d',
            label: TripStringsMcdA2.dayLabel(d),
            selected: focus == TripMapFocus.day && day == d,
            color: TripColors.dayColor(d),
            onTap: () => widget.onDay(d),
          ));
        }
      }
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
              child: Row(
                children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    chips[i],
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _chip({
    required String id,
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      key: _keyOf(id),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44),
          child: SelectableChip(
            label: label,
            selected: selected,
            activeColor: color,
            icon: icon,
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
