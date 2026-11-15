import 'package:flutter/material.dart';

import '../tokens/design_scale.dart';
import '../tokens/listing_palette.dart';
import 'art_3d.dart';
import 'motion_kit.dart';

const BorderRadius _kChipRadius = BorderRadius.only(
  topLeft: Radius.circular(8),
  topRight: Radius.circular(24),
  bottomLeft: Radius.circular(8),
  bottomRight: Radius.circular(8),
);
const BorderRadius _kWhiteCardRadius = BorderRadius.only(
  topLeft: Radius.circular(8),
  topRight: Radius.circular(68),
  bottomLeft: Radius.circular(8),
  bottomRight: Radius.circular(8),
);
const Color _kInlineHint = Color(0xFF9FA3AB);
const Color _kChevron = Color(0xFFB0B4BD);
const Color _kBadge = Color(0xFFFF5287);
const Color _kBannerFill = Color(0xFFFFF1DE);
const Color _kBannerText = Color(0xFF6A4A1A);
const List<BoxShadow> _kFieldShadow = [
  BoxShadow(color: Color(0x599E9E9E), offset: Offset(3, 5), blurRadius: 12),
];

List<BoxShadow> _toneShadow(
  ListingTone tone,
  Offset offset,
  double blur, [
  double alpha = 0.5,
]) => [
  BoxShadow(
    color: tone.haloBase.withValues(alpha: alpha),
    offset: DS.shadowOffset(offset),
    blurRadius: DS.shadowBlur(blur),
  ),
];

Widget _tap({
  required Widget child,
  VoidCallback? onTap,
  Key? key,
  String? label,
  bool? selected,
}) {
  final body = Semantics(
    button: true,
    enabled: onTap != null,
    selected: selected,
    label: label,
    child: GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    ),
  );
  return onTap == null ? body : PressScale(child: body);
}

class ChipCP extends StatelessWidget {
  const ChipCP({
    super.key,
    required this.tone,
    required this.art,
    required this.label,
    this.off = false,
    this.onTap,
  });

