import 'package:flutter/material.dart';

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
const List<BoxShadow> _kFieldShadow = [BoxShadow(color: Color(0x599E9E9E), offset: Offset(3, 5), blurRadius: 12)];

List<BoxShadow> _toneShadow(ListingTone tone, Offset offset, double blur, [double alpha = 0.5]) =>
    [BoxShadow(color: tone.haloBase.withValues(alpha: alpha), offset: offset, blurRadius: blur)];

Widget _tap({required Widget child, VoidCallback? onTap, Key? key, String? label, bool? selected}) {
  final body = Semantics(
    button: true,
    enabled: onTap != null,
    selected: selected,
    label: label,
    child: GestureDetector(key: key, behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
  );
  return onTap == null ? body : PressScale(child: body);
}

class ChipCP extends StatelessWidget {
  const ChipCP({super.key, required this.tone, required this.art, required this.label, this.off = false, this.onTap});

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
              padding: const EdgeInsets.only(top: 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: _kChipRadius,
                  gradient: tone.gradient,
                  boxShadow: off ? const [] : tone.glow(blur: 8),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(70, 12, 18, 12),
                  child: Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, Colors.white, letterSpacing: 0)),
                ),
              ),
            ),
            Positioned(left: 6, top: 0, child: Art3D(asset: art, size: 58, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28)),
          ],
        ),
      ),
    );
  }
}

class ChipCPRow extends StatelessWidget {
  const ChipCPRow({super.key, required this.children, this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 4), this.controller});

  final List<Widget> children;
  final EdgeInsets padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: padding.copyWith(top: (padding.top - 20).clamp(0, double.infinity), bottom: padding.bottom + 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 12), children[i]],
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
    final size = inline ? 44.0 : 56.0;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w400, Ink3D.hint, letterSpacing: 0)),
          ),
        hint
            ? (value.length <= 26
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, maxLines: 1, style: Ink3D.text(inline ? 16 : 15, FontWeight.w400, inline ? _kInlineHint : Ink3D.hint, letterSpacing: 0)),
                  )
                : Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(inline ? 16 : 15, FontWeight.w400, inline ? _kInlineHint : Ink3D.hint, letterSpacing: 0)))
            : Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ink3D.text(inline ? 16 : 15, FontWeight.w400, Ink3D.body, letterSpacing: 0),
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
          boxShadow: flat ? const [] : _toneShadow(tone, inline ? const Offset(3, 6) : const Offset(4, 8), inline ? 10 : 12),
        ),
        alignment: Alignment.center,
        child: buttonChild ?? Art3D(asset: buttonArt, size: inline ? 30 : 42, shadowBlur: 2, shadowOffset: const Offset(2, 3), shadowAlpha: 0.3),
      ),
    );
    final pill = BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(38)),
      boxShadow: flat ? const [BoxShadow(color: Color(0x1F000000), offset: Offset(0, 3), blurRadius: 10)] : _kFieldShadow,
    );
    if (inline) {
      final body = Container(
        margin: margin ?? const EdgeInsets.fromLTRB(18, 16, 18, 0),
        padding: padding ?? const EdgeInsets.fromLTRB(20, 10, 12, 10),
        decoration: pill,
        child: Row(children: [Expanded(child: field ?? text), const SizedBox(width: 10), button]),
      );
      if (field != null || onTap == null) return body;
      return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: body);
    }
    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: onTap != null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 64),
                  padding: EdgeInsets.fromLTRB(leadingArt == null ? 22 : 12, 10, 18, 10),
                  decoration: pill,
                  child: Row(
                    children: [
                      if (leadingArt != null) ...[
                        Art3D(asset: leadingArt!, size: 44, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.25),
                        const SizedBox(width: 12),
                      ],
                      Expanded(child: text),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
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
    final size = narrow ? 96.0 : 118.0;
    final halo = size + 6;
    final t = Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(28, FontWeight.w700, Ink3D.title, height: 1.25));
    final s = subtitle.isEmpty ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w400, Ink3D.sub, letterSpacing: 0));
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 100),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (hasArt) ...[
            Positioned(
              right: 12,
              top: -6,
              child: ExcludeSemantics(child: Container(width: halo, height: halo, decoration: BoxDecoration(shape: BoxShape.circle, color: tone.halo))),
            ),
            Positioned(right: 16, top: -8, child: ExcludeSemantics(child: Art3D(asset: art, size: size))),
          ],
          Padding(
            padding: EdgeInsets.fromLTRB(18, 10, hasArt ? size + 22 : 18, 0),
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
                      if (!subtitleFirst && s != null) Padding(padding: const EdgeInsets.only(top: 3), child: s),
                    ],
                  ),
                ),
                if (trailing != null) Padding(padding: const EdgeInsets.only(left: 10), child: trailing),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RoundIconButton3D extends StatelessWidget {
  const RoundIconButton3D({super.key, required this.asset, this.onTap, this.badge, this.size = 46, this.semanticsLabel});

  final String asset;
  final VoidCallback? onTap;
  final Widget? badge;
  final double size;
  final String? semanticsLabel;

  static Widget count(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        constraints: const BoxConstraints(minWidth: 17),
        decoration: BoxDecoration(color: _kBadge, borderRadius: BorderRadius.circular(9)),
        child: Text(text, maxLines: 1, textAlign: TextAlign.center, textScaler: TextScaler.noScaling, style: Ink3D.text(10, FontWeight.w500, Colors.white, letterSpacing: 0)),
      );

  @override
  Widget build(BuildContext context) {
    return _tap(
      onTap: onTap,
      label: semanticsLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: Ink3D.softShadow),
                child: Center(child: Image.asset(asset, width: size * 28 / 46, height: size * 28 / 46, fit: BoxFit.contain, filterQuality: FilterQuality.high)),
              ),
            ),
            if (badge != null) Positioned(top: -3, right: -3, child: badge!),
          ],
        ),
      ),
    );
  }
}

