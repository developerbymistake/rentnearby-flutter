import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'buttons_kit.dart';
import 'motion_kit.dart';
import 'wide_card.dart';

const double _kContentMax = 520;
const BorderRadius _kSheetTop = BorderRadius.vertical(top: Radius.circular(32));
const BorderRadius _kWayRadius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(54), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

bool _narrow(BuildContext context) => MediaQuery.sizeOf(context).width < 340;
double _scale(BuildContext context) => MediaQuery.textScalerOf(context).scale(1);

Widget _halo(double size, Color color) => DecoratedBox(
  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  child: SizedBox(width: size, height: size),
);

class GuideStepHeader extends StatelessWidget {
  const GuideStepHeader({super.key, required this.tone, this.label = '', this.progress = 0});

  final ListingTone tone;
  final String label;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 70),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 20 * _scale(context)),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(label.toUpperCase(), style: Ink3D.text(13, FontWeight.w700, tone.g2, height: 1.4, letterSpacing: 0.3)),
            ),
          ),
        ),
        Container(
          height: 6,
          margin: const EdgeInsets.only(top: 14),
          decoration: BoxDecoration(color: Ink3D.line, borderRadius: BorderRadius.circular(4)),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0, 1).toDouble(),
            child: DecoratedBox(
              decoration: BoxDecoration(color: tone.g1, borderRadius: BorderRadius.circular(4)),
              child: const SizedBox(height: 6, width: double.infinity),
            ),
          ),
        ),
      ],
    );
  }
}

class GuideSheetScaffold extends StatelessWidget {
  const GuideSheetScaffold({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    this.stepLabel = '',
    this.body = '',
    this.progress = 0,
    this.ringLabel,
    this.children = const [],
    this.bottom,
    this.sheetHeight = 640,
    this.header,
    this.centerText = false,
    this.scrollKey,
  });

  final bool centerText;
  // A new value opens the content scrolled to the top.
  final Object? scrollKey;
  final ListingTone tone;
  final String art;
  final String title;
  final String stepLabel;
  final String body;
  final double progress;
  final String? ringLabel;
  final List<Widget> children;
  final Widget? bottom;
  final double sheetHeight;
  final Widget? header;

  static const double minTop = 150;
  static const double overlap = 14;

  // Depends only on the space, never on the content, so every step has the same sheet.
  static double sheetHeightFor(double available, {double topInset = 0, double bottomInset = 0, double max = 640}) {
    final room = available - topInset;
    final h = math.min(max + bottomInset, room - minTop + overlap);
    return math.max(h, math.min(room, 320 + bottomInset));
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF2F3F8), Colors.white]),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final avail = c.maxHeight.isFinite ? c.maxHeight : MediaQuery.sizeOf(context).height;
          final h = sheetHeightFor(avail, topInset: pad.top, bottomInset: pad.bottom, max: sheetHeight);
          final zone = math.max(0.0, avail - pad.top - h + overlap);
          final artSize = (zone - 20).clamp(0.0, 160.0).toDouble();
          return SizedBox(
            height: avail,
            child: Stack(
              children: [
                if (artSize >= 56)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: pad.top,
                    height: zone,
                    child: ExcludeSemantics(
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          _halo(artSize * 1.15, tone.haloBase.withValues(alpha: 0.14)),
                          Art3D(asset: art, size: artSize, shadowBlur: 10, shadowOffset: const Offset(8, 12), shadowAlpha: 0.22),
                        ],
                      ),
                    ),
                  ),
                Positioned(left: 0, right: 0, bottom: 0, height: h, child: _sheet(context, pad.bottom)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sheet(BuildContext context, double inset) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: _kSheetTop,
        boxShadow: [BoxShadow(color: Color(0x4D9E9E9E), offset: Offset(0, -2), blurRadius: 16)],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: ClipRect(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: PageStorage(
                        bucket: PageStorageBucket(),
                        child: SingleChildScrollView(
                          key: ValueKey(scrollKey ?? title),
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: _kContentMax),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  header ?? GuideStepHeader(tone: tone, label: stepLabel, progress: progress),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      title,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: centerText ? TextAlign.center : TextAlign.start,
                                      style: Ink3D.text(26, FontWeight.w700, Ink3D.title, height: 1.4, letterSpacing: 0.27),
                                    ),
                                  ),
                                  if (body.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        body,
                                        maxLines: 5,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: centerText ? TextAlign.center : TextAlign.start,
                                        style: Ink3D.text(15, FontWeight.w400, Ink3D.copy, height: 1.45, letterSpacing: 0),
                                      ),
                                    ),
                                  ...children,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const _ScrollFade(),
                if (bottom != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 22 + inset),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: _kContentMax),
                        child: bottom,
                      ),
                    ),
                  )
                else
                  SizedBox(height: 22 + inset),
              ],
            ),
          ),
          Positioned(
            right: 20,
            top: -30,
            child: ExcludeSemantics(
              child: Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: tone.gradient,
                  boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.5), offset: const Offset(3, 8), blurRadius: 14)],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    ringLabel ?? '${(progress.clamp(0, 1) * 100).round()}%',
                    maxLines: 1,
                    textScaler: TextScaler.noScaling,
                    style: Ink3D.text(15, FontWeight.w700, Colors.white, letterSpacing: 0),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Soft edge where the scrolling content meets the pinned buttons.
