import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'pill_buttons_3d.dart';

class PageHeader3D extends StatelessWidget {
  const PageHeader3D({
    super.key,
    required this.tone,
    required this.title,
    this.subtitle,
    this.art,
    this.onBack,
    this.leadingIcon,
    this.onLeading,
    this.leadingSemantics,
    this.trailing,
    this.inlineTitle = false,
    this.artSize = 122,
    this.bottom,
    this.surface = false,
  });

  final ListingTone tone;
  final String title;
  final String? subtitle;
  final String? art;
  final VoidCallback? onBack;
  final IconData? leadingIcon;
  final VoidCallback? onLeading;
  final String? leadingSemantics;
  final Widget? trailing;
  final bool inlineTitle;
  final double artSize;
  final Widget? bottom;
  final bool surface;

  static const double buttonSize = 44;

  Widget? _leading(BuildContext context) {
    final icon = leadingIcon;
    if (icon == null && onBack == null) return null;
    final tip = icon == null ? MaterialLocalizations.of(context).backButtonTooltip : (leadingSemantics ?? MaterialLocalizations.of(context).showMenuTooltip);
    return Tooltip(
      message: tip,
      excludeFromSemantics: true,
      child: Tap3D(
        onTap: icon == null ? onBack : onLeading,
        label: tip,
        exclude: true,
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: surface ? null : Ink3D.softShadow, border: surface ? Border.all(color: Ink3D.line) : null),
          child: Icon(icon ?? Icons.chevron_left_rounded, size: icon == null ? 28 : 24, color: tone.text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final hasArt = art != null && art!.isNotEmpty;
    final size = narrow ? artSize * 96 / 122 : artSize;
    final shift = trailing == null ? 0.0 : buttonSize + 12;
    final clear = (hasArt ? size + (inlineTitle ? 0 : (narrow ? 8 : 10)) : 0.0) + shift;
    final sub = subtitle;
    final lead = _leading(context);

    final titleText = Semantics(
      header: true,
      child: FitOrWrap3D(text: title, style: Ink3D.text(narrow ? 23 : (inlineTitle && MediaQuery.sizeOf(context).width < 380 ? 24 : 26), FontWeight.w700, Ink3D.title, height: 1.15)),
    );
    final subText = (sub == null || sub.isEmpty)
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FitOrWrap3D(text: sub, stretch: 1.5, style: Ink3D.text(14, FontWeight.w400, Ink3D.sub, letterSpacing: 0, height: 1.35)),
          );

    final Widget text;
    if (inlineTitle) {
      text = ConstrainedBox(
        constraints: BoxConstraints(minHeight: hasArt ? size - 4 : buttonSize),
        child: Padding(
          padding: EdgeInsets.only(right: clear),
          child: Row(
            children: [
              if (lead != null) ...[lead, const SizedBox(width: 12)],
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [titleText, ?subText]),
              ),
            ],
          ),
        ),
      );
    } else {
      text = ConstrainedBox(
        constraints: BoxConstraints(minHeight: hasArt ? size - 2 : 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: buttonSize, child: Align(alignment: Alignment.centerLeft, child: lead)),
            const SizedBox(height: 10),
            Padding(padding: EdgeInsets.only(right: clear), child: titleText),
            if (subText != null) Padding(padding: EdgeInsets.only(right: clear), child: subText),
          ],
        ),
      );
    }

    final head = Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (hasArt)
            Positioned(
              right: -4 + shift,
              top: -8,
              child: ExcludeSemantics(child: Art3D(asset: art!, size: size, halo: size - 2, haloColor: tone.halo, haloDy: 4)),
            ),
          text,
          if (trailing != null) Positioned(right: 0, top: 0, child: trailing!),
        ],
      ),
    );

    final body = bottom == null ? head : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, bottom!]);
    if (!surface) return body;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: Ink3D.softShadow,
      ),
      child: Padding(padding: const EdgeInsets.only(bottom: 14), child: body),
    );
  }
}
