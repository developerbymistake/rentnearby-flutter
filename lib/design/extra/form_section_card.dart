import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'pill_buttons_3d.dart';

enum FormArtSide { left, right }

class FormSectionCard extends StatelessWidget {
  const FormSectionCard({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    required this.child,
    this.tag,
    this.tagMuted = false,
    this.requiredMark = false,
    this.hint,
    this.artSide = FormArtSide.left,
    this.corner = 68,
    this.trailing,
    this.margin,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final Widget child;
  final String? tag;
  final bool tagMuted;
  final bool requiredMark;
  final String? hint;
  final FormArtSide artSide;
  final double corner;
  final Widget? trailing;
  final EdgeInsets? margin;

  static const double topRoom = 46;

  Widget _title(double size, {bool oneLine = true}) {
    final text = Text.rich(
      TextSpan(
        text: title,
        children: [if (requiredMark) const TextSpan(text: ' *', style: TextStyle(color: Form3D.error))],
      ),
      maxLines: oneLine ? 1 : 2,
      softWrap: !oneLine,
      overflow: oneLine ? TextOverflow.visible : TextOverflow.ellipsis,
      style: Ink3D.text(size, FontWeight.w700, Ink3D.title, height: 1.3),
    );
    final head = Semantics(header: true, child: text);
    return oneLine ? FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: head) : head;
  }

  Widget? _hint() {
    final h = hint;
    if (h == null || h.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(h, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w600, Form3D.amber, letterSpacing: 0)),
    );
  }

  Widget? _tag() {
    final t = tag;
    if (t == null || t.isEmpty) return null;
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: tagMuted ? Form3D.limit : Form3D.wash(tone, 0.13)),
      child: Text(t.toUpperCase(), maxLines: 1, style: Ink3D.text(10.5, FontWeight.w700, tagMuted ? Form3D.muted : tone.text, letterSpacing: 0.5)),
    );
  }

  Widget _leftHead() {
    final tag = _tag();
    final hint = _hint();
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 62,
            height: 26,
            child: OverflowBox(
              alignment: Alignment.bottomCenter,
              minHeight: 62,
              maxHeight: 62,
              child: ExcludeSemantics(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(width: 62, height: 62, decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: Form3D.wash(tone, 0.14))),
                    Positioned(left: -5, top: -16, child: Art3D(asset: art, size: 72, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 46),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tag == null && hint == null) Padding(padding: const EdgeInsets.only(bottom: 18), child: _title(16.5)) else _title(16.5),
                  ?tag,
                  ?hint,
                ],
              ),
            ),
          ),
          if (trailing != null) Padding(padding: const EdgeInsets.only(left: 8), child: trailing),
        ],
      ),
    );
  }

  Widget _rightHead() {
    final tag = _tag();
    final hint = _hint();
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 14, right: 86),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_title(17, oneLine: false), ?tag, ?hint],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final right = artSide == FormArtSide.right;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: const Radius.circular(8), topRight: Radius.circular(corner), bottomLeft: const Radius.circular(8), bottomRight: const Radius.circular(8)),
        boxShadow: Form3D.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [right ? _rightHead() : _leftHead(), child],
      ),
    );
    return Padding(
      padding: margin ?? const EdgeInsets.fromLTRB(18, topRoom, 18, 0),
      child: right
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                card,
                Positioned(
                  right: 12,
                  top: -40,
                  child: IgnorePointer(child: ExcludeSemantics(child: Art3D(asset: art, size: 86, halo: 88, haloColor: tone.halo, haloDy: 3, shadowBlur: 5, shadowOffset: const Offset(4, 7)))),
                ),
              ],
            )
          : card,
    );
  }
}

class FormNoteCard extends StatelessWidget {
  const FormNoteCard({super.key, required this.tone, required this.art, this.title, this.body, this.titleColor, this.onTap, this.margin});

  final ListingTone tone;
  final String art;
  final String? title;
  final String? body;
  final Color? titleColor;
  final VoidCallback? onTap;
  final EdgeInsets? margin;

  static const double topRoom = 34;

  @override
  Widget build(BuildContext context) {
    final t = title;
    final b = body;
    final card = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 70),
          padding: EdgeInsets.fromLTRB(84, 14, onTap == null ? 16 : 10, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(24), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
            boxShadow: Form3D.cardShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (t != null && t.isNotEmpty) Text(t, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, titleColor ?? Ink3D.title, height: 1.3, letterSpacing: 0)),
                    if (b != null && b.isNotEmpty) Text(b, maxLines: 6, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Form3D.label, height: 1.45, letterSpacing: 0)),
                  ],
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right_rounded, size: 26, color: tone.text),
            ],
          ),
        ),
        Positioned(left: 10, top: -20, child: ExcludeSemantics(child: Art3D(asset: art, size: 64, halo: 60, haloColor: tone.halo, haloDy: 4, shadowBlur: 4, shadowOffset: const Offset(3, 5)))),
      ],
    );
    return Padding(
      padding: margin ?? const EdgeInsets.fromLTRB(18, topRoom, 18, 0),
      child: onTap == null ? card : Tap3D(onTap: onTap, child: card),
    );
  }
}