class _ScrollFade extends StatelessWidget {
  const _ScrollFade();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 0,
      child: OverflowBox(
        alignment: Alignment.bottomCenter,
        minHeight: 16,
        maxHeight: 16,
        child: const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00FFFFFF), Colors.white]),
            ),
            child: SizedBox(height: 16, width: double.infinity),
          ),
        ),
      ),
    );
  }
}

enum OptionState { idle, on, off }

class OptionCard extends StatelessWidget {
  const OptionCard({super.key, required this.tone, required this.art, required this.label, this.state = OptionState.idle, this.onTap, this.trailing});

  final ListingTone tone;
  final String art;
  final String label;
  final OptionState state;
  final VoidCallback? onTap;
  final Widget? trailing;

  static const double topRoom = 26;
  static const BorderRadius radius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(40), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    final small = _narrow(context);
    final artSize = small ? 64.0 : 84.0;
    final off = state == OptionState.off;
    final on = state == OptionState.on;
    final check = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(shape: BoxShape.circle, color: on ? Colors.white : Colors.white.withValues(alpha: 0.35)),
      child: on ? Icon(Icons.check_rounded, size: 17, color: tone.g2) : null,
    );
    final card = Opacity(
      opacity: off ? 0.78 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: topRoom),
            child: DecoratedBox(
              decoration: BoxDecoration(borderRadius: radius, gradient: tone.gradient, boxShadow: off ? const [] : tone.glow(blur: 8)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 80, minWidth: double.infinity),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(small ? 74 : 98, 16, 14, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.1),
                          style: Ink3D.text(small ? 15 : 17, FontWeight.w700, Colors.white, height: 1.4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      trailing ?? check,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 6,
            top: topRoom - (small ? 26 : 32),
            child: IgnorePointer(child: _halo(artSize + 8, Colors.white.withValues(alpha: 0.22))),
          ),
          Positioned(
            left: 10,
            top: topRoom - (small ? 22 : 28),
            child: IgnorePointer(
              child: Art3D(asset: art, size: artSize, shadowBlur: 5, shadowOffset: const Offset(4, 6), shadowAlpha: 0.25),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return PressScale(
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: card),
    );
  }
}

class GuideButtons extends StatelessWidget {
  const GuideButtons({
    super.key,
    required this.primaryLabel,
    this.onPrimary,
    this.loading = false,
    this.enabled = true,
    this.onSquare,
    this.squareIcon = Icons.close_rounded,
    this.squareSemantics = 'Previous',
    this.why = '',
    required this.tone,
  });

  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool loading;
  final bool enabled;
  final VoidCallback? onSquare;
  final IconData squareIcon;
  final String squareSemantics;
  final String why;
  final ListingTone tone;

