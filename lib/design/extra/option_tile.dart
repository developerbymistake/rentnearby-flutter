import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'pill_buttons_3d.dart';
import 'pill_field.dart';

class OptionTileItem {
  const OptionTileItem({required this.label, required this.art, this.big});

  final String label;
  final String art;
  final String? big;
}

class OptionTileGrid extends StatelessWidget {
  const OptionTileGrid({
    super.key,
    required this.tone,
    required this.items,
    required this.isSelected,
    required this.onTap,
    this.columns = 3,
    this.errorText,
    this.tileHeight = 62,
  });

  final ListingTone tone;
  final List<OptionTileItem> items;
  final bool Function(int index) isSelected;
  final ValueChanged<int>? onTap;
  final int columns;
  final String? errorText;
  final double tileHeight;

  static const double topRoom = 38;
  static const double rowGap = 44;

  Widget _tile(int i, double height, bool bad) {
    final item = items[i];
    final on = isSelected(i);
    final small = columns >= 4;
    final art = small ? 48.0 : 56.0;
    final halo = small ? 46.0 : 52.0;
    final big = item.big;
    return Tap3D(
      onTap: onTap == null ? null : () => onTap!(i),
      label: big == null ? item.label : '$big ${item.label}',
      selected: on,
      exclude: true,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            height: height,
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(22), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
              color: on ? null : Form3D.wash(tone, 0.11),
              gradient: on ? tone.gradient : null,
              border: bad ? Border.all(color: Form3D.error, width: 1.5) : null,
              boxShadow: on ? [BoxShadow(color: tone.shadow, offset: const Offset(1.1, 4), blurRadius: 8)] : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(item.label, maxLines: 1, softWrap: false, style: Ink3D.text(13, FontWeight.w700, on ? Colors.white : tone.text, letterSpacing: 0, height: 1.1)),
            ),
          ),
          Positioned(
            top: -32,
            child: Art3D(asset: item.art, size: art, halo: halo, haloColor: Form3D.wash(tone, 0.14), haloDy: 2, shadowBlur: 4, shadowOffset: const Offset(3, 5)),
          ),
          if (big != null)
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(child: Text(big, maxLines: 1, style: Ink3D.text(22, FontWeight.w700, on ? Colors.white : tone.text, letterSpacing: 0, height: 1.2))),
            ),
          if (on)
            Positioned(
              right: -7,
              top: -7,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: Form3D.knob),
                child: Icon(Icons.check_rounded, size: 15, color: tone.button),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final hasBig = items.any((e) => e.big != null);
    final height = (hasBig ? tileHeight + 20 : tileHeight) + (scaler.scale(13) - 13) * 1.4 + (hasBig ? (scaler.scale(22) - 22) * 1.2 : 0);
    final e = errorText;
    final bad = e != null && e.isNotEmpty;
    final rows = (items.length / columns).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < rows; r++)
          Padding(
            padding: EdgeInsets.only(top: r == 0 ? topRoom : rowGap),
            child: Row(
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: 10),
                  Expanded(child: r * columns + c < items.length ? _tile(r * columns + c, height, bad) : const SizedBox.shrink()),
                ],
              ],
            ),
          ),
        if (bad) FieldMessage(error: e),
      ],
    );
  }
}

class GradientOptionCard extends StatelessWidget {
  const GradientOptionCard({super.key, required this.tone, required this.art, required this.label, required this.selected, required this.onTap, this.height = 80});

  final ListingTone tone;
  final String art;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final double height;

