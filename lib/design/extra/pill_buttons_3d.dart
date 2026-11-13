import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'motion_kit.dart';

abstract final class Form3D {
  static const Color fill = Color(0xFFF2F3F8);
  static const Color fillOff = Color(0xFFECEEF3);
  static const Color fillError = Color(0xFFFFF4F4);
  static const Color error = Color(0xFFE0525C);
  static const Color errorText = Color(0xFFD03A44);
  static const Color hint = Color(0xFF9FA3AB);
  static const Color label = Color(0xFF4A6572);
  static const Color muted = Color(0xFF767676);
  static const Color todo = Color(0xFFE6E9F0);
  static const Color todoText = Color(0xFF8A8F99);
  static const Color amber = Color(0xFFC77700);
  static const Color switchOff = Color(0xFFDCE0E8);
  static const Color limit = Color(0xFFEEF0F4);
  static const Color outline = Color(0xFFE6E8EF);
  static const Color lockHalo = Color(0x1F78808C);
  static const LinearGradient lockGradient =
      LinearGradient(colors: [Color(0xFFC9CED8), Color(0xFFA2A9B6)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const LinearGradient dangerGradient =
      LinearGradient(colors: [Color(0xFFFE95B6), Color(0xFFFF5287)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const List<BoxShadow> dangerGlow = [BoxShadow(color: Color(0x73FF5287), offset: Offset(3, 8), blurRadius: 14)];
  static const List<BoxShadow> cardShadow = [BoxShadow(color: Color(0x389E9E9E), offset: Offset(1.1, 1.1), blurRadius: 10)];
  static const List<BoxShadow> knob = [BoxShadow(color: Color(0x40000000), offset: Offset(0, 2), blurRadius: 4)];
  static const List<BoxShadow> badge = [BoxShadow(color: Color(0x40000000), offset: Offset(2, 4), blurRadius: 6)];
  static const List<BoxShadow> onCard = [BoxShadow(color: Color(0x33000000), offset: Offset(3, 8), blurRadius: 14)];

  static List<BoxShadow> glow(ListingTone tone, {Offset offset = const Offset(3, 8), double blur = 14}) =>
      [BoxShadow(color: tone.shadow, offset: offset, blurRadius: blur)];

  static Color wash(ListingTone tone, double alpha) => tone.haloBase.withValues(alpha: alpha);

  static const double narrow = 340;
}

class Tap3D extends StatelessWidget {
  const Tap3D({super.key, required this.child, required this.onTap, this.label, this.selected, this.toggled, this.tapKey, this.exclude = false});

  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  final bool? selected;
  final bool? toggled;
  final Key? tapKey;
  final bool exclude;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Semantics(
      button: toggled == null,
      enabled: on,
      label: label,
      selected: selected,
      toggled: toggled,
      excludeSemantics: exclude,
      onTap: onTap,
      child: PressScale(
        enabled: on,
        child: GestureDetector(key: tapKey, behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
      ),
    );
  }
}

class FitLine3D extends StatelessWidget {
  const FitLine3D({super.key, required this.text, required this.style, this.stretch = 1.25});

  final String text;
  final TextStyle style;
  final double stretch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final p = TextPainter(text: TextSpan(text: text, style: style), maxLines: 1, textDirection: TextDirection.ltr, textScaler: MediaQuery.textScalerOf(context))..layout();
        final w = p.width;
        p.dispose();
        final line = Text(text, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: style);
        if (w <= box.maxWidth || w > box.maxWidth * stretch) return line;
        return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(text, maxLines: 1, softWrap: false, style: style));
      },
    );
  }
}

class FitOrWrap3D extends StatelessWidget {
  const FitOrWrap3D({super.key, required this.text, required this.style, this.maxLines = 2, this.stretch = 1.25});

  final String text;
  final TextStyle style;
  final int maxLines;
  final double stretch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final p = TextPainter(text: TextSpan(text: text, style: style), maxLines: 1, textDirection: TextDirection.ltr, textScaler: MediaQuery.textScalerOf(context))..layout();
        final w = p.width;
        p.dispose();
        if (w > box.maxWidth && w <= box.maxWidth * stretch) {
          return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(text, maxLines: 1, softWrap: false, style: style));
        }
        return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style);
      },
    );
  }
}