  static const BorderRadius primaryRadius = BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18), bottomLeft: Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    final label = primaryLabel;
    final live = enabled && !loading && onPrimary != null;
    final wide = label == null;
    final square = Tooltip(
      message: squareSemantics,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: onSquare != null,
        label: squareSemantics,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSquare,
          child: Opacity(
            opacity: onSquare == null ? 0.45 : 1,
            child: Container(
              width: wide ? null : 52,
              constraints: const BoxConstraints(minHeight: 52),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Ink3D.softShadow),
              child: wide
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(squareIcon, size: 22, color: Ink3D.hint),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(squareSemantics, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w600, Ink3D.hint)),
                        ),
                      ],
                    )
                  : Icon(squareIcon, size: 26, color: Ink3D.hint),
            ),
          ),
        ),
      ),
    );
    final primary = label == null
        ? const SizedBox(height: 52)
        : Semantics(
            button: true,
            enabled: live,
            label: label,
            excludeSemantics: true,
            child: PressScale(
              enabled: live,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: live ? onPrimary : null,
                child: Opacity(
                  opacity: enabled ? 1 : 0.5,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: primaryRadius,
                      gradient: tone.gradient,
                      boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.5), offset: const Offset(1.1, 6), blurRadius: 14)],
                    ),
                    child: loading ? const KitDots(color: Colors.white) : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, Colors.white)),
                  ),
                ),
              ),
            ),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide) Expanded(child: square) else ...[square, const SizedBox(width: 14), Expanded(child: primary)],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SizedBox(
            height: 18 * _scale(context),
            child: why.isEmpty
                ? null
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(why, maxLines: 1, textAlign: TextAlign.center, style: Ink3D.text(12, FontWeight.w400, Ink3D.hint, letterSpacing: 0)),
                  ),
          ),
        ),
      ],
    );
  }
}

class SheetNameChip {
  const SheetNameChip({required this.art, required this.label});

  final String art;
  final String label;
}

// The white sheet alone (with its 78 art room on top), for use inside an existing sheet route.
class SheetModalBody extends StatelessWidget {
  const SheetModalBody({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    this.body = '',
    this.names = const [],
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.linkLabel,
    this.onLink,
    this.primaryKey,
    this.secondaryKey,
    this.extra,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String body;
  final List<SheetNameChip> names;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? linkLabel;
  final VoidCallback? onLink;
  final Key? primaryKey;
  final Key? secondaryKey;
  final Widget? extra;

  static const double artRoom = 78;
  static const BorderRadius primaryRadius = BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20), bottomRight: Radius.circular(20), bottomLeft: Radius.circular(8));

  Widget _button(String label, VoidCallback? onTap, Key? key, {required bool primary}) {
    return Padding(
      padding: EdgeInsets.only(top: primary ? 22 : 12),
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        excludeSemantics: true,
        child: PressScale(
          enabled: onTap != null,
          child: GestureDetector(
            key: key,
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              constraints: BoxConstraints(minHeight: primary ? 54 : 50, minWidth: double.infinity),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              alignment: Alignment.center,
              decoration: primary
                  ? BoxDecoration(
                      borderRadius: primaryRadius,
                      gradient: tone.gradient,
                      boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.5), offset: const Offset(1.1, 6), blurRadius: 14)],
                    )
                  : BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: Ink3D.softShadow),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(primary ? 17 : 16, FontWeight.w700, primary ? Colors.white : tone.text)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final screen = MediaQuery.sizeOf(context).height;
    final maxSheet = math.max(260.0, screen - pad.top - artRoom - 12);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Ink3D.text(26, FontWeight.w700, Ink3D.title, height: 1.4)),
        if (body.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(body, maxLines: 6, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Ink3D.text(15, FontWeight.w400, Ink3D.copy, height: 1.45, letterSpacing: 0)),
          ),
        if (names.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final n in names)
                  Container(
                    padding: const EdgeInsets.fromLTRB(6, 5, 14, 5),
                    decoration: BoxDecoration(color: tone.tint, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(n.art, width: 28, height: 28, fit: BoxFit.contain),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(n.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, tone.text)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ?extra,
        if (primaryLabel != null) _button(primaryLabel!, onPrimary, primaryKey, primary: true),
        if (secondaryLabel != null) _button(secondaryLabel!, onSecondary, secondaryKey, primary: false),
        if (linkLabel != null)
          Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onLink,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(linkLabel!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, Ink3D.grey)),
              ),
            ),
          ),
      ],
    );
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: artRoom),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: math.min(430.0 + pad.bottom, maxSheet), maxHeight: maxSheet),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: _kSheetTop,
              boxShadow: [BoxShadow(color: Color(0x33000000), offset: Offset(0, -4), blurRadius: 24)],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(22, 84, 22, 22 + pad.bottom),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _kContentMax),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(top: 0, child: IgnorePointer(child: _halo(144, tone.haloBase.withValues(alpha: 0.18)))),
        Positioned(
          top: 4,
          child: IgnorePointer(
            child: Art3D(asset: art, size: 136, shadowBlur: 7, shadowOffset: const Offset(5, 9), shadowAlpha: 0.3),
          ),
        ),
      ],
    );
  }
}

