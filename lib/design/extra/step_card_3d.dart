import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'pill_buttons_3d.dart';

enum StepCardState { locked, current, done }

class StepCard3D extends StatelessWidget {
  const StepCard3D({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    required this.state,
    this.eyebrow,
    this.subtitle,
    this.trailingLabel,
    this.trailingIcon,
    this.onTap,
    this.subtitleBad = false,
    this.semanticsLabel,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final StepCardState state;
  final String? eyebrow;
  final String? subtitle;
  final String? trailingLabel;
  final IconData? trailingIcon;
  final VoidCallback? onTap;
  final bool subtitleBad;
  final String? semanticsLabel;

  static const double topRoom = 36;
  static const double gap = 16;
  static const List<double> _grey = <double>[0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0, 0, 0, 1, 0];

  Widget? _trailing(bool locked, double k) {
    final icon = trailingIcon;
    final label = trailingLabel;
    if (icon != null) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(shape: BoxShape.circle, color: locked ? Colors.white.withValues(alpha: 0.35) : Colors.white, boxShadow: locked ? null : Form3D.badge),
        child: Icon(icon, size: 18, color: locked ? Colors.white : tone.button),
      );
    }
    if (label == null || label.isEmpty) return null;
    return Container(
      width: 78 * k,
      height: 26 * k,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14 * k),
        color: locked ? Colors.white.withValues(alpha: 0.35) : Colors.white,
        boxShadow: locked ? null : Form3D.badge,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, maxLines: 1, softWrap: false, style: Ink3D.text(12.5, FontWeight.w700, locked ? Colors.white : tone.button, letterSpacing: 0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final scaler = MediaQuery.textScalerOf(context);
    final k = (scaler.scale(100) / 100).clamp(1.0, 1.3);
    final locked = state == StepCardState.locked;
    final artSize = narrow ? 96.0 : 118.0;
    final left = narrow ? 112.0 : 134.0;
    final eye = eyebrow;
    final sub = subtitle ?? '';
    final trail = _trailing(locked, k);
    final live = !locked && onTap != null;

    Widget image = Art3D(asset: art, size: artSize, halo: artSize - 2, haloColor: locked ? Form3D.lockHalo : tone.halo, haloDy: 5);
    if (locked) {
      image = Opacity(opacity: 0.5, child: ColorFiltered(colorFilter: const ColorFilter.matrix(_grey), child: image));
    }

    final card = Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: EdgeInsets.fromLTRB(left, 10, 14, 14),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(54), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
        gradient: locked ? Form3D.lockGradient : tone.gradient,
        border: state == StepCardState.current ? Border.all(color: Colors.white, width: 3, strokeAlign: BorderSide.strokeAlignOutside) : null,
        boxShadow: locked
            ? null
            : (state == StepCardState.current
                ? [BoxShadow(color: tone.shadow, offset: const Offset(1.1, 8), blurRadius: 16)]
                : [BoxShadow(color: tone.shadow, offset: const Offset(1.1, 4), blurRadius: 10)]),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 26),
            child: LayoutBuilder(builder: (context, box) {
              final eyeStyle = Ink3D.text(10.5, FontWeight.w700, Colors.white.withValues(alpha: 0.92), letterSpacing: 0.7);
              final eyeText = eye == null || eye.isEmpty ? null : Text(eye.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: eyeStyle);
              if (eyeText != null && trail != null) {
                final p = TextPainter(text: TextSpan(text: eye!.toUpperCase(), style: eyeStyle), maxLines: 1, textDirection: TextDirection.ltr, textScaler: scaler)..layout();
                final need = p.width;
                p.dispose();
                final pillW = trailingIcon != null ? 32.0 : 78 * k;
                if (need > box.maxWidth - pillW - 8) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [Align(alignment: Alignment.centerRight, child: trail), const SizedBox(height: 6), eyeText],
                  );
                }
              }
              return Row(
                children: [
                  Expanded(child: eyeText ?? const SizedBox.shrink()),
                  if (trail != null) Padding(padding: const EdgeInsets.only(left: 8), child: trail),
                ],
              );
            }),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FitLine3D(text: title, style: Ink3D.text(18, FontWeight.w700, Colors.white, height: 1.3)),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: scaler.scale(12.5) * 1.38 * 2),
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  sub,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(12.5, subtitleBad ? FontWeight.w700 : FontWeight.w400, Colors.white.withValues(alpha: subtitleBad ? 1 : 0.95), height: 1.38, letterSpacing: 0),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final label = semanticsLabel ?? [if (eye != null && eye.isNotEmpty) eye, title, if (sub.isNotEmpty) sub, ?trailingLabel, if (state == StepCardState.done) 'done', if (locked) 'locked'].join(', ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, topRoom + gap, 18, 0),
      child: Tap3D(
        onTap: live ? onTap : null,
        label: label,
        exclude: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            card,
            Positioned(left: 8, top: -topRoom - ArtLift.of(art, artSize), child: image),
            if (state == StepCardState.done)
              Positioned(
                left: narrow ? 78 : 96,
                top: narrow ? 44 : 56,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: Form3D.badge),
                  child: Icon(Icons.check_rounded, size: 20, color: tone.button),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
