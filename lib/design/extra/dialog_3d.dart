import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../tokens/design_colors.dart';
import '../tokens/listing_palette.dart';
import 'art_3d.dart';
import 'pill_buttons_3d.dart';

class DialogLine {
  const DialogLine(this.text, {this.art});

  final String text;
  final String? art;
}

class Dialog3D extends StatelessWidget {
  const Dialog3D({
    super.key,
    required this.tone,
    required this.title,
    this.art,
    this.body,
    this.content,
    this.lines = const [],
    this.note,
    this.primaryLabel,
    this.onPrimary,
    this.primaryDanger = false,
    this.primaryEnabled = true,
    this.primaryLoading = false,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryDanger = false,
    this.tertiaryLabel,
    this.onTertiary,
    this.stacked = false,
    this.minBodyLines = 2,
    this.primaryKey,
    this.secondaryKey,
    this.actions,
    this.actionsHorizontal = false,
    this.label,
    this.leftAlign = false,
    this.artDanger = false,
    this.familyCorner = false,
    this.tight = false,
    this.secondaryNeutral = false,
    this.titleSize = 21,
  });

  final ListingTone tone;
  final String title;
  final String? art;
  final String? body;
  final Widget? content;
  final List<DialogLine> lines;
  final String? note;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryDanger;
  final bool primaryEnabled;
  final bool primaryLoading;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool secondaryDanger;
  final String? tertiaryLabel;
  final VoidCallback? onTertiary;
  final bool stacked;
  final int minBodyLines;
  final Key? primaryKey;
  final Key? secondaryKey;
  // Ready-made buttons (legacy dialogs); replaces the label buttons.
  final List<Widget>? actions;
  final bool actionsHorizontal;
  // Small caps line above the title (pickers).
  final String? label;
  final bool leftAlign;
  final bool artDanger;
  final bool familyCorner;
  final bool tight;
  final bool secondaryNeutral;
  final double titleSize;

  static const double artRoom = 66;

