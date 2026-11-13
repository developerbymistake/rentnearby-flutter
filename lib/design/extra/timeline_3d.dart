import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'motion_kit.dart';

enum TimelineState { done, current, todo }

class TimelineItem {
  const TimelineItem({
    required this.title,
    this.subtitle,
    this.art,
    this.badge,
    this.dotColor,
    this.state = TimelineState.todo,
    this.trailing,
    this.child,
    this.onTap,
    this.faded = false,
  });

  final String title;
  final String? subtitle;
  final String? art;
  final String? badge;
  final Color? dotColor;
  final TimelineState state;
  final Widget? trailing;
  final Widget? child;
  final VoidCallback? onTap;
  final bool faded;

  bool get hasNode => art != null || badge != null || dotColor != null;
}

class Timeline3D extends StatelessWidget {
  const Timeline3D({super.key, required this.tone, required this.items, this.dense = false, this.lineColor});

  final ListingTone tone;
  final List<TimelineItem> items;
  final bool dense;
  final Color? lineColor;

  static const Color _idle = Color(0xFFE6E9F0);

  Color _line(TimelineItem item) => lineColor ?? (item.state == TimelineState.done ? tone.g1 : _idle);

  Widget _node(TimelineItem item) {
    final on = item.state != TimelineState.todo;
    if (item.art != null) {
      return SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(color: tone.haloBase.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14))),
            ),
            Art3D(asset: item.art!, size: 40, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.25),
          ],
        ),
      );
    }
    if (item.badge != null) {
      return Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? null : _idle,
          gradient: on ? tone.gradient : null,
          boxShadow: item.state == TimelineState.current ? [BoxShadow(color: tone.shadow, offset: const Offset(1.1, 3), blurRadius: 6)] : null,
        ),
        child: item.state == TimelineState.done
            ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
            : Text(item.badge!, textScaler: TextScaler.noScaling, style: Ink3D.text(13, FontWeight.w700, on ? Colors.white : Ink3D.grey, height: 1, letterSpacing: 0)),
      );
    }
    final c = item.dotColor!;
    final size = dense ? 12.0 : 24.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: on ? c : Colors.white, border: Border.all(color: c, width: dense ? 3 : 5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rail = dense ? 30.0 : 44.0;
    final lineW = dense ? 3.0 : 4.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) _row(context, i, rail, lineW),
      ],
    );
  }

  Widget _row(BuildContext context, int i, double rail, double lineW) {
    final item = items[i];
    final last = i == items.length - 1;
    final above = i == 0 ? null : _line(items[i - 1]);
    final below = last ? null : _line(item);
    Widget seg(Color? c) => Container(width: lineW, color: c);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.title.isNotEmpty || item.trailing != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.title.isNotEmpty) Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w700, Ink3D.title)),
                    if (item.subtitle != null) Text(item.subtitle!, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.sub, height: 1.4)),
                  ],
                ),
              ),
              if (item.trailing != null) ...[const SizedBox(width: 8), item.trailing!],
            ],
          ),
        if (item.child != null) item.child!,
      ],
    );
    Widget content = Padding(
      padding: EdgeInsets.only(left: 12, top: item.hasNode ? (dense ? 0 : 2) : 0, bottom: last ? 0 : (dense ? 12 : 16)),
      child: Opacity(opacity: item.faded ? 0.5 : 1, child: text),
    );
    if (item.onTap != null) {
      content = Semantics(
        button: true,
        child: PressScale(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: item.onTap, child: content)),
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: rail,
            child: ExcludeSemantics(
              child: Column(
                children: [
                  if (item.hasNode) ...[
                    SizedBox(height: dense ? 3 : 2, child: seg(above)),
                    Opacity(opacity: item.faded ? 0.5 : 1, child: _node(item)),
                  ],
                  Expanded(child: seg(below ?? (item.hasNode ? null : above))),
                ],
              ),
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class RailStop3D extends StatelessWidget {
  const RailStop3D({super.key, required this.tone, required this.art, required this.title, this.subtitle, this.tag, this.connectorBelow = true, this.trailing});

  final ListingTone tone;
  final String art;
  final String title;
  final String? subtitle;
  final String? tag;
  final bool connectorBelow;
  final Widget? trailing;

  static const double topRoom = 30;
  static const BorderRadius radius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(24), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, topRoom, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: radius,
              boxShadow: [BoxShadow(color: Color(0x409E9E9E), offset: Offset(1.1, 1.1), blurRadius: 10)],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(decoration: BoxDecoration(color: tone.haloBase.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(18))),
                      ),
                      Positioned(left: -4, top: -14, child: Art3D(asset: art, size: 66, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, Ink3D.title)),
                      if (tag != null) Text(tag!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w700, const Color(0xFFB35C00))),
                      if (subtitle != null) Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.sub)),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
          if (connectorBelow)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(margin: const EdgeInsets.only(left: 42), width: 4, height: 26, color: tone.g1),
            ),
        ],
      ),
    );
  }
}
