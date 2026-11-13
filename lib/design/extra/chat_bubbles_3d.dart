import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'motion_kit.dart';

double _scale(BuildContext context) => MediaQuery.textScalerOf(context).scale(1);

enum ChatTicks { none, sent, delivered, read }

class _Ticks extends StatelessWidget {
  const _Ticks(this.ticks, this.color);

  final ChatTicks ticks;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (ticks == ChatTicks.none) return const SizedBox(height: 14);
    final label = switch (ticks) { ChatTicks.sent => 'Sent', ChatTicks.delivered => 'Delivered', _ => 'Read' };
    return Semantics(
      label: label,
      child: Icon(
        ticks == ChatTicks.sent ? Icons.done_rounded : Icons.done_all_rounded,
        size: 15,
        color: ticks == ChatTicks.read ? color : color.withValues(alpha: 0.65),
      ),
    );
  }
}

class ChatBubble3D extends StatelessWidget {
  const ChatBubble3D({super.key, required this.tone, required this.text, required this.mine, this.ticks = ChatTicks.none, this.dimmed = false});

  final ListingTone tone;
  final String text;
  final bool mine;
  final ChatTicks ticks;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 262),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? null : Colors.white,
        gradient: mine ? tone.gradient : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 8),
          bottomRight: Radius.circular(mine ? 8 : 16),
        ),
        boxShadow: mine
            ? [BoxShadow(color: tone.shadow.withValues(alpha: 0.45), offset: const Offset(1.1, 4), blurRadius: 10)]
            : const [BoxShadow(color: Color(0x4D9E9E9E), offset: Offset(1.1, 3), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: Text(text, style: Ink3D.text(14, FontWeight.w400, mine ? Colors.white : Ink3D.body, height: 1.4)),
          ),
          if (mine && ticks != ChatTicks.none) Padding(padding: const EdgeInsets.only(top: 2), child: _Ticks(ticks, Colors.white)),
        ],
      ),
    );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Opacity(opacity: dimmed ? 0.55 : 1, child: bubble),
    );
  }
}

class ChatAnswerPill extends StatelessWidget {
  const ChatAnswerPill({super.key, required this.tone, required this.label, required this.onTap, this.negative = false});

  final ListingTone tone;
  final String label;
  final VoidCallback? onTap;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final c = negative ? const Color(0xFFE0525C) : tone.g2;
    final pill = Container(
      width: 244,
      constraints: BoxConstraints(minHeight: 42 * _scale(context).clamp(1.0, 1.4)),
      padding: const EdgeInsets.fromLTRB(18, 6, 14, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x4D9E9E9E), offset: Offset(1.1, 3), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, c))),
          Icon(Icons.chevron_right_rounded, size: 20, color: c),
        ],
      ),
    );
    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        child: PressScale(
          enabled: onTap != null,
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: Opacity(opacity: onTap == null ? 0.5 : 1, child: pill)),
        ),
      ),
    );
  }
}

class ChatSystemNote extends StatelessWidget {
  const ChatSystemNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: const Color(0x17253840), borderRadius: BorderRadius.circular(14)),
          child: Text(text, textAlign: TextAlign.center, style: Ink3D.text(12, FontWeight.w500, Ink3D.sub)),
        ),
      ),
    );
  }
}

enum ChatButtonKind { primary, secondary, danger }

class ChatCardButton {
  const ChatCardButton({required this.label, required this.onTap, this.kind = ChatButtonKind.primary, this.icon, this.busy = false});

  final String label;
  final VoidCallback? onTap;
  final ChatButtonKind kind;
  final IconData? icon;
  final bool busy;
}

class ChatChip {
  const ChatChip(this.label, {this.selected = false, this.selectable = false, this.onTap});

  final String label;
  final bool selected;
  final bool selectable;
  final VoidCallback? onTap;
}