  static const double topRoom = 26;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final h = height + (scaler.scale(12) - 12) * 2.4;
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    return Padding(
      padding: const EdgeInsets.only(top: topRoom),
      child: Tap3D(
        onTap: onTap,
        label: label,
        selected: selected,
        exclude: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: h,
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 9),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(24), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
                gradient: tone.gradient,
                boxShadow: selected
                    ? [
                        BoxShadow(color: tone.shadow, offset: const Offset(1.1, 6), blurRadius: 12),
                        BoxShadow(color: tone.g2, spreadRadius: 5),
                        const BoxShadow(color: Colors.white, spreadRadius: 3),
                      ]
                    : null,
              ),
              child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w700, Colors.white, letterSpacing: 0, height: 1.2)),
            ),
            Positioned(left: 4, top: narrow ? -18 : -topRoom, child: Art3D(asset: art, size: narrow ? 48 : 62, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28)),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? Colors.white : Colors.white.withValues(alpha: 0.4)),
                child: selected ? Icon(Icons.check_rounded, size: 14, color: tone.button) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.tone,
    required this.label,
    required this.selected,
    required this.onTap,
    this.check = false,
    this.outlined = false,
    this.height = 36,
    this.topLabel,
    this.enabled = true,
  });

  final ListingTone tone;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool check;
  final bool outlined;
  final double height;
  final String? topLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final top = topLabel;
    final live = enabled && onTap != null;
    final ink = selected ? Colors.white : (outlined ? Ink3D.body : tone.text);
    final h = top == null ? height : (height < 64 ? 64.0 : height);
    final Widget content = top == null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (check && selected) ...[const Icon(Icons.check_rounded, size: 15, color: Colors.white), const SizedBox(width: 6)],
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w600, ink, letterSpacing: 0))),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(top, maxLines: 1, style: Ink3D.text(11, FontWeight.w600, ink.withValues(alpha: selected ? 0.92 : 0.8), letterSpacing: 0, height: 1.2)),
              Text(label, maxLines: 1, style: Ink3D.text(16, FontWeight.w700, ink, letterSpacing: 0, height: 1.25)),
            ],
          );
    final pill = Container(
      constraints: BoxConstraints(minHeight: h, minWidth: top == null ? 0 : 52),
      padding: EdgeInsets.symmetric(horizontal: top == null ? 14 : 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(top == null ? h / 2 : 20),
        color: selected ? null : (outlined ? Colors.white : Form3D.wash(tone, 0.11)),
        gradient: selected ? tone.gradient : null,
        border: Border.all(color: outlined && !selected ? Form3D.outline : Colors.transparent, width: 1.5),
        boxShadow: selected && live ? [BoxShadow(color: tone.shadow, offset: const Offset(1.1, 3), blurRadius: 6)] : null,
      ),
      child: Center(widthFactor: 1, heightFactor: 1, child: content),
    );
    return Tap3D(
      onTap: live ? onTap : null,
      label: top == null ? label : '$top $label',
      selected: selected,
      exclude: true,
      child: live ? pill : Opacity(opacity: 0.45, child: pill),
    );
  }
}

class SegmentPills extends StatelessWidget {
  const SegmentPills({super.key, required this.tone, required this.labels, required this.selected, required this.onTap, this.columns, this.height = 48, this.errorRing = false});

  final ListingTone tone;
  final List<String> labels;
  final int? selected;
  final ValueChanged<int>? onTap;
  final int? columns;
  final double height;
  final bool errorRing;

  Widget _cell(int i) {
    final on = i == selected;
    return Tap3D(
      onTap: onTap == null ? null : () => onTap!(i),
      label: labels[i],
      selected: on,
      exclude: true,
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          color: on ? null : Form3D.fill,
          gradient: on ? tone.gradient : null,
          border: Border.all(color: errorRing ? Form3D.error : Colors.transparent, width: 2),
          boxShadow: on ? [BoxShadow(color: tone.shadow, offset: const Offset(1.1, 4), blurRadius: 8)] : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(labels[i], maxLines: 1, softWrap: false, style: Ink3D.text(16, FontWeight.w700, on ? Colors.white : Form3D.label, letterSpacing: 0)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cols = columns ?? labels.length;
    final rows = (labels.length / cols).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows; r++)
          Padding(
            padding: EdgeInsets.only(top: r == 0 ? 0 : 10),
            child: Row(
              children: [
                for (var c = 0; c < cols; c++) ...[
                  if (c > 0) const SizedBox(width: 10),
                  Expanded(child: r * cols + c < labels.length ? _cell(r * cols + c) : const SizedBox.shrink()),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class DashedAddRow3D extends StatelessWidget {
  const DashedAddRow3D({super.key, required this.tone, required this.label, required this.onTap, this.trailing, this.enabled = true, this.margin = const EdgeInsets.fromLTRB(18, 20, 18, 0)});

  final ListingTone tone;
  final String label;
  final VoidCallback? onTap;
  final String? trailing;
  final bool enabled;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final live = enabled && onTap != null;
    final t = trailing;
    final row = CustomPaint(
      painter: _DashPainter(Form3D.wash(tone, 0.5), Form3D.wash(tone, 0.06)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: tone.gradient),
              child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: FitOrWrap3D(text: label, style: Ink3D.text(14.5, FontWeight.w700, tone.text, letterSpacing: 0))),
            if (t != null && t.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 124),
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(t, maxLines: 1, style: Ink3D.text(12, FontWeight.w600, Form3D.muted, letterSpacing: 0))),
                ),
              ),
          ],
        ),
      ),
    );
    return Padding(
      padding: margin,
      child: Tap3D(onTap: live ? onTap : null, child: live ? row : Opacity(opacity: 0.5, child: row)),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.line, this.fill);

  final Color line;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final box = RRect.fromRectAndCorners(
      (Offset.zero & size).deflate(1),
      topLeft: const Radius.circular(8),
      topRight: const Radius.circular(28),
      bottomLeft: const Radius.circular(8),
      bottomRight: const Radius.circular(8),
    );
    canvas.drawRRect(box, Paint()..color = fill);
    final pen = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..addRRect(box);
    for (final ui.PathMetric m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 7), pen);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.line != line || old.fill != fill;
}
