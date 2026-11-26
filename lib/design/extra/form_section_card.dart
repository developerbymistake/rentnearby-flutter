import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'pill_buttons_3d.dart';
import 'package:bakhli/design/tokens/design_scale.dart';
import '../tokens/card_tokens.dart';

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
    this.corner = CardRadius.heroNotch,
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

  static double get topRoom => DS.s(46);

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
      padding: EdgeInsets.only(top: DS.s(2)),
      child: Text(h, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w600, Form3D.amber, letterSpacing: 0)),
    );
  }

  Widget? _tag() {
    final t = tag;
    if (t == null || t.isEmpty) return null;
    return Container(
      margin: EdgeInsets.only(top: DS.s(3)),
      padding: EdgeInsets.symmetric(horizontal: DS.s(10), vertical: DS.s(3)),
      decoration: BoxDecoration(borderRadius: DS.circular(10), color: tagMuted ? Form3D.limit : Form3D.wash(tone, 0.13)),
      child: Text(t.toUpperCase(), maxLines: 1, style: Ink3D.text(10.5, FontWeight.w700, tagMuted ? Form3D.muted : tone.text, letterSpacing: 0.5)),
    );
  }

  Widget _leftHead() {
    final tag = _tag();
    final hint = _hint();
    return Padding(
      padding: EdgeInsets.only(top: DS.s(12), bottom: DS.s(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: DS.s(62),
            height: DS.s(26),
            child: OverflowBox(
              alignment: Alignment.bottomCenter,
              minHeight: DS.s(62),
              maxHeight: DS.s(62),
              child: ExcludeSemantics(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(width: DS.s(62), height: DS.s(62), decoration: BoxDecoration(borderRadius: DS.circular(18), color: Form3D.wash(tone, 0.14))),
                    Positioned(left: DS.s(-5), top: DS.s(-16), child: Art3D(asset: art, size: 72, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28)),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: DS.s(12)),
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: DS.s(46)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tag == null && hint == null) Padding(padding: EdgeInsets.only(bottom: DS.s(18)), child: _title(16.5)) else _title(16.5),
                  ?tag,
                  ?hint,
                ],
              ),
            ),
          ),
          if (trailing != null) Padding(padding: EdgeInsets.only(left: DS.s(8)), child: trailing),
        ],
      ),
    );
  }

  Widget _rightHead() {
    final tag = _tag();
    final hint = _hint();
    return Padding(
      padding: EdgeInsets.only(top: DS.s(18), bottom: DS.s(14), right: DS.s(86)),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: DS.s(26)),
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
      padding: EdgeInsets.fromLTRB(DS.s(18), 0, DS.s(18), DS.s(18)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DS.br(BorderRadius.only(topLeft: const Radius.circular(CardRadius.corner), topRight: Radius.circular(corner), bottomLeft: const Radius.circular(CardRadius.corner), bottomRight: const Radius.circular(CardRadius.corner))),
        boxShadow: DS.shadows(Form3D.cardShadow),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [right ? _rightHead() : _leftHead(), child],
      ),
    );
    return Padding(
      padding: margin ?? EdgeInsets.fromLTRB(DS.s(18), topRoom, DS.s(18), 0),
      child: right
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                card,
                Positioned(
                  right: DS.s(12),
                  top: DS.s(-40),
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

  static double get topRoom => DS.s(34);

  @override
  Widget build(BuildContext context) {
    final t = title;
    final b = body;
    final card = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: DS.s(70)),
          padding: EdgeInsets.fromLTRB(DS.s(84), DS.s(14), DS.s(onTap == null ? 16 : 10), DS.s(14)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: DS.br(CardRadius.card),
            boxShadow: DS.shadows(Form3D.cardShadow),
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
              if (onTap != null) Icon(Icons.chevron_right_rounded, size: DS.s(26), color: tone.text),
            ],
          ),
        ),
        Positioned(left: DS.s(10), top: DS.s(-20), child: ExcludeSemantics(child: Art3D(asset: art, size: 64, halo: 60, haloColor: tone.halo, haloDy: 4, shadowBlur: 4, shadowOffset: const Offset(3, 5)))),
      ],
    );
    return Padding(
      padding: margin ?? EdgeInsets.fromLTRB(DS.s(18), topRoom, DS.s(18), 0),
      child: onTap == null ? card : Tap3D(onTap: onTap, child: card),
    );
  }
}
