import 'package:flutter/material.dart';

import '../../../../design/design.dart';

/// One track with a filled pill that slides to the selected cell. Cells share the full row; when they would be
/// narrower than [minCell] the row scrolls sideways and keeps the selected cell in view. [selected] < 0 hides the pill.
class SlidingTabs extends StatefulWidget {
  const SlidingTabs({super.key, required this.labels, required this.selected, required this.onTap, required this.tone, this.margin});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onTap;
  final ListingTone tone;
  final EdgeInsets? margin;

  static const double cellHeight = 40;
  static const double minCell = 60;

  static Key tabKey(int i) => ValueKey('sliding_tab_$i');

  @override
  State<SlidingTabs> createState() => _SlidingTabsState();
}

class _SlidingTabsState extends State<SlidingTabs> {
  final _scroll = ScrollController();
  double _cell = 0;

  @override
  void didUpdateWidget(SlidingTabs old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _reveal() {
    if (!mounted || !_scroll.hasClients || widget.selected < 0 || _cell <= 0) return;
    final p = _scroll.position;
    final left = widget.selected * _cell;
    final right = left + _cell;
    double? to;
    if (left < p.pixels) to = left;
    if (right > p.pixels + p.viewportDimension) to = right - p.viewportDimension;
    if (to != null) _scroll.animateTo(to.clamp(0, p.maxScrollExtent), duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  Widget _track(double width, double cell) {
    final n = widget.labels.length;
    final sel = widget.selected;
    final tone = widget.tone;
    return SizedBox(
      width: width,
      height: DS.s(SlidingTabs.cellHeight),
      child: Stack(
        children: [
          if (sel >= 0 && sel < n)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              left: sel * cell,
              top: 0,
              bottom: 0,
              width: cell,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: tone.gradient,
                  borderRadius: DS.circular(SlidingTabs.cellHeight / 2),
                  boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: Alpha.scrim), offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(8))],
                ),
              ),
            ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                SizedBox(
                  width: cell,
                  child: Tap3D(
                    tapKey: SlidingTabs.tabKey(i),
                    onTap: () => widget.onTap(i),
                    selected: i == sel,
                    label: widget.labels[i],
                    exclude: true,
                    child: Container(
                      height: DS.s(SlidingTabs.cellHeight),
                      alignment: Alignment.center,
                      padding: DS.sym(h: 6),
                      child: Text(
                        widget.labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Ink3D.text(13, FontWeight.w700, i == sel ? DesignColors.onPrimary : Ink3D.body, letterSpacing: 0),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.labels.length;
    return Container(
      margin: widget.margin ?? EdgeInsets.zero,
      padding: DS.all(4),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DS.circular(SlidingTabs.cellHeight / 2 + 4),
        boxShadow: [BoxShadow(color: DesignColors.textStrong.withValues(alpha: Alpha.tint), offset: DS.shadowOffset(const Offset(0, 2)), blurRadius: DS.shadowBlur(8))],
      ),
      child: LayoutBuilder(builder: (context, box) {
        if (n == 0) return SizedBox(height: DS.s(SlidingTabs.cellHeight));
        final minCell = MediaQuery.textScalerOf(context).scale(DS.s(SlidingTabs.minCell));
        final even = box.maxWidth / n;
        if (even >= minCell) {
          _cell = even;
          return _track(box.maxWidth, even);
        }
        _cell = minCell;
        WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
        return ClipRRect(
          borderRadius: DS.circular(SlidingTabs.cellHeight / 2),
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: _track(minCell * n, minCell),
          ),
        );
      }),
    );
  }
}