class SheetModal extends StatelessWidget {
  const SheetModal({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    this.body = '',
    this.names = const [],
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.linkLabel,
    this.onLink,
    this.onDismiss,
    this.primaryKey,
    this.secondaryKey,
    this.extra,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String body;
  final List<SheetNameChip> names;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? linkLabel;
  final VoidCallback? onLink;
  final VoidCallback? onDismiss;
  final Key? primaryKey;
  final Key? secondaryKey;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final inPopup = ModalRoute.of(context) is PopupRoute;
    final dismiss = onDismiss ?? (inPopup ? () => Navigator.of(context).maybePop() : null);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: dismiss,
            child: const ColoredBox(color: Ink3D.dim),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SheetModalBody(
            tone: tone,
            art: art,
            title: title,
            body: body,
            names: names,
            primaryLabel: primaryLabel,
            onPrimary: onPrimary,
            secondaryLabel: secondaryLabel,
            onSecondary: onSecondary,
            linkLabel: linkLabel,
            onLink: onLink,
            primaryKey: primaryKey,
            secondaryKey: secondaryKey,
            extra: extra,
          ),
        ),
      ],
    );
  }

  // Resolves with the value given to Navigator.pop, null when dismissed.
  static Future<T?> show<T>(BuildContext context, {required WidgetBuilder builder}) => showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (c, _, _) => builder(c),
    transitionBuilder: (c, a, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
      child: child,
    ),
  );
}

enum WayRowKind { stop, drive }

class WayRow {
  const WayRow.stop(this.text, {this.tag, this.filled = true}) : kind = WayRowKind.stop, right = null, note = null;
  const WayRow.drive(this.text, {this.right, this.note}) : kind = WayRowKind.drive, tag = null, filled = false;

  final WayRowKind kind;
  final String text;
  final String? tag;
  final String? right;
  final String? note;
  final bool filled;
}

class WayButton {
  const WayButton({required this.label, this.onTap, this.primary = false, this.full = false, this.busy = false, this.itemKey});

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool full;
  final bool busy;
  final Key? itemKey;
}

