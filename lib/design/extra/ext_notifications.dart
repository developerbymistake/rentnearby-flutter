import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'pill_buttons_3d.dart';

abstract final class NotificationTone {
  static ListingTone of(String kind) => switch (kind) {
        'approved' => ListingTone.cE,
        'rejected' => ListingTone.cC,
        'takedown' => ListingTone.cF,
        _ => ListingTone.cB,
      };

  static const Color skeletonA = Color(0xFFE4E7F0);
  static const Color skeletonB = Color(0xFFD6DAE6);
  static const Color skeletonHalo = Color(0xFFCDD2E0);
  static const Color skeletonBar = Color(0xFFC5CAD9);
  static const Color skeletonGo = Color(0xFFEEF0F5);
  static const Color goFill = Color(0xFFFAFAFA);
  static const Color pillFill = Color(0x42FFFFFF);
  static const Color haloFill = Color(0x3DFAFAFA);
  static const List<BoxShadow> readShadow = [BoxShadow(color: Color(0x24000000), offset: Offset(1.1, 2), blurRadius: 6)];
  static const List<BoxShadow> newPillShadow = [BoxShadow(color: Color(0x2E000000), offset: Offset(2, 3), blurRadius: 6)];
  static const List<BoxShadow> goShadow = [BoxShadow(color: Color(0x59213333), offset: Offset(6, 6), blurRadius: 8)];
  static const List<BoxShadow> skeletonShadow = [BoxShadow(color: Color(0x4D9E9E9E), offset: Offset(1.1, 3), blurRadius: 8)];

  static Color washed(Color c) {
    const s = 0.5;
    const b = 1.06;
    final r = c.r, g = c.g, bl = c.b;
    double ch(double v) => (v * b).clamp(0.0, 1.0);
    return Color.from(
      alpha: c.a,
      red: ch((0.213 + 0.787 * s) * r + (0.715 - 0.715 * s) * g + (0.072 - 0.072 * s) * bl),
      green: ch((0.213 - 0.213 * s) * r + (0.715 + 0.285 * s) * g + (0.072 - 0.072 * s) * bl),
      blue: ch((0.213 - 0.213 * s) * r + (0.715 - 0.715 * s) * g + (0.072 + 0.928 * s) * bl),
    );
  }
}

const BorderRadius _cardRadius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(44), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

class NotificationHeader3D extends StatelessWidget {
  const NotificationHeader3D({super.key, required this.tone, required this.title, required this.art, this.onBack, this.action});

  final ListingTone tone;
  final String title;
  final String art;
  final VoidCallback? onBack;
  final Widget? action;

  static double heightFor(BuildContext context) {
    final s = MediaQuery.textScalerOf(context).scale(1);
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final title = (narrow ? 24.0 : 28.0) * 1.2 * s;
    final h = 10 + 46 + 14 + title + 8;
    return h < 128 ? 128 : h;
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final artSize = narrow ? 84.0 : 118.0;
    final clear = artSize + (narrow ? 30 : 34);
    final tip = MaterialLocalizations.of(context).backButtonTooltip;
    final back = onBack == null
        ? null
        : Tooltip(
            message: tip,
            excludeFromSemantics: true,
            child: Tap3D(
              onTap: onBack,
              label: tip,
              exclude: true,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: Ink3D.softShadow),
                child: Icon(Icons.chevron_left_rounded, size: 30, color: tone.text),
              ),
            ),
          );
    return SizedBox(
      height: heightFor(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 16,
            top: 6,
            child: ExcludeSemantics(child: Art3D(asset: art, size: artSize, halo: artSize + 6, haloColor: tone.halo, haloDy: -1)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, 10, clear, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 46,
                  child: Row(
                    children: [
                      ?back,
                      if (action != null) ...[const SizedBox(width: 12), Flexible(child: action!)],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Semantics(
                  header: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(title, maxLines: 1, softWrap: false, style: Ink3D.text(narrow ? 24 : 28, FontWeight.w700, Ink3D.title, height: 1.2)),
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

class _NotificationFrame extends StatelessWidget {
  const _NotificationFrame({required this.tone, required this.art, required this.title, required this.body, required this.bottom, this.read = false, this.onTap, this.titleLines = 1, this.bodyLines = 2});

  final ListingTone tone;
  final String art;
  final String title;
  final String body;
  final Widget bottom;
  final bool read;
  final VoidCallback? onTap;
  final int titleLines;
  final int bodyLines;

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.textScalerOf(context).scale(1);
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final artSize = narrow ? 80.0 : 94.0;
    final textLeft = narrow ? 92.0 : 108.0;
    final g1 = read ? NotificationTone.washed(tone.g1) : tone.g1;
    final g2 = read ? NotificationTone.washed(tone.g2) : tone.g2;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(textLeft, 12, 14, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, maxLines: titleLines, overflow: TextOverflow.ellipsis, style: Ink3D.text(14.5, FontWeight.w700, Colors.white, height: 20 / 14.5)),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: 36 * s),
                child: Text(body, maxLines: bodyLines, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Colors.white.withValues(alpha: 0.96), height: 18 / 12.5)),
              ),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: bottom),
      ],
    );
    final card = Container(
      decoration: BoxDecoration(
        borderRadius: _cardRadius,
        gradient: LinearGradient(colors: [g1, g2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: read ? NotificationTone.readShadow : tone.glow(),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: _cardRadius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, customBorder: const RoundedRectangleBorder(borderRadius: _cardRadius), child: content),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 34, 14, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            left: 7,
            top: -32,
            child: IgnorePointer(
              child: ExcludeSemantics(child: Art3D(asset: art, size: artSize, halo: artSize, haloColor: NotificationTone.haloFill, haloDy: 4, shadowBlur: 5, shadowOffset: const Offset(4, 7))),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationCard3D extends StatelessWidget {
  const NotificationCard3D({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    required this.body,
    required this.time,
    this.unit = '',
    this.tag,
    this.isNew = false,
    this.read = false,
    this.opens = true,
    this.onTap,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String body;
  final String time;
  final String unit;
  final String? tag;
  final bool isNew;
  final bool read;
  final bool opens;
  final VoidCallback? onTap;

  Widget _pill(String label, {bool white = false, required Color ink}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: white ? Colors.white : NotificationTone.pillFill,
          borderRadius: BorderRadius.circular(10),
          boxShadow: white ? NotificationTone.newPillShadow : null,
        ),
        child: Text(label, maxLines: 1, softWrap: false, style: Ink3D.text(11, FontWeight.w700, white ? ink : Colors.white, letterSpacing: 0.4)),
      );

  @override
  Widget build(BuildContext context) {
    final ink = read ? NotificationTone.washed(tone.button) : tone.button;
    final pills = <Widget>[
      if (tag != null) _pill(tag!, ink: ink),
      if (isNew) _pill('NEW', white: true, ink: ListingTone.indigo.g2),
    ];
    final bottom = SizedBox(
      height: 36,
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 86),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(time, maxLines: 1, softWrap: false, style: Ink3D.text(20, FontWeight.w600, Colors.white, height: 1, letterSpacing: 0)),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(unit, maxLines: 1, softWrap: false, style: Ink3D.text(11, FontWeight.w500, Colors.white, height: 1)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < pills.length; i++) ...[if (i > 0) const SizedBox(width: 6), pills[i]]]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ExcludeSemantics(
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: NotificationTone.goFill, shape: BoxShape.circle, boxShadow: NotificationTone.goShadow),
              child: Icon(opens ? Icons.arrow_forward_rounded : Icons.check_rounded, size: 20, color: ink),
            ),
          ),
        ],
      ),
    );
    return _NotificationFrame(tone: tone, art: art, title: title, body: body, read: read, onTap: onTap, bottom: bottom);
  }
}

