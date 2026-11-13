import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:bakhli/design/design.dart';
import 'package:get/get.dart';
import '../controllers/trip_plan_controller.dart';
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
  final _order = <String>[];
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
      final target = _snapOffset(selected);
      if (target == null) return;
      _scroll.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.fastOutSlowIn);
    });
  }

  double? _snapOffset(String selected) {
    if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) return null;
    final ids = _order;
    final at = ids.indexOf(selected);
    final box = _keys[selected]?.currentContext?.findRenderObject();
    if (at < 0 || box is! RenderBox) return null;
    final viewport = RenderAbstractViewport.of(box);
    final lead = widget.padding.resolve(Directionality.of(context)).left;
    final selStart = viewport.getOffsetToReveal(box, 0).offset - lead;
    final selEnd = viewport.getOffsetToReveal(box, 1).offset + lead;
    var target = selStart;
    final prev = at > 0 ? _keys[ids[at - 1]]?.currentContext?.findRenderObject() : null;
    if (prev is RenderBox) {
      final prevStart = viewport.getOffsetToReveal(prev, 0).offset - lead;
      if (prevStart >= selEnd) target = prevStart;
    }
    final pos = _scroll.position;
    return target.clamp(pos.minScrollExtent, pos.maxScrollExtent);
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
      _order.clear();
      final chips = <Widget>[
        _chip(
          id: _allKey,
          label: TripStringsMcdA2.all,
          selected: focus == TripMapFocus.all,
          color: DesignColors.primary,
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
            color: TripKit.dayColor(start),
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
            iconAsset: TravelIcon.pin,
            color: DesignColors.primary,
            onTap: () => widget.onLeg(k),
          ),
        ));
        for (var d = start; d <= end; d++) {
          if (p.legIndexOf(d) != k) continue;
          chips.add(_chip(
            id: 'd$d',
            label: TripStringsMcdA2.dayLabel(d),
            selected: focus == TripMapFocus.day && day == d,
            color: TripKit.dayColor(d),
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
                  _atStart ? DesignColors.surface : Colors.transparent,
                  DesignColors.surface,
                  DesignColors.surface,
                  _atEnd ? DesignColors.surface : Colors.transparent,
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
                    if (i > 0) const SizedBox(width: 10),
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
    String? iconAsset,
  }) {
    final art = id == _allKey
        ? ListingArt.worldMap
        : iconAsset != null
            ? ListingArt.pushpin
            : ListingArt.calendar;
    _order.add(id);
    return KeyedSubtree(
      key: _keyOf(id),
      child: ChipCP(tone: ListingTone.indigo, art: art, label: label, off: !selected, onTap: onTap),
    );
  }
}