class WayCard extends StatelessWidget {
  const WayCard({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    this.subtitle = '',
    this.bestLabel,
    this.bestReason,
    this.rows = const [],
    this.buttons = const [],
    this.note,
    this.onTap,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String subtitle;
  final String? bestLabel;
  final String? bestReason;
  final List<WayRow> rows;
  final List<WayButton> buttons;
  final String? note;
  final VoidCallback? onTap;

  static const double topRoom = 38;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final small = _narrow(context);
    final artSize = small ? 96.0 : 116.0;
    final sub = Ink3D.text(13, FontWeight.w400, white.withValues(alpha: 0.92), height: 1.45);
    final best = bestLabel;
    final reason = bestReason;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _kWayRadius,
        gradient: tone.gradient,
        boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.55), offset: const Offset(1.1, 4), blurRadius: 10)],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(left: small ? 90 : 114),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: small ? 50 : 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (best != null && best.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: white, borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, size: 14, color: tone.g2),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(best, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w700, tone.g2, letterSpacing: 0.4)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(20, FontWeight.w700, white, height: 1.3)),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: sub),
                      ),
                    if (reason != null && reason.isNotEmpty) Text(reason, maxLines: 2, overflow: TextOverflow.ellipsis, style: sub),
                  ],
                ),
              ),
            ),
            if (rows.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final r in rows) _row(r)]),
              ),
            if (buttons.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 14), child: _grid(context)),
            if (note != null && note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(note!, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w400, white.withValues(alpha: 0.9), height: 1.4, letterSpacing: 0)),
              ),
          ],
        ),
      ),
    );
    final stack = Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(18, topRoom, 18, 0), child: card),
        Positioned(
          left: 18 + 10,
          top: topRoom - (small ? 26 : 34),
          child: IgnorePointer(child: _halo(artSize + 4, white.withValues(alpha: 0.24))),
        ),
        Positioned(
          left: 18 + (small ? 12 : 8),
          top: topRoom - (small ? 30 : 40),
          child: IgnorePointer(
            child: Art3D(asset: art, size: artSize),
          ),
        ),
      ],
    );
    if (onTap == null) return stack;
    return PressScale(
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: stack),
    );
  }

  Widget _row(WayRow r) {
    const white = Colors.white;
    if (r.kind == WayRowKind.stop) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: r.filled ? white : null,
                border: Border.all(color: white, width: 3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(r.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w700, white, height: 1.5)),
                  if (r.tag != null)
                    DecoratedBox(
                      decoration: BoxDecoration(color: white, borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                        child: Text(r.tag!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w700, tone.g2)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final note = r.note;
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      margin: const EdgeInsets.fromLTRB(24, 2, 0, 2),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: white.withValues(alpha: 0.6), width: 3)),
      ),
      alignment: Alignment.centerLeft,
      child: LayoutBuilder(builder: (context, box) {
        final scaler = MediaQuery.textScalerOf(context);
        final textStyle = Ink3D.text(14, FontWeight.w500, white, height: 1.4);
        final rightStyle = Ink3D.text(15, FontWeight.w700, white);
        final right = r.right;
        final rightW = right == null ? 0.0 : KitText.widthOf(right, rightStyle, scaler) + 8;
        var longest = 0.0;
        for (final w in r.text.split(RegExp(r'\s+'))) {
          final x = KitText.widthOf(w, textStyle, scaler);
          if (x > longest) longest = x;
        }
        final stack = right != null && box.maxWidth - rightW < (longest > 110 ? longest : 110) * 1.15;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(r.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: textStyle),
            if (note != null && note.isNotEmpty)
              Text(note, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w400, white.withValues(alpha: 0.9), height: 1.4, letterSpacing: 0)),
            if (stack) Text(right, maxLines: 1, overflow: TextOverflow.ellipsis, style: rightStyle),
          ],
        );
        if (right == null || stack) return text;
        return Row(
          children: [
            Expanded(child: text),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(right, maxLines: 1, softWrap: false, style: rightStyle),
            ),
          ],
        );
      }),
    );
  }

  Widget _btn(WayButton b, double minHeight) {
    final ink = b.primary ? tone.g2 : Colors.white;
    return Semantics(
      button: true,
      enabled: b.onTap != null && !b.busy,
      label: b.label,
      excludeSemantics: true,
      child: GestureDetector(
        key: b.itemKey,
        behavior: HitTestBehavior.opaque,
        onTap: b.busy ? null : b.onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: b.primary ? Colors.white : Colors.white.withValues(alpha: 0.24), boxShadow: b.primary ? Ink3D.whiteBtn : const []),
          child: b.busy
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(ink)))
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(b.label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Ink3D.text(13.5, FontWeight.w700, ink, height: 1.25)),
                ),
        ),
      ),
    );
  }

  // Two columns; a full button, or one left without a partner, takes the whole row.
  Widget _grid(BuildContext context) {
    final double h = 44.0 * math.max<double>(1, _scale(context));
    final out = <Widget>[];
    var i = 0;
    while (i < buttons.length) {
      if (out.isNotEmpty) out.add(const SizedBox(height: 10));
      final b = buttons[i];
      if (b.full || i + 1 >= buttons.length || buttons[i + 1].full) {
        out.add(_btn(b, h));
        i += 1;
      } else {
        out.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _btn(b, h)),
                const SizedBox(width: 10),
                Expanded(child: _btn(buttons[i + 1], h)),
              ],
            ),
          ),
        );
        i += 2;
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: out);
  }
}