class TitleRow3D extends StatelessWidget {
  const TitleRow3D({super.key, required this.title, this.action, this.onAction, this.subtitle, this.tone, this.trailing});

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
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(18, FontWeight.w600, Ink3D.body, letterSpacing: 0.4, height: 1.3)),
                ),
              ),
              if (trailing != null) Padding(padding: const EdgeInsets.only(left: 10), child: trailing),
              if (trailing == null && action != null)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: _tap(
                    onTap: onAction,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(action!, maxLines: 1, style: Ink3D.text(15, FontWeight.w500, t.text, letterSpacing: 0.4)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 18, color: t.text),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (sub != null && sub.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
            ),
        ],
      ),
    );
  }
}

class ListingFilterChip extends StatelessWidget {
  const ListingFilterChip({super.key, required this.tone, required this.label, this.selected = true, this.dot = false, this.icon, this.onTap});

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: selected ? tone.gradient : null,
          color: selected ? null : Colors.white,
          boxShadow: selected ? _toneShadow(tone, const Offset(1.1, 4), 8) : Ink3D.softShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: ink), const SizedBox(width: 6)],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, ink, letterSpacing: 0))),
            if (dot) ...[
              const SizedBox(width: 7),
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? Colors.white : tone.g2)),
            ],
          ],
        ),
      ),
    );
  }
}

class MapPill3D extends StatelessWidget {
  const MapPill3D({super.key, required this.tone, required this.label, this.art = ListingArt.worldMap, this.onTap});

  final ListingTone tone;
  final String label;
  final String art;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 22, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: tone.gradient,
          boxShadow: _toneShadow(tone, const Offset(3, 8), 14, 0.55),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Art3D(asset: art, size: 30, shadowBlur: 2, shadowOffset: const Offset(2, 3), shadowAlpha: 0.3),
            const SizedBox(width: 8),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, Colors.white, letterSpacing: 0))),
          ],
        ),
      ),
    );
  }
}

