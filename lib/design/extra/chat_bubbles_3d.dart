import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'motion_kit.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/design_scale.dart';
import '../tokens/card_tokens.dart';

double _scale(BuildContext context) => MediaQuery.textScalerOf(context).scale(1);

enum ChatTicks { none, sent, delivered, read }

class _Ticks extends StatelessWidget {
  const _Ticks(this.ticks, this.color);

  final ChatTicks ticks;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (ticks == ChatTicks.none) return SizedBox(height: DS.s(14));
    final label = switch (ticks) { ChatTicks.sent => 'Sent', ChatTicks.delivered => 'Delivered', _ => 'Read' };
    return Semantics(
      label: label,
      child: Icon(
        ticks == ChatTicks.sent ? Icons.done_rounded : Icons.done_all_rounded,
        size: DS.s(15),
        color: ticks == ChatTicks.read ? color : color.withValues(alpha: 0.65),
      ),
    );
  }
}

class ChatBubble3D extends StatelessWidget {
  const ChatBubble3D({
    super.key,
    required this.tone,
    required this.text,
    required this.mine,
    this.ticks = ChatTicks.none,
    this.dimmed = false,
    this.time,
    this.sender,
    this.senderColor,
    this.maxWidth,
    this.maskToken,
  });

  final ListingTone tone;
  final String text;
  final bool mine;
  final ChatTicks ticks;
  final bool dimmed;
  final String? time;
  final String? sender;
  final Color? senderColor;
  final double? maxWidth;
  final String? maskToken;