  final ListingTone tone;
  final String art;
  final String label;
  final bool off;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _tap(
      onTap: onTap,
      selected: !off,
      child: Opacity(
        opacity: off ? 0.62 : 1,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsets.only(top: DS.s(20)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: DS.br(_kChipRadius),
                  gradient: tone.gradient,
                  boxShadow: off ? const [] : tone.glow(blur: 8),
                ),
                child: Padding(
                  padding: DS.insets(l: 70, t: 12, r: 18, b: 12),
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(
                      14,
                      FontWeight.w700,
                      Colors.white,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: DS.s(6),
              top: 0,
              child: Art3D(
                asset: art,
                size: 58,
                shadowBlur: 4,
                shadowOffset: const Offset(3, 5),
                shadowAlpha: 0.28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChipCPRow extends StatelessWidget {
  const ChipCPRow({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 4),
    this.controller,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: EdgeInsets.fromLTRB(
        DS.s(padding.left),
        DS.gv((padding.top - 20).clamp(0, double.infinity)),
        DS.s(padding.right),
        DS.gv(padding.bottom + 8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Gap.h(12),
            children[i],
          ],
        ],
      ),
    );
  }
}

class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    required this.tone,
    required this.value,
    required this.buttonArt,
    this.label,
    this.leadingArt,
    this.hint = false,
    this.inline = false,
    this.onTap,
    this.onButtonTap,
    this.buttonKey,
    this.field,
    this.buttonChild,
    this.buttonSemantics,
    this.margin,
    this.padding,
    this.flat = false,
  });

  final ListingTone tone;
  final String value;
  final String buttonArt;
  final String? label;
  final String? leadingArt;
  final bool hint;
  final bool inline;
  final VoidCallback? onTap;
  final VoidCallback? onButtonTap;
  final Key? buttonKey;
  final Widget? field;
  final Widget? buttonChild;
  final String? buttonSemantics;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final size = DS.s(inline ? 44.0 : 56.0);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: EdgeInsets.only(bottom: DS.s(1)),
            child: Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Ink3D.text(
                11,
                FontWeight.w400,
                Ink3D.hint,
                letterSpacing: 0,
              ),
            ),
          ),
        hint
            ? (value.length <= 26
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: Ink3D.text(
                          inline ? 16 : 15,
                          FontWeight.w400,
                          inline ? _kInlineHint : Ink3D.hint,
                          letterSpacing: 0,
                        ),
                      ),
                    )
                  : Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Ink3D.text(
                        inline ? 16 : 15,
                        FontWeight.w400,
                        inline ? _kInlineHint : Ink3D.hint,
                        letterSpacing: 0,
                      ),
                    ))
            : Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ink3D.text(
                  inline ? 16 : 15,
                  FontWeight.w400,
                  Ink3D.body,
                  letterSpacing: 0,
                ),
              ),
      ],
    );
    final button = _tap(
      key: buttonKey,
      onTap: onButtonTap ?? onTap,
      label: buttonSemantics,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: tone.gradient,
          boxShadow: flat
              ? const []
              : _toneShadow(
                  tone,
                  inline ? const Offset(3, 6) : const Offset(4, 8),
                  inline ? 10 : 12,
                ),
        ),
        alignment: Alignment.center,
        child:
            buttonChild ??
            Art3D(
              asset: buttonArt,
              size: inline ? 30 : 42,
              shadowBlur: 2,
              shadowOffset: const Offset(2, 3),
              shadowAlpha: 0.3,
            ),
      ),
    );
    final pill = BoxDecoration(
      color: Colors.white,
      borderRadius: DS.circular(38),
      boxShadow: flat
          ? DS.shadows(const [
              BoxShadow(
                color: Color(0x1F000000),
                offset: Offset(0, 3),
                blurRadius: 10,
              ),
            ])
          : DS.shadows(_kFieldShadow),
    );
    if (inline) {
      final body = Container(
        margin: margin ?? EdgeInsets.fromLTRB(DS.s(18), DS.gv(16), DS.s(18), 0),
        padding: padding ?? DS.insets(l: 20, t: 10, r: 12, b: 10),
        decoration: pill,
        child: Row(
          children: [
            Expanded(child: field ?? text),
            SizedBox(width: DS.s(10)),
            button,
          ],
        ),
      );
      if (field != null || onTap == null) return body;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: body,
      );
    }
    return Padding(
      padding:
          margin ?? EdgeInsets.symmetric(horizontal: DS.s(16), vertical: DS.gv(10)),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: onTap != null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Container(
                  constraints: BoxConstraints(minHeight: DS.s(64)),
                  padding: DS.insets(
                    l: leadingArt == null ? 22 : 12,
                    t: 10,
                    r: 18,
                    b: 10,
                  ),
                  decoration: pill,
                  child: Row(
                    children: [
                      if (leadingArt != null) ...[
                        Art3D(
                          asset: leadingArt!,
                          size: 44,
                          shadowBlur: 3,
                          shadowOffset: const Offset(2, 4),
                          shadowAlpha: 0.25,
                        ),
                        SizedBox(width: DS.s(12)),
                      ],
                      Expanded(child: text),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Gap.h(10),
          button,
        ],
      ),
    );
  }
}