  static Future<T?> show<T>(BuildContext context, {required WidgetBuilder builder, bool barrierDismissible = true}) =>
      showGeneralDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: DesignColors.scrim,
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (ctx, _, _) => builder(ctx),
        transitionBuilder: (ctx, anim, _, child) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4 * anim.value, sigmaY: 4 * anim.value),
          child: FadeTransition(opacity: anim, child: child),
        ),
      );

  Widget? _buttons() {
    final custom = actions;
    if (custom != null) {
      if (custom.isEmpty) return null;
      if (actionsHorizontal) return PillButtonRow(stackUnder: 200, children: custom);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < custom.length; i++) ...[if (i > 0) const SizedBox(height: 10), custom[i]],
        ],
      );
    }
    final h = stacked ? 48.0 : 50.0;
    final primary = primaryLabel == null
        ? null
        : GradientPillButton(
            key: primaryKey,
            tone: tone,
            label: primaryLabel!,
            onTap: onPrimary,
            danger: primaryDanger,
            enabled: primaryEnabled,
            loading: primaryLoading,
            height: h,
            fontSize: 15,
          );
    final secondary = secondaryLabel == null
        ? null
        : WhitePillButton(key: secondaryKey, tone: tone, label: secondaryLabel!, onTap: onSecondary, danger: secondaryDanger, neutral: secondaryNeutral, height: h, fontSize: 15);
    final tertiary = tertiaryLabel == null ? null : WhitePillButton(tone: tone, label: tertiaryLabel!, onTap: onTertiary, height: h, fontSize: 15);
    final list = <Widget>[?primary, ?secondary, ?tertiary];
    if (list.isEmpty) return null;
    if (stacked || tertiary != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < list.length; i++) ...[if (i > 0) const SizedBox(height: 10), list[i]],
        ],
      );
    }
    return PillButtonRow(stackUnder: 200, children: [?secondary, ?primary]);
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final a = art;
    final simple = lines.isEmpty && content == null && !stacked && a != null && !leftAlign;
    final align = leftAlign ? TextAlign.left : TextAlign.center;
    final buttons = _buttons();
    final top = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(label!, textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w600, Ink3D.grey, letterSpacing: 0.3)),
          ),
        Semantics(
          header: true,
          namesRoute: true,
          child: Text(
            title,
            textAlign: align,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: label != null ? Ink3D.text(24, FontWeight.w700, tone.text, height: 1.25) : Ink3D.text(titleSize, FontWeight.w700, Ink3D.title, height: 1.25),
          ),
        ),
        if (body != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: simple ? minBodyLines * 14.5 * 1.5 * scale : 0),
              child: Text(body!, textAlign: align, style: Ink3D.text(14.5, FontWeight.w400, Ink3D.copy, height: 1.5)),
            ),
          ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(note!, textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, const Color(0xFF8A8F99), height: 1.4)),
          ),
        if (lines.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF2F3F8), borderRadius: BorderRadius.circular(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        if (l.art != null) ...[Image.asset(l.art!, width: 26, height: 26, fit: BoxFit.contain), const SizedBox(width: 10)],
                        Expanded(child: Text(l.text, style: Ink3D.text(13, FontWeight.w500, Ink3D.body, height: 1.35))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (content != null) Padding(padding: const EdgeInsets.only(top: 12), child: content),
      ],
    );
    final card = Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: simple && !tight ? 300 : 0),
      padding: EdgeInsets.fromLTRB(22, a != null ? 84 : 26, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: familyCorner ? BusyOverlay3D.radius : BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 10), blurRadius: 30)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          top,
          if (buttons != null) Padding(padding: const EdgeInsets.only(top: 22), child: buttons),
        ],
      ),
    );
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: EdgeInsets.only(top: a != null ? artRoom : 0),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    card,
                    if (a != null)
                      Positioned(
                        top: -artRoom,
                        left: leftAlign ? 4 : null,
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: Art3D(asset: a, size: 128, halo: 136, haloColor: (artDanger ? const Color(0xFFE0525C) : tone.haloBase).withValues(alpha: 0.18), shadowBlur: 7, shadowOffset: const Offset(5, 9), shadowAlpha: 0.3),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BusyOverlay3D extends StatelessWidget {
  const BusyOverlay3D({super.key, required this.tone, required this.message, this.art, this.progress, this.caption});

  final ListingTone tone;
  final String message;
  final String? art;
  final double? progress;
  final String? caption;

  static const BorderRadius radius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(54), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final card = Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(22, 84, 22, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: [BoxShadow(color: Color(0x4D000000), offset: Offset(0, 10), blurRadius: 30)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center, style: Ink3D.text(17, FontWeight.w700, Ink3D.title, height: 1.3)),
          if (p == null)
            Padding(padding: const EdgeInsets.only(top: 8), child: SizedBox(height: 30, child: _BusyDots(color: tone.g2)))
          else
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: 112,
                height: 112,
                child: CustomPaint(
                  painter: _RingPainter(progress: p.clamp(0, 1).toDouble(), color: tone.g2, track: tone.haloBase.withValues(alpha: 0.16)),
                  child: Center(
                    child: Text('${(p.clamp(0, 1) * 100).round()}%', textScaler: TextScaler.noScaling, style: Ink3D.text(24, FontWeight.w600, tone.text, height: 1)),
                  ),
                ),
              ),
            ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(caption!, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w400, Ink3D.grey)),
            ),
        ],
      ),
    );
    return AbsorbPointer(
      child: Semantics(
        liveRegion: true,
        container: true,
        child: ColoredBox(
          color: DesignColors.scrim,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
              child: Material(
                type: MaterialType.transparency,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    card,
                    Positioned(
                      top: -58,
                      child: ExcludeSemantics(
                        child: Art3D(asset: art ?? ListingArt.airplane, size: 124, halo: 124, haloColor: const Color(0x47FFFFFF), shadowBlur: 7, shadowOffset: const Offset(5, 9), shadowAlpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BusyDots extends StatefulWidget {
  const _BusyDots({required this.color});

  final Color color;

  @override
  State<_BusyDots> createState() => _BusyDotsState();
}

class _BusyDotsState extends State<_BusyDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.35 + 0.65 * (0.5 + 0.5 * math.sin((_c.value - i * 0.18) * 2 * math.pi))),
              ),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color, required this.track});

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(4);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = track;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint);
    paint
      ..color = color
      ..strokeCap = StrokeCap.round;
    if (progress > 0) canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color || old.track != track;
}

class MenuItem3D {
  const MenuItem3D({required this.label, required this.onTap, this.art, this.icon, this.danger = false, this.positive = false});

  final String label;
  final VoidCallback? onTap;
  final String? art;
  final IconData? icon;
  final bool danger;
  final bool positive;
}

class MenuPopup3D extends StatelessWidget {
  const MenuPopup3D({super.key, required this.items, this.width = 196});

  final List<MenuItem3D> items;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(32), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
          boxShadow: const [BoxShadow(color: Color(0x4D000000), offset: Offset(0, 10), blurRadius: 28)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1, thickness: 1, color: Ink3D.line),
              _row(items[i]),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _row(MenuItem3D item) {
    return Tap3D(
                onTap: item.onTap,
                child: Opacity(
                  opacity: item.onTap == null ? 0.45 : 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          if (item.art != null) ...[
                            Image.asset(item.art!, width: 30, height: 30, fit: BoxFit.contain),
                            const SizedBox(width: 12),
                          ] else if (item.icon != null) ...[
                            SizedBox(width: 30, height: 30, child: Icon(item.icon, size: 22, color: _ink(item))),
                            const SizedBox(width: 12),
                          ],
                          Expanded(child: Text(item.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14.5, FontWeight.w600, _ink(item)))),
                        ],
                      ),
                    ),
                  ),
                ),
              );
  }

  static Color _ink(MenuItem3D item) => item.danger ? const Color(0xFFE0406F) : (item.positive ? const Color(0xFF2E7D32) : Ink3D.body);
}

// Opens under [anchor] (global rect of the menu button), kept inside the screen.
Future<void> showMenu3D(BuildContext context, {required Rect anchor, required List<MenuItem3D> items, double width = 196, bool coverAnchor = false}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x33141828),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (ctx, _, _) {
      final wrapped = [
        for (final item in items)
          MenuItem3D(
            label: item.label,
            art: item.art,
            icon: item.icon,
            danger: item.danger,
            positive: item.positive,
            onTap: item.onTap == null
                ? null
                : () {
                    Navigator.of(ctx).pop();
                    item.onTap!();
                  },
          ),
      ];
      return CustomSingleChildLayout(
        delegate: _MenuLayout(anchor, MediaQuery.paddingOf(ctx), coverAnchor),
        child: MenuPopup3D(items: wrapped, width: width),
      );
    },
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(opacity: anim, child: child),
  );
}

class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout(this.anchor, this.inset, this.cover);

  final Rect anchor;
  final EdgeInsets inset;
  final bool cover;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints.loose(Size(constraints.maxWidth - 16, constraints.maxHeight - inset.vertical - 16));

  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = (anchor.right - child.width).clamp(8.0, math.max(8.0, size.width - child.width - 8)).toDouble();
    var y = cover ? anchor.top : anchor.bottom + 6;
    final maxY = size.height - inset.bottom - child.height - 8;
    if (y > maxY) y = math.max(inset.top + 8, anchor.top - child.height - 6);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuLayout old) => old.anchor != anchor || old.inset != inset || old.cover != cover;
}