class ChatCard3D extends StatelessWidget {
  const ChatCard3D({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    required this.mine,
    this.subtitle,
    this.chips = const [],
    this.buttons = const [],
    this.body,
    this.ticks = ChatTicks.none,
    this.dimmed = false,
    this.width = 300,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final bool mine;
  final String? subtitle;
  final List<ChatChip> chips;
  final List<ChatCardButton> buttons;
  final Widget? body;
  final ChatTicks ticks;
  final bool dimmed;
  final double width;

  static const double topRoom = 30;
  static const BorderRadius radius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(32), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

  Widget _chip(BuildContext context, ChatChip c) {
    final ring = c.selected || c.selectable;
    final ink = c.selected ? Colors.white : (c.selectable ? tone.text : Ink3D.sub);
    final chip = Container(
      constraints: BoxConstraints(minHeight: 32 * _scale(context).clamp(1.0, 1.4)),
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: c.selected ? null : (c.selectable ? Colors.white : const Color(0xFFF2F3F8)),
        gradient: c.selected ? tone.gradient : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.selectable && !c.selected ? tone.haloBase.withValues(alpha: 0.5) : Colors.transparent, width: 1.5),
        boxShadow: c.selected ? [BoxShadow(color: tone.shadow.withValues(alpha: 0.45), offset: const Offset(1.1, 3), blurRadius: 6)] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ring) ...[
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.selected ? Colors.white : null,
                border: c.selected ? null : Border.all(color: tone.g2, width: 2),
              ),
              child: c.selected ? Icon(Icons.check_rounded, size: 12, color: tone.g2) : null,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(child: Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w600, ink))),
        ],
      ),
    );
    if (c.onTap == null) return chip;
    return Semantics(
      button: true,
      selected: c.selected,
      child: PressScale(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: c.onTap, child: chip)),
    );
  }

  Widget _button(BuildContext context, ChatCardButton b) {
    final primary = b.kind == ChatButtonKind.primary;
    final ink = switch (b.kind) { ChatButtonKind.primary => Colors.white, ChatButtonKind.secondary => tone.text, ChatButtonKind.danger => const Color(0xFFE0525C) };
    final off = b.onTap == null && !b.busy;
    final box = Container(
      constraints: BoxConstraints(minHeight: 44 * _scale(context).clamp(1.0, 1.3)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary ? null : Colors.white,
        gradient: primary ? tone.gradient : null,
        borderRadius: BorderRadius.circular(24),
        border: primary ? null : Border.all(color: b.kind == ChatButtonKind.danger ? const Color(0x59E0525C) : const Color(0xFFE6E8EE), width: 1.5),
        boxShadow: off
            ? null
            : primary
            ? [BoxShadow(color: tone.shadow.withValues(alpha: 0.5), offset: const Offset(1.1, 4), blurRadius: 8)]
            : const [BoxShadow(color: Color(0x599E9E9E), offset: Offset(3, 5), blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (b.busy) ...[
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.4, color: ink)),
            const SizedBox(width: 8),
          ] else if (b.icon != null) ...[
            Icon(b.icon, size: 18, color: ink),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(b.label, maxLines: 1, softWrap: false, style: Ink3D.text(14, FontWeight.w700, ink)),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      enabled: !off && !b.busy,
      child: PressScale(
        enabled: !off && !b.busy,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: b.busy ? null : b.onTap, child: Opacity(opacity: off ? 0.45 : 1, child: box)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: dimmed ? const Color(0xFFE9EDEA) : Colors.white,
        borderRadius: radius,
        boxShadow: dimmed ? null : const [BoxShadow(color: Color(0x529E9E9E), offset: Offset(1.1, 4), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 30),
            child: Padding(
              padding: const EdgeInsets.only(left: 62),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14.5, FontWeight.w700, dimmed ? const Color(0xFF8A948D) : Ink3D.title, height: 1.25, letterSpacing: 0)),
              ),
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(subtitle!, style: Ink3D.text(13, FontWeight.w400, Ink3D.sub, height: 1.4)),
            ),
          if (body != null) Padding(padding: const EdgeInsets.only(top: 10), child: body),
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(spacing: 6, runSpacing: 6, children: [for (final c in chips) _chip(context, c)]),
            ),
          if (buttons.isNotEmpty) const SizedBox(height: 5),
          for (final b in buttons) Padding(padding: const EdgeInsets.only(top: 9), child: _button(context, b)),
          if (mine)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(alignment: Alignment.centerRight, child: _Ticks(ticks, tone.g2)),
            ),
        ],
      ),
    );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Padding(
          padding: const EdgeInsets.only(top: topRoom),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              card,
              Positioned(
                left: 8,
                top: -30,
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: dimmed ? 0.55 : 1,
                    child: Art3D(asset: art, size: 66, halo: 70, haloColor: tone.haloBase.withValues(alpha: 0.16), shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatAskSlot extends StatelessWidget {
  const ChatAskSlot({super.key, required this.tone, required this.label, required this.onTap, this.enabled = true});

  final ListingTone tone;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  static const BorderRadius _radius = BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    final on = enabled && onTap != null;
    final slot = CustomPaint(
      foregroundPainter: _DashedBorder(color: tone.haloBase.withValues(alpha: 0.75), radius: _radius),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
        decoration: BoxDecoration(color: tone.haloBase.withValues(alpha: 0.08), borderRadius: _radius),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: tone.gradient,
                boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.5), offset: const Offset(1.1, 3), blurRadius: 6)],
              ),
              child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, tone.g2))),
          ],
        ),
      ),
    );
    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        button: true,
        enabled: on,
        child: PressScale(
          enabled: on,
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: on ? onTap : null, child: Opacity(opacity: on ? 1 : 0.5, child: slot)),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color, required this.radius});

  final Color color;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(radius.toRRect((Offset.zero & size).deflate(0.75)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius;
}