class NotificationBannerCard3D extends StatelessWidget {
  const NotificationBannerCard3D({super.key, required this.art, required this.title, required this.body, required this.actionLabel, required this.onAction});

  final String art;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.cF;
    final button = Tap3D(
      onTap: onAction,
      label: actionLabel,
      exclude: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: Ink3D.whiteBtn),
        child: Text(actionLabel, maxLines: 1, softWrap: false, style: Ink3D.text(14, FontWeight.w700, tone.button)),
      ),
    );
    return _NotificationFrame(
      tone: tone,
      art: art,
      title: title,
      body: body,
      titleLines: 2,
      bodyLines: 3,
      bottom: Align(alignment: Alignment.centerRight, child: FittedBox(fit: BoxFit.scaleDown, child: button)),
    );
  }
}

class NotificationCardSkeleton extends StatefulWidget {
  const NotificationCardSkeleton({super.key});

  @override
  State<NotificationCardSkeleton> createState() => _NotificationCardSkeletonState();
}

class _NotificationCardSkeletonState extends State<NotificationCardSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400), lowerBound: 0.55, upperBound: 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bar(double? w, double h) => FadeTransition(
        opacity: _c,
        child: Container(width: w, height: h, decoration: BoxDecoration(color: NotificationTone.skeletonBar, borderRadius: BorderRadius.circular(h / 2))),
      );

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final artSize = narrow ? 80.0 : 94.0;
    final textLeft = narrow ? 92.0 : 108.0;
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 34, 14, 0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 130,
              decoration: const BoxDecoration(
                borderRadius: _cardRadius,
                gradient: LinearGradient(colors: [NotificationTone.skeletonA, NotificationTone.skeletonB], begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: NotificationTone.skeletonShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(textLeft, 16, 14, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(widthFactor: 0.88, child: _bar(null, 12)),
                        const SizedBox(height: 12),
                        _bar(null, 12),
                        const SizedBox(height: 8),
                        FractionallySizedBox(widthFactor: 0.64, child: _bar(null, 12)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        _bar(64, 18),
                        const SizedBox(width: 32),
                        _bar(48, 18),
                        const Spacer(),
                        Container(width: 36, height: 36, decoration: const BoxDecoration(color: NotificationTone.skeletonGo, shape: BoxShape.circle)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 6,
              top: -28,
              child: FadeTransition(
                opacity: _c,
                child: Container(width: artSize, height: artSize, decoration: const BoxDecoration(color: NotificationTone.skeletonHalo, shape: BoxShape.circle)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationDaySkeleton extends StatelessWidget {
  const NotificationDaySkeleton({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(width: 64, height: 10, decoration: BoxDecoration(color: NotificationTone.skeletonB, borderRadius: BorderRadius.circular(5))),
        ),
      );
}

class NotificationMoreSpinner extends StatelessWidget {
  const NotificationMoreSpinner({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Center(
          child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3.5, color: ListingTone.indigo.g2, backgroundColor: ListingTone.indigo.g2.withValues(alpha: 0.28))),
        ),
      );
}