  Widget _body(TextStyle style) {
    final token = maskToken;
    if (token == null || token.isEmpty || !text.contains(token)) return Text(text, style: style);
    final parts = text.split(token);
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) spans.add(TextSpan(text: parts[i]));
      if (i < parts.length - 1) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: DS.s(6)),
            decoration: BoxDecoration(color: (mine ? Colors.white : Ink3D.sub).withValues(alpha: Alpha.v25), borderRadius: DS.circular(6)),
            child: Text(token, style: style),
          ),
        ));
      }
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }

  Widget _content() {
    final named = sender != null;
    final meta = time != null
        ? Padding(
            padding: EdgeInsets.only(top: DS.s(2)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time!, style: Ink3D.text(12, FontWeight.w400, mine ? Colors.white.withValues(alpha: Alpha.high) : Ink3D.grey)),
                if (mine && ticks != ChatTicks.none) ...[SizedBox(width: DS.s(4)), _Ticks(ticks, Colors.white)],
              ],
            ),
          )
        : (mine && ticks != ChatTicks.none ? Padding(padding: EdgeInsets.only(top: DS.s(2)), child: _Ticks(ticks, Colors.white)) : null);
    return Column(
      crossAxisAlignment: named ? CrossAxisAlignment.stretch : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (named) ...[
          Text(sender!, style: Ink3D.text(12.5, FontWeight.w600, senderColor ?? Ink3D.sub)),
          SizedBox(height: DS.s(2)),
        ],
        Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: _body(Ink3D.text(14, FontWeight.w400, mine ? Colors.white : Ink3D.body, height: 1.4)),
        ),
        if (meta != null) named ? Align(alignment: Alignment.centerRight, child: meta) : meta,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth ?? DS.s(262)),
      padding: EdgeInsets.symmetric(horizontal: DS.s(14), vertical: DS.s(10)),
      decoration: BoxDecoration(
        color: mine ? null : Colors.white,
        gradient: mine ? tone.gradient : null,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(DS.radius(16)),
          topRight: Radius.circular(DS.radius(16)),
          bottomLeft: Radius.circular(DS.radius(mine ? 16 : 8)),
          bottomRight: Radius.circular(DS.radius(mine ? 8 : 16)),
        ),
        boxShadow: mine
            ? [BoxShadow(color: tone.shadow.withValues(alpha: 0.45), offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(10))]
            : [BoxShadow(color: Color(0x4D9E9E9E), offset: DS.shadowOffset(const Offset(1.1, 3)), blurRadius: DS.shadowBlur(8))],
      ),
      child: sender == null ? _content() : IntrinsicWidth(child: _content()),
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
      width: DS.s(244),
      constraints: BoxConstraints(minHeight: DS.s(42) * _scale(context).clamp(1.0, 1.4)),
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(6), DS.s(14), DS.s(6)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DS.circular(22),
        border: Border.all(color: c, width: 1.5),
        boxShadow: [BoxShadow(color: Color(0x4D9E9E9E), offset: DS.shadowOffset(const Offset(1.1, 3)), blurRadius: DS.shadowBlur(8))],
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, c))),
          Icon(Icons.chevron_right_rounded, size: DS.s(20), color: c),
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
  const ChatSystemNote(this.text, {super.key, this.colors});

  final String text;
  final (Color, Color)? colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: DS.gv(10)),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: DS.s(12), vertical: DS.s(5)),
          decoration: BoxDecoration(color: colors?.$1 ?? const Color(0x17253840), borderRadius: DS.circular(14)),
          child: Text(text, textAlign: TextAlign.center, style: Ink3D.text(12, FontWeight.w500, colors?.$2 ?? Ink3D.sub)),
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
  static BorderRadius get radius => DS.br(CardRadius.tile);

  Widget _chip(BuildContext context, ChatChip c) {
    final ring = c.selected || c.selectable;
    final ink = c.selected ? Colors.white : (c.selectable ? tone.text : Ink3D.sub);
    final chip = Container(
      constraints: BoxConstraints(minHeight: DS.s(32) * _scale(context).clamp(1.0, 1.4)),
      padding: EdgeInsets.symmetric(horizontal: DS.s(11)),
      decoration: BoxDecoration(
        color: c.selected ? null : (c.selectable ? Colors.white : const Color(0xFFF2F3F8)),
        gradient: c.selected ? tone.gradient : null,
        borderRadius: DS.circular(18),
        border: Border.all(color: c.selectable && !c.selected ? tone.haloBase.withValues(alpha: 0.5) : Colors.transparent, width: 1.5),
        boxShadow: c.selected ? [BoxShadow(color: tone.shadow.withValues(alpha: 0.45), offset: DS.shadowOffset(const Offset(1.1, 3)), blurRadius: DS.shadowBlur(6))] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ring) ...[
            Container(
              width: DS.s(16),
              height: DS.s(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.selected ? Colors.white : null,
                border: c.selected ? null : Border.all(color: tone.g2, width: DS.s(2)),
              ),
              child: c.selected ? Icon(Icons.check_rounded, size: DS.s(12), color: tone.g2) : null,
            ),
            Gap.h(6),
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
      constraints: BoxConstraints(minHeight: DS.s(44) * _scale(context).clamp(1.0, 1.3)),
      padding: EdgeInsets.symmetric(horizontal: DS.s(14), vertical: DS.s(4)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary ? null : Colors.white,
        gradient: primary ? tone.gradient : null,
        borderRadius: DS.circular(24),
        border: primary ? null : Border.all(color: b.kind == ChatButtonKind.danger ? const Color(0x59E0525C) : const Color(0xFFE6E8EE), width: 1.5),
        boxShadow: off
            ? null
            : primary
            ? [BoxShadow(color: tone.shadow.withValues(alpha: 0.5), offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(8))]
            : [BoxShadow(color: Color(0x599E9E9E), offset: DS.shadowOffset(const Offset(3, 5)), blurRadius: DS.shadowBlur(10))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (b.busy) ...[
            SizedBox(width: DS.s(16), height: DS.s(16), child: CircularProgressIndicator(strokeWidth: DS.s(2.4), color: ink)),
            Gap.h(8),
          ] else if (b.icon != null) ...[
            Icon(b.icon, size: DS.s(18), color: ink),
            Gap.h(8),
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
      padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(12), DS.s(16), DS.s(14)),
      decoration: BoxDecoration(
        color: dimmed ? const Color(0xFFE9EDEA) : Colors.white,
        borderRadius: radius,
        boxShadow: dimmed ? null : [BoxShadow(color: Color(0x529E9E9E), offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: DS.s(30)),
            child: Padding(
              padding: EdgeInsets.only(left: DS.s(62)),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14.5, FontWeight.w700, dimmed ? const Color(0xFF8A948D) : Ink3D.title, height: 1.25, letterSpacing: 0)),
              ),
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: EdgeInsets.only(top: DS.s(10)),
              child: Text(subtitle!, style: Ink3D.text(13, FontWeight.w400, Ink3D.sub, height: 1.4)),
            ),
          if (body != null) Padding(padding: EdgeInsets.only(top: DS.s(10)), child: body),
          if (chips.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: DS.s(10)),
              child: Wrap(spacing: DS.gh(6), runSpacing: DS.gv(6), children: [for (final c in chips) _chip(context, c)]),
            ),
          if (buttons.isNotEmpty) SizedBox(height: DS.s(5)),
          for (final b in buttons) Padding(padding: EdgeInsets.only(top: DS.s(9)), child: _button(context, b)),
          if (mine)
            Padding(
              padding: EdgeInsets.only(top: DS.s(8)),
              child: Align(alignment: Alignment.centerRight, child: _Ticks(ticks, tone.g2)),
            ),
        ],
      ),
    );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: DS.s(width)),
        child: Padding(
          padding: EdgeInsets.only(top: DS.s(topRoom)),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              card,
              Positioned(
                left: DS.s(8),
                top: DS.s(-30),
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

  static BorderRadius get _radius => BorderRadius.only(topLeft: Radius.circular(DS.radius(16)), topRight: Radius.circular(DS.radius(16)), bottomLeft: Radius.circular(DS.radius(16)), bottomRight: Radius.circular(DS.radius(8)));

  @override
  Widget build(BuildContext context) {
    final on = enabled && onTap != null;
    final slot = CustomPaint(
      foregroundPainter: _DashedBorder(color: tone.haloBase.withValues(alpha: 0.75), radius: _radius),
      child: Container(
        padding: EdgeInsets.fromLTRB(DS.s(6), DS.s(6), DS.s(16), DS.s(6)),
        decoration: BoxDecoration(color: tone.haloBase.withValues(alpha: 0.08), borderRadius: _radius),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: DS.s(30),
              height: DS.s(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: tone.gradient,
                boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.5), offset: DS.shadowOffset(const Offset(1.1, 3)), blurRadius: DS.shadowBlur(6))],
              ),
              child: Icon(Icons.add_rounded, size: DS.s(20), color: Colors.white),
            ),
            Gap.h(10),
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
        canvas.drawPath(m.extractPath(d, d + DS.s(4)), paint);
        d += DS.s(7);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius;
}
