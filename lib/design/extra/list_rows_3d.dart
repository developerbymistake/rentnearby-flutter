import 'package:bakhli/design/tokens/design_scale.dart';
import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'pill_buttons_3d.dart';
import 'motion_kit.dart';
import '../tokens/card_tokens.dart';

double _scale(BuildContext context) => MediaQuery.textScalerOf(context).scale(1);

Widget _tile(String art, {required double tile, required double artSize, required Color color, double radius = 16, bool round = false}) => SizedBox(
  width: DS.s(tile),
  height: DS.s(tile),
  child: Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: round ? BoxShape.circle : BoxShape.rectangle, borderRadius: round ? null : DS.circular(radius)),
        ),
      ),
      Positioned(
        left: DS.s((tile - artSize) / 2),
        top: DS.s((tile - artSize) / 2 - 6),
        child: Art3D(asset: art, size: artSize, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28),
      ),
    ],
  ),
);

Widget _tap({required Widget child, VoidCallback? onTap, String? label}) {
  if (onTap == null) return child;
  return Semantics(
    button: true,
    label: label,
    child: PressScale(
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
    ),
  );
}

class InfoField {
  const InfoField({required this.label, this.value, this.child});

  final String label;
  final String? value;
  final Widget? child;
}

class InfoFieldCard extends StatelessWidget {
  const InfoFieldCard({super.key, required this.fields, this.margin});

  final List<InfoField> fields;
  final EdgeInsets? margin;