class TopBar3D extends StatelessWidget {
  const TopBar3D({super.key, required this.tone, required this.title, this.subtitle = '', this.stepChip, this.onBack, this.trailing, this.bottom});

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
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Row(
        children: [
          if (onBack != null) ...[
            Tooltip(
              message: MaterialLocalizations.of(context).backButtonTooltip,
              child: _tap(
                onTap: onBack,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: Ink3D.softShadow),
                  child: Icon(Icons.chevron_left_rounded, size: 26, color: tone.text),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(22, FontWeight.w700, Ink3D.title, height: 1.3)),
                ),
                if (subtitle.isNotEmpty) Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w400, Ink3D.sub, letterSpacing: 0, height: 1.4)),
              ],
            ),
          ),
          if (chip != null && chip.isNotEmpty) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: tone.gradient,
                boxShadow: _toneShadow(tone, const Offset(1.1, 3), 8),
              ),
              child: Text(chip, maxLines: 1, style: Ink3D.text(12, FontWeight.w700, Colors.white, letterSpacing: 0)),
            ),
          ],
          if (trailing != null) Padding(padding: const EdgeInsets.only(left: 12), child: trailing),
        ],
      ),
    );
    if (bottom == null) return bar;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [bar, bottom!]);
  }
}

class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key, required this.text, this.art = ListingArt.clipboard, this.margin = const EdgeInsets.fromLTRB(18, 14, 18, 0)});

  final String text;
  final String art;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: _kBannerFill,
        borderRadius: _kChipRadius,
        boxShadow: [BoxShadow(color: Color(0x409E9E9E), offset: Offset(1.1, 1.1), blurRadius: 10)],
      ),
      child: Row(
        children: [
          ExcludeSemantics(child: Image.asset(art, width: 34, height: 34, fit: BoxFit.contain)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, maxLines: 8, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w400, _kBannerText, letterSpacing: 0, height: 1.4))),
        ],
      ),
    );
  }
}

class _DockShell extends StatelessWidget {
  const _DockShell({required this.maxWidth, required this.child, this.side = 22});

  final double maxWidth;
  final double side;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    return Container(
      constraints: BoxConstraints(minHeight: 86 + inset),
      padding: EdgeInsets.fromLTRB(side, 10, side, 12 + inset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: Ink3D.topEdge,
      ),
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth, minHeight: 64), child: Center(heightFactor: 1, child: child)),
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
    final stacked = MediaQuery.sizeOf(context).width < 300 || MediaQuery.textScalerOf(context).scale(14) > 20;
    final label = actionLabel;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(18, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
        if (subtitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subtitle, key: subtitleKey, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
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
                padding: EdgeInsets.symmetric(horizontal: stacked ? 20 : 38, vertical: 14),
                alignment: stacked ? Alignment.center : null,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: tone.gradient,
                  boxShadow: _toneShadow(tone, const Offset(3, 8), 14),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Visibility.maintain(
                      visible: !loading,
                      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w700, Colors.white, letterSpacing: 0)),
                    ),
                    if (loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)),
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
              children: [text, if (button != null) Padding(padding: const EdgeInsets.only(top: 10), child: button)],
            )
          : LayoutBuilder(
              builder: (context, box) => Row(
                children: [
                  Expanded(child: text),
                  if (button != null) ...[
                    const SizedBox(width: 12),
                    ConstrainedBox(constraints: BoxConstraints(maxWidth: box.maxWidth * 0.58), child: button),
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
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(label, maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Ink3D.text(16, FontWeight.w700, color, letterSpacing: 0, height: 1.25)),
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
            const SizedBox(width: 8),
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
      decoration: divider ? const BoxDecoration(border: Border(top: BorderSide(color: Ink3D.line))) : null,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          SizedBox(
            width: tile,
            height: tile,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(decoration: BoxDecoration(color: t.haloBase.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(tile > 56 ? 18 : 16))),
                ),
                Positioned(
                  left: -2,
                  top: tile > 56 ? -12 : -10,
                  child: ExcludeSemantics(child: Art3D(asset: art, size: tile + 10, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle ?? Ink3D.text(16, FontWeight.w500, Ink3D.title, letterSpacing: 0, height: 1.3)),
                if (sub != null && sub.isNotEmpty)
                  Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w400, Ink3D.grey, letterSpacing: 0, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing ?? const Icon(Icons.chevron_right_rounded, size: 22, color: _kChevron),
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(button: true, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row));
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
      margin: margin,
      padding: padding,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: _kWhiteCardRadius,
        boxShadow: [BoxShadow(color: Color(0x339E9E9E), offset: Offset(1.1, 1.1), blurRadius: 10)],
      ),
      child: child,
    );
  }
}
