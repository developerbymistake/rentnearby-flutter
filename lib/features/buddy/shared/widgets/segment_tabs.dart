import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../buddy_look.dart';

class SegmentTabs extends StatefulWidget {
  const SegmentTabs({super.key, required this.labels, required this.selected, required this.onTap, required this.tone, this.counts = const {}, this.solidBadges = const {}, this.margin, this.dayDots, this.compact = false});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onTap;
  final ListingTone tone;
  final Map<int, int> counts;
  final Set<int> solidBadges;
  final EdgeInsets? margin;
  final List<Color>? dayDots;
  final bool compact;

  @override
  State<SegmentTabs> createState() => _SegmentTabsState();
}

class _SegmentTabsState extends State<SegmentTabs> {
  final _scroll = ScrollController();
  final _keys = <GlobalKey>[];
  final _fade = ValueNotifier<(bool, bool)>((false, false));

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateFade);
    _afterLayout();
  }

  @override
  void didUpdateWidget(SegmentTabs old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected || old.labels.length != widget.labels.length) _afterLayout();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _afterLayout() {
    if (!widget.compact) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateFade();
      if (widget.selected < _keys.length) {
        final ctx = _keys[widget.selected].currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 200), alignment: 0.5);
      }
    });
  }

  void _updateFade() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final v = (p.pixels > 1, p.pixels < p.maxScrollExtent - 1);
    if (v != _fade.value) _fade.value = v;
  }

  Color? _dot(int i) {
    final d = widget.dayDots;
    return d != null && i < d.length ? d[i] : null;
  }

  Widget _cell(int i, {required bool fit}) => _Cell(
        label: widget.labels[i],
        on: i == widget.selected,
        count: widget.counts[i] ?? 0,
        solidBadge: widget.solidBadges.contains(i),
        tone: widget.tone,
        dot: _dot(i),
        fit: fit,
        onTap: () => widget.onTap(i),
      );

  Widget _compactRow() {
    while (_keys.length < widget.labels.length) {
      _keys.add(GlobalKey());
    }
    final row = NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateFade();
        });
        return false;
      },
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        child: Row(children: [for (var i = 0; i < widget.labels.length; i++) KeyedSubtree(key: _keys[i], child: _cell(i, fit: false))]),
      ),
    );
    return ValueListenableBuilder<(bool, bool)>(
      valueListenable: _fade,
      builder: (_, f, child) {
        if (!f.$1 && !f.$2) return child!;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => LinearGradient(
            colors: const [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
            stops: [0, f.$1 ? 0.08 : 0, f.$2 ? 0.92 : 1, 1],
          ).createShader(r),
          child: child,
        );
      },
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: widget.margin ?? DS.insets(l: 18, t: 18, r: 18),
        padding: DS.all(4),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: DS.circular(24),
          boxShadow: [BoxShadow(color: DesignColors.textStrong.withValues(alpha: Alpha.tint), offset: DS.shadowOffset(const Offset(0, 2)), blurRadius: DS.shadowBlur(8))],
        ),
        child: widget.compact
            ? _compactRow()
            : Row(
                children: [
                  for (var i = 0; i < widget.labels.length; i++) Expanded(child: _cell(i, fit: true)),
                ],
              ),
      );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.on, required this.count, required this.solidBadge, required this.tone, required this.onTap, this.dot, required this.fit});

  final String label;
  final bool on;
  final int count;
  final bool solidBadge;
  final ListingTone tone;
  final VoidCallback onTap;
  final Color? dot;
  final bool fit;

  @override
  Widget build(BuildContext context) {
    final textColor = on ? DesignColors.onPrimary : BuddyLook.subText;
    return Tap3D(
      onTap: onTap,
      selected: on,
      label: count > 0 ? '$label, $count' : label,
      exclude: true,
      child: Container(
        constraints: BoxConstraints(minHeight: DS.s(40)),
        alignment: Alignment.center,
        padding: DS.sym(h: 6),
        decoration: on
            ? BoxDecoration(
                gradient: tone.gradient,
                borderRadius: DS.circular(20),
                boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: Alpha.scrim), offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(8))],
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null) ...[
              Container(width: DS.s(8), height: DS.s(8), decoration: BoxDecoration(color: dot, shape: BoxShape.circle, boxShadow: on && dot!.a > 0 ? [BoxShadow(color: DesignColors.onPrimary, spreadRadius: DS.s(1.5))] : null)),
              Gap.h(6),
            ],
            if (fit)
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, textColor, letterSpacing: 0)))
            else
              Text(label, maxLines: 1, softWrap: false, style: Ink3D.text(13, FontWeight.w700, textColor, letterSpacing: 0)),
            if (count > 0) ...[
              Gap.h(6),
              Container(
                constraints: BoxConstraints(minWidth: DS.s(20), minHeight: DS.s(20)),
                padding: DS.sym(h: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: solidBadge || !on ? BuddyLook.countBadge : DesignColors.surface, borderRadius: DS.circular(10)),
                child: Text('$count',
                    maxLines: 1, textScaler: TextScaler.noScaling, style: Ink3D.text(11, FontWeight.w700, solidBadge || !on ? DesignColors.onPrimary : tone.g2, letterSpacing: 0)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