class ModuleTitleBar extends StatelessWidget {
  const ModuleTitleBar({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    this.subtitle = '',
    this.subtitleFirst = false,
    this.trailing,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String subtitle;
  final bool subtitleFirst;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final hasArt = art.isNotEmpty;
    final size = narrow ? 58.0 : 71.0;
    final halo = DS.s(size + 6);
    final t = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Ink3D.text(28, FontWeight.w700, Ink3D.title, height: 1.25),
    );
    final s = subtitle.isEmpty
        ? null
        : Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Ink3D.text(14, FontWeight.w400, Ink3D.sub, letterSpacing: 0),
          );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: DS.s(100)),
      child: Padding(
        padding: EdgeInsets.only(top: DS.gv(12)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (hasArt) ...[
              Positioned(
                right: DS.s(12),
                top: DS.s(-4),
                child: ExcludeSemantics(
                  child: Container(
                    width: halo,
                    height: halo,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tone.halo,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: DS.s(16),
                top: DS.s(-6),
                child: ExcludeSemantics(
                  child: Art3D(asset: art, size: size),
                ),
              ),
            ],
            Padding(
              padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(10), DS.s(hasArt ? size + 22 : 18), 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (subtitleFirst) ?s,
                        t,
                        if (!subtitleFirst && s != null)
                          Padding(
                            padding: EdgeInsets.only(top: DS.s(3)),
                            child: s,
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null)
                    Padding(
                      padding: EdgeInsets.only(left: DS.gh(10)),
                      child: trailing,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoundIconButton3D extends StatelessWidget {
  const RoundIconButton3D({
    super.key,
    required this.asset,
    this.onTap,
    this.badge,
    this.size = 46,
    this.semanticsLabel,
    this.scaled = true,
  });

  final String asset;
  final VoidCallback? onTap;
  final Widget? badge;
  final double size;
  final String? semanticsLabel;
  final bool scaled;

  static Widget count(String text, {bool scaled = true}) => Container(
    padding: EdgeInsets.symmetric(horizontal: DS.s(5, scaled: scaled), vertical: DS.s(1, scaled: scaled)),
    constraints: BoxConstraints(minWidth: DS.s(17, scaled: scaled)),
    decoration: BoxDecoration(
      color: _kBadge,
      borderRadius: BorderRadius.circular(DS.s(9, scaled: scaled)),
    ),
    child: Text(
      text,
      maxLines: 1,
      textAlign: TextAlign.center,
      textScaler: TextScaler.noScaling,
      style: Ink3D.text(10, FontWeight.w500, Colors.white, letterSpacing: 0, scaled: scaled),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final box = DS.s(size, scaled: scaled);
    return _tap(
      onTap: onTap,
      label: semanticsLabel,
      child: SizedBox(
        width: box,
        height: box,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: DS.shadows(Ink3D.softShadow, scaled: scaled),
                ),
                child: Center(
                  child: Image.asset(
                    asset,
                    width: box * 28 / 46,
                    height: box * 28 / 46,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
            if (badge != null) Positioned(top: -DS.s(3, scaled: scaled), right: -DS.s(3, scaled: scaled), child: badge!),
          ],
        ),
      ),
    );
  }
}

class TitleRow3D extends StatelessWidget {
  const TitleRow3D({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.subtitle,
    this.tone,
    this.trailing,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final String? subtitle;
  final ListingTone? tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = tone ?? ListingTone.indigo;
    final sub = subtitle;
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(28), DS.s(18), DS.gv(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(
                      18,
                      FontWeight.w600,
                      Ink3D.body,
                      letterSpacing: 0.4,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: EdgeInsets.only(left: DS.gh(10)),
                  child: trailing,
                ),
              if (trailing == null && action != null)
                Padding(
                  padding: EdgeInsets.only(left: DS.gh(10)),
                  child: _tap(
                    onTap: onAction,
                    child: Padding(
                      padding: DS.sym(v: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            action!,
                            maxLines: 1,
                            style: Ink3D.text(
                              15,
                              FontWeight.w500,
                              t.text,
                              letterSpacing: 0.4,
                            ),
                          ),
                          SizedBox(width: DS.s(4)),
                          Icon(Icons.arrow_forward, size: DS.s(18), color: t.text),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (sub != null && sub.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: DS.s(4)),
              child: Text(
                sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Ink3D.text(
                  13,
                  FontWeight.w400,
                  Ink3D.grey,
                  letterSpacing: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ListingFilterChip extends StatelessWidget {
  const ListingFilterChip({
    super.key,
    required this.tone,
    required this.label,
    this.selected = true,
    this.dot = false,
    this.icon,
    this.onTap,
  });

  final ListingTone tone;
  final String label;
  final bool selected;
  final bool dot;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? Colors.white : tone.text;
    return _tap(
      onTap: onTap,
      child: Container(
        padding: DS.sym(h: 16, v: 8),
        decoration: BoxDecoration(
          borderRadius: DS.circular(22),
          gradient: selected ? tone.gradient : null,
          color: selected ? null : Colors.white,
          boxShadow: selected
              ? _toneShadow(tone, const Offset(1.1, 4), 8)
              : DS.shadows(Ink3D.softShadow),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: DS.s(16), color: ink),
              SizedBox(width: DS.s(6)),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ink3D.text(14, FontWeight.w700, ink, letterSpacing: 0),
              ),
            ),
            if (dot) ...[
              SizedBox(width: DS.s(7)),
              Container(
                width: DS.s(8),
                height: DS.s(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? Colors.white : tone.g2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MapPill3D extends StatelessWidget {
  const MapPill3D({
    super.key,
    required this.tone,
    required this.label,
    this.art = ListingArt.worldMap,
    this.onTap,
  });

  final ListingTone tone;
  final String label;
  final String art;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _tap(
      onTap: onTap,
      child: Container(
        padding: DS.insets(l: 12, t: 10, r: 22, b: 10),
        decoration: BoxDecoration(
          borderRadius: DS.circular(26),
          gradient: tone.gradient,
          boxShadow: _toneShadow(tone, const Offset(3, 8), 14, 0.55),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Art3D(
              asset: art,
              size: 30,
              shadowBlur: 2,
              shadowOffset: const Offset(2, 3),
              shadowAlpha: 0.3,
            ),
            SizedBox(width: DS.s(8)),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ink3D.text(
                  14,
                  FontWeight.w700,
                  Colors.white,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopBar3D extends StatelessWidget {
  const TopBar3D({
    super.key,
    required this.tone,
    required this.title,
    this.subtitle = '',
    this.stepChip,
    this.onBack,
    this.trailing,
    this.bottom,
  });

  final ListingTone tone;
  final String title;
  final String subtitle;
  final String? stepChip;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final chip = stepChip;
    final bar = Padding(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(10), DS.s(18), 0),
      child: Row(
        children: [
          if (onBack != null) ...[
            Tooltip(
              message: MaterialLocalizations.of(context).backButtonTooltip,
              child: _tap(
                onTap: onBack,
                child: Container(
                  width: DS.s(46),
                  height: DS.s(46),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: DS.shadows(Ink3D.softShadow),
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: DS.s(26),
                    color: tone.text,
                  ),
                ),
              ),
            ),
            Gap.h(12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(
                      22,
                      FontWeight.w700,
                      Ink3D.title,
                      height: 1.3,
                    ),
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(
                      13,
                      FontWeight.w400,
                      Ink3D.sub,
                      letterSpacing: 0,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
          if (chip != null && chip.isNotEmpty) ...[
            Gap.h(12),
            Container(
              padding: DS.sym(h: 12, v: 6),
              decoration: BoxDecoration(
                borderRadius: DS.circular(14),
                gradient: tone.gradient,
                boxShadow: _toneShadow(tone, const Offset(1.1, 3), 8),
              ),
              child: Text(
                chip,
                maxLines: 1,
                style: Ink3D.text(
                  12,
                  FontWeight.w700,
                  Colors.white,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
          if (trailing != null)
            Padding(padding: EdgeInsets.only(left: DS.gh(12)), child: trailing),
        ],
      ),
    );
    if (bottom == null) return bar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [bar, bottom!],
    );
  }
}

class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({
    super.key,
    required this.text,
    this.art = ListingArt.clipboard,
    this.margin = const EdgeInsets.fromLTRB(18, 14, 18, 0),
  });

  final String text;
  final String art;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(DS.s(margin.left), DS.gv(margin.top), DS.s(margin.right), DS.gv(margin.bottom)),
      padding: DS.sym(h: 16, v: 14),
      decoration: BoxDecoration(
        color: _kBannerFill,
        borderRadius: DS.br(_kChipRadius),
        boxShadow: DS.shadows(const [
          BoxShadow(
            color: Color(0x409E9E9E),
            offset: Offset(1.1, 1.1),
            blurRadius: 10,
          ),
        ]),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Image.asset(art, width: DS.s(34), height: DS.s(34), fit: BoxFit.contain),
          ),
          SizedBox(width: DS.s(10)),
          Expanded(
            child: Text(
              text,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: Ink3D.text(
                14,
                FontWeight.w400,
                _kBannerText,
                letterSpacing: 0,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DockShell extends StatelessWidget {
  const _DockShell({
    required this.maxWidth,
    required this.child,
    this.side = 22,
  });

  final double maxWidth;
  final double side;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    return Container(
      constraints: BoxConstraints(minHeight: DS.s(86) + inset),
      padding: EdgeInsets.fromLTRB(DS.s(side), DS.s(10), DS.s(side), DS.s(12) + inset),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radius(16))),
        boxShadow: DS.shadows(Ink3D.topEdge),
      ),
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, minHeight: DS.s(64)),
          child: Center(heightFactor: 1, child: child),
        ),
      ),
    );
  }
}

class DockBar extends StatelessWidget {
  const DockBar({
    super.key,
    required this.tone,
    required this.title,
    this.subtitle = '',
    this.actionLabel,
    this.onAction,
    this.loading = false,
    this.actionKey,
    this.subtitleKey,
    this.maxWidth = 640,
  });

  final ListingTone tone;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;
  final Key? actionKey;
  final Key? subtitleKey;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final stacked =
        MediaQuery.sizeOf(context).width < 300 ||
        MediaQuery.textScalerOf(context).scale(14) > 20;
    final label = actionLabel;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Ink3D.text(18, FontWeight.w600, Ink3D.title, letterSpacing: 0),
        ),
        if (subtitle.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: DS.s(2)),
            child: Text(
              subtitle,
              key: subtitleKey,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Ink3D.text(
                12,
                FontWeight.w400,
                Ink3D.grey,
                letterSpacing: 0,
              ),
            ),
          ),
      ],
    );
    final enabled = onAction != null && !loading;
    final button = label == null
        ? null
        : Opacity(
            opacity: onAction == null && !loading ? 0.5 : 1,
            child: _tap(
              key: actionKey,
              onTap: enabled ? onAction : null,
              label: loading ? label : null,
              child: Container(
                padding: DS.sym(
                  h: stacked ? 20 : 38,
                  v: 14,
                ),
                alignment: stacked ? Alignment.center : null,
                decoration: BoxDecoration(
                  borderRadius: DS.circular(30),
                  gradient: tone.gradient,
                  boxShadow: _toneShadow(tone, const Offset(3, 8), 14),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Visibility.maintain(
                      visible: !loading,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Ink3D.text(
                          16,
                          FontWeight.w700,
                          Colors.white,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    if (loading)
                      SizedBox(
                        width: DS.s(18),
                        height: DS.s(18),
                        child: CircularProgressIndicator(
                          strokeWidth: DS.s(2.2),
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
    return _DockShell(
      maxWidth: maxWidth,
      child: stacked
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                text,
                if (button != null)
                  Padding(
                    padding: EdgeInsets.only(top: DS.gv(10)),
                    child: button,
                  ),
              ],
            )
          : LayoutBuilder(
              builder: (context, box) => Row(
                children: [
                  Expanded(child: text),
                  if (button != null) ...[
                    Gap.h(12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: box.maxWidth * 0.58,
                      ),
                      child: button,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class DockLinks extends StatelessWidget {
  const DockLinks({
    super.key,
    required this.firstLabel,
    required this.onFirst,
    required this.secondLabel,
    required this.onSecond,
    this.tone,
    this.maxWidth = 720,
  });

  final String firstLabel;
  final VoidCallback onFirst;
  final String secondLabel;
  final VoidCallback onSecond;
  final ListingTone? tone;
  final double maxWidth;

  Widget _link(String label, VoidCallback onTap, Color color) => Expanded(
    child: _tap(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: DS.s(48)),
        child: Center(
          child: Padding(
            padding: DS.all(4),
            child: Text(
              label,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Ink3D.text(
                16,
                FontWeight.w700,
                color,
                letterSpacing: 0,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return _DockShell(
      maxWidth: maxWidth,
      side: 12,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _link(firstLabel, onFirst, (tone ?? ListingTone.indigo).text),
            Gap.h(8),
            _link(secondLabel, onSecond, Ink3D.grey),
          ],
        ),
      ),
    );
  }
}

class IconRow3D extends StatelessWidget {
  const IconRow3D({
    super.key,
    required this.art,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.tone,
    this.divider = false,
    this.tile = 56,
    this.titleStyle,
  });

  final String art;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final ListingTone? tone;
  final bool divider;
  final double tile;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final t = tone ?? ListingTone.indigo;
    final sub = subtitle;
    final row = Container(
      decoration: divider
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: Ink3D.line)),
            )
          : null,
      padding: DS.sym(h: 18, v: 13),
      child: Row(
        children: [
          SizedBox(
            width: DS.s(tile),
            height: DS.s(tile),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.haloBase.withValues(alpha: 0.14),
                      borderRadius: DS.circular(tile > 56 ? 18 : 16),
                    ),
                  ),
                ),
                Positioned(
                  left: DS.s(-2),
                  top: DS.s(tile > 56 ? -12 : -10),
                  child: ExcludeSemantics(
                    child: Art3D(
                      asset: art,
                      size: tile + 10,
                      shadowBlur: 4,
                      shadowOffset: const Offset(3, 5),
                      shadowAlpha: 0.28,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: DS.s(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      titleStyle ??
                      Ink3D.text(
                        16,
                        FontWeight.w500,
                        Ink3D.title,
                        letterSpacing: 0,
                        height: 1.3,
                      ),
                ),
                if (sub != null && sub.isNotEmpty)
                  Text(
                    sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(
                      13,
                      FontWeight.w400,
                      Ink3D.grey,
                      letterSpacing: 0,
                      height: 1.35,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: DS.s(8)),
          trailing ??
              Icon(
                Icons.chevron_right_rounded,
                size: DS.s(22),
                color: _kChevron,
              ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: row,
      ),
    );
  }
}

class WhiteCard3D extends StatelessWidget {
  const WhiteCard3D({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
    this.margin = const EdgeInsets.symmetric(horizontal: 18),
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(DS.s(margin.left), DS.gv(margin.top), DS.s(margin.right), DS.gv(margin.bottom)),
      padding: DS.insets(l: padding.left, t: padding.top, r: padding.right, b: padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DS.br(_kWhiteCardRadius),
        boxShadow: DS.shadows(const [
          BoxShadow(
            color: Color(0x339E9E9E),
            offset: Offset(1.1, 1.1),
            blurRadius: 10,
          ),
        ]),
      ),
      child: child,
    );
  }
}