  static const BorderRadius radius = CardRadius.hero;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? EdgeInsets.fromLTRB(DS.s(18), DS.gv(22), DS.s(18), 0),
      padding: DS.sym(h: 22, v: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DS.br(radius),
        boxShadow: DS.shadows(const [BoxShadow(color: Color(0x339E9E9E), offset: Offset(1.1, 1.1), blurRadius: 10)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < fields.length; i++)
            Container(
              padding: DS.sym(v: 14),
              decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: Ink3D.line))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(fields[i].label.toUpperCase(), style: Ink3D.text(11, FontWeight.w700, Ink3D.hint, letterSpacing: 0.5)),
                  SizedBox(height: DS.s(4)),
                  fields[i].child ?? Text(fields[i].value ?? '', style: Ink3D.text(15, FontWeight.w400, Ink3D.sub, height: 1.5)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class SummaryRow3D extends StatelessWidget {
  const SummaryRow3D({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    this.detail,
    this.detailBad = false,
    this.actionLabel,
    this.onAction,
    this.divider = true,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String? detail;
  final bool detailBad;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final action = actionLabel;
    return Container(
      padding: EdgeInsets.only(top: DS.s(divider ? 24 : 10), bottom: DS.s(18)),
      decoration: BoxDecoration(border: divider ? const Border(top: BorderSide(color: Ink3D.line)) : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tile(art, tile: 66, artSize: 78, color: tone.haloBase.withValues(alpha: 0.13), radius: 18),
          SizedBox(width: DS.s(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: DS.s(30)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w700, Ink3D.title)),
                      ),
                      if (action != null) ...[
                        SizedBox(width: DS.s(8)),
                        _tap(
                          onTap: onAction,
                          label: '$action $title',
                          child: Container(
                            constraints: BoxConstraints(minWidth: DS.s(58), minHeight: DS.s(28)),
                            padding: DS.sym(h: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: tone.haloBase.withValues(alpha: 0.13), borderRadius: DS.circular(15)),
                            child: Text(action, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w700, tone.text)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (detail != null)
                  Padding(
                    padding: EdgeInsets.only(top: DS.s(4)),
                    child: FitOrWrap3D(
                      text: detail!,
                      maxLines: 3,
                      style: Ink3D.text(12, detailBad ? FontWeight.w600 : FontWeight.w400, detailBad ? const Color(0xFFC0404A) : Ink3D.grey, height: 1.35),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum BannerKind { good, warn, bad, info }

class Banner3D extends StatelessWidget {
  const Banner3D({super.key, required this.kind, required this.title, this.art, this.subtitle, this.actionLabel, this.onAction, this.onTap, this.margin, this.tone, this.compact = false});

  final bool compact;
  final BannerKind kind;
  final String title;
  final String? art;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final EdgeInsets? margin;
  final ListingTone? tone;

  static const BorderRadius radius = CardRadius.card;

  @override
  Widget build(BuildContext context) {
    final t = tone ?? ListingTone.indigo;
    final (Color fill, Color ink, Color tileBase, Color g1, Color g2, Color link) = switch (kind) {
      BannerKind.good => (const Color(0xFFE3F2E4), const Color(0xFF17501B), const Color(0xFF2E7D32), const Color(0xFF66BB6A), const Color(0xFF2E7D32), const Color(0xFF17501B)),
      BannerKind.warn => (const Color(0xFFFFF1DE), const Color(0xFF9A5B00), const Color(0xFFF57C00), const Color(0xFFFFC371), const Color(0xFFFF8A3D), const Color(0xFFC26A00)),
      BannerKind.bad => (const Color(0xFFFDECEC), const Color(0xFFB83A40), const Color(0xFFE0525C), const Color(0xFFFA7D82), const Color(0xFFE0525C), const Color(0xFFB83A40)),
      BannerKind.info => (Colors.white, Ink3D.title, t.haloBase, t.g1, t.g2, t.text),
    };
    final action = actionLabel;
    final pill = action != null && onAction != null;
    final body = Container(
      margin: margin ?? EdgeInsets.fromLTRB(DS.s(18), DS.gv(14), DS.s(18), 0),
      constraints: BoxConstraints(minHeight: DS.s(compact ? 58 : 68)),
      padding: compact ? DS.sym(h: 16, v: 12) : DS.insets(l: 14, t: 12, r: 16, b: 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: DS.br(radius),
        boxShadow: DS.shadows(const [BoxShadow(color: Color(0x389E9E9E), offset: Offset(1.1, 1.1), blurRadius: 10)]),
      ),
      child: Row(
        children: [
          if (art != null && compact) ...[Art3D(asset: art!, size: 34, shadowBlur: 3, shadowOffset: const Offset(2, 3), shadowAlpha: 0.25), SizedBox(width: DS.s(10))]
          else if (art != null) ...[_tile(art!, tile: 46, artSize: 52, color: tileBase.withValues(alpha: 0.16), radius: 14), SizedBox(width: DS.s(12))],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: compact ? Ink3D.text(13.5, FontWeight.w600, ink) : Ink3D.text(14, FontWeight.w700, ink)),
                if (subtitle != null)
                  Padding(
                    padding: EdgeInsets.only(top: DS.s(1)),
                    child: Text(subtitle!, maxLines: 4, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, const Color(0xFF5F6B76), height: 1.35)),
                  ),
                if (action != null && !pill)
                  Padding(
                    padding: EdgeInsets.only(top: DS.s(4)),
                    child: Text(action, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w700, link)),
                  ),
              ],
            ),
          ),
          if (pill) ...[
            SizedBox(width: DS.s(10)),
            _tap(
              onTap: onAction,
              label: action,
              child: Container(
                constraints: BoxConstraints(minHeight: DS.s(32) * _scale(context).clamp(1.0, 1.3)),
                padding: DS.sym(h: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: DS.circular(18),
                  gradient: LinearGradient(colors: [g1, g2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Text(action, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w700, Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
    return _tap(onTap: onTap, label: title, child: body);
  }
}

class DayLabel3D extends StatelessWidget {
  const DayLabel3D(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(10), DS.s(18), 0),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: DS.s(18)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(text.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w700, Ink3D.grey, letterSpacing: 0.8)),
          ),
        ),
      ),
    );
  }
}

class OnCardRow extends StatelessWidget {
  const OnCardRow({super.key, required this.title, this.subtitle, this.art, this.trailing, this.onTap, this.enabled = true, this.light = false, this.fitSubtitle = false});

  final bool fitSubtitle;
  final String title;
  final String? subtitle;
  final String? art;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final ink = light ? const Color(0xFFD93A55) : Colors.white;
    final row = Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        constraints: BoxConstraints(minHeight: DS.s(subtitle == null ? 44 : 58)),
        padding: DS.sym(h: 12, v: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: light ? 0.92 : 0.18), borderRadius: DS.circular(12)),
        child: Row(
          children: [
            if (art != null) ...[Art3D(asset: art!, size: 34, shadowBlur: 3, shadowOffset: const Offset(2, 3), shadowAlpha: 0.25), SizedBox(width: DS.s(10))],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w600, ink)),
                  if (subtitle != null)
                    if (fitSubtitle)
                      FitOrWrap3D(text: subtitle!, style: Ink3D.text(11.5, FontWeight.w400, ink.withValues(alpha: 0.92)))
                    else
                      Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w400, ink.withValues(alpha: 0.92))),
                ],
              ),
            ),
            if (trailing != null) ...[SizedBox(width: DS.s(8)), trailing!],
          ],
        ),
      ),
    );
    return _tap(onTap: enabled ? onTap : null, label: title, child: row);
  }
}

class OnCardPill extends StatelessWidget {
  const OnCardPill({super.key, required this.label, this.onTap, this.color, this.enabled = true, this.width});

  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool enabled;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      width: width,
      constraints: BoxConstraints(minWidth: width ?? DS.s(84), minHeight: DS.s(28)),
      padding: DS.sym(h: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.3),
        borderRadius: DS.circular(16),
        boxShadow: enabled ? DS.shadows(const [BoxShadow(color: Color(0x33000000), offset: Offset(2, 4), blurRadius: 6)]) : null,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, maxLines: 1, softWrap: false, style: Ink3D.text(12.5, FontWeight.w700, enabled ? (color ?? ListingTone.indigo.button) : Colors.white)),
      ),
    );
    return _tap(onTap: enabled ? onTap : null, label: label, child: pill);
  }
}

class PayLine3D extends StatelessWidget {
  const PayLine3D(this.text, {super.key, this.art});

  final String text;
  final String? art;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(22), DS.gv(18), DS.s(22), 0),
      child: Row(
        children: [
          if (art != null) ...[Image.asset(art!, width: DS.s(30), height: DS.s(30), fit: BoxFit.contain), SizedBox(width: DS.s(10))],
          Expanded(
            child: Text(text, textAlign: art == null ? TextAlign.center : TextAlign.start, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.sub, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