double _labelWidth(BuildContext context, String text, double size) {
  final p = TextPainter(
    text: TextSpan(text: text, style: Ink3D.text(size, FontWeight.w700, Colors.white)),
    maxLines: 1,
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final w = p.width;
  p.dispose();
  return w;
}

class _PillBody extends StatelessWidget {
  const _PillBody({required this.label, required this.color, required this.height, required this.fontSize, required this.expand, this.icon, this.loading = false});

  final String label;
  final Color color;
  final double height;
  final double fontSize;
  final bool expand;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 3, color: color, backgroundColor: color.withValues(alpha: 0.4)),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: fontSize + 4, color: color),
          const SizedBox(width: 8),
        ],
        Text(label, maxLines: 1, softWrap: false, style: Ink3D.text(fontSize, FontWeight.w700, color)),
      ],
    );
    final fitted = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: FittedBox(fit: BoxFit.scaleDown, child: row),
    );
    return SizedBox(height: height, width: expand ? double.infinity : null, child: expand ? Center(child: fitted) : Center(widthFactor: 1, child: fitted));
  }
}

abstract class _PillSpec {
  String get label;
  double get fontSize;
  IconData? get icon;
}

class GradientPillButton extends StatelessWidget implements _PillSpec {
  const GradientPillButton({
    super.key,
    required this.tone,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.enabled = true,
    this.danger = false,
    this.height = 54,
    this.icon,
    this.expand = true,
    this.fontSize = 16,
    this.semanticsLabel,
  });

  final ListingTone tone;
  @override
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool enabled;
  final bool danger;
  final double height;
  @override
  final IconData? icon;
  final bool expand;
  @override
  final double fontSize;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final live = enabled && onTap != null;
    final body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: danger ? Form3D.dangerGradient : tone.gradient,
        boxShadow: live ? (danger ? Form3D.dangerGlow : Form3D.glow(tone)) : null,
      ),
      child: _PillBody(label: label, color: Colors.white, height: height, fontSize: fontSize, expand: expand, icon: icon, loading: loading),
    );
    return Tap3D(
      onTap: live && !loading ? onTap : null,
      label: semanticsLabel,
      exclude: semanticsLabel != null,
      child: live || loading ? body : Opacity(opacity: 0.45, child: body),
    );
  }
}

class WhitePillButton extends StatelessWidget implements _PillSpec {
  const WhitePillButton({
    super.key,
    required this.tone,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.danger = false,
    this.height = 54,
    this.icon,
    this.expand = true,
    this.fontSize = 16,
    this.onGradient = false,
    this.semanticsLabel,
    this.neutral = false,
  });

  final ListingTone tone;
  @override
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool danger;
  final double height;
  @override
  final IconData? icon;
  final bool expand;
  @override
  final double fontSize;
  final bool onGradient;
  final bool neutral;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final live = enabled && onTap != null;
    final color = !live ? Ink3D.grey : (danger ? Form3D.errorText : (neutral ? Ink3D.grey : (onGradient ? tone.button : tone.text)));
    final body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        color: Colors.white,
        boxShadow: onGradient ? Form3D.onCard : Ink3D.softShadow,
      ),
      child: _PillBody(label: label, color: color, height: height, fontSize: fontSize, expand: expand, icon: icon),
    );
    return Tap3D(
      onTap: live ? onTap : null,
      label: semanticsLabel,
      exclude: semanticsLabel != null,
      child: live ? body : Opacity(opacity: 0.45, child: body),
    );
  }
}

class PillButtonRow extends StatelessWidget {
  const PillButtonRow({super.key, required this.children, this.gap = 12, this.stackUnder = 280});

  final List<Widget> children;
  final double gap;
  final double stackUnder;

  static const double _floor = 0.8;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) return children.first;
    return LayoutBuilder(
      builder: (context, box) {
        final cell = (box.maxWidth - gap * (children.length - 1)) / children.length;
        var stack = box.maxWidth < stackUnder;
        if (!stack) {
          for (final c in children) {
            if (c is! _PillSpec) continue;
            final spec = c as _PillSpec;
            final need = _labelWidth(context, spec.label, spec.fontSize) + (spec.icon == null ? 0 : spec.fontSize + 12);
            if (need * _floor > cell - 36) stack = true;
          }
        }
        if (stack) {
          final list = children.reversed.toList();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < list.length; i++) ...[if (i > 0) SizedBox(height: gap), list[i]],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(width: gap), Expanded(child: children[i])],
          ],
        );
      },
    );
  }
}
