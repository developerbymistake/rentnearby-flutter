import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'buttons_kit.dart';
import 'motion_kit.dart';
import 'sheet_close_button.dart';
import 'wide_card.dart';
import 'package:bakhli/design/tokens/design_scale.dart';
import '../tokens/card_tokens.dart';

const double _kContentMax = 520;
BorderRadius get _kSheetTop => BorderRadius.vertical(top: Radius.circular(DS.radius(32)));
BorderRadius get _kWayRadius => DS.br(CardRadius.hero);

bool _narrow(BuildContext context) => MediaQuery.sizeOf(context).width < 340;
double _scale(BuildContext context) => MediaQuery.textScalerOf(context).scale(1);

Widget _halo(double size, Color color) => DecoratedBox(
  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  child: SizedBox(width: DS.s(size), height: DS.s(size)),
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
          padding: EdgeInsets.only(right: DS.s(70)),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: DS.s(20) * _scale(context)),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(label.toUpperCase(), style: Ink3D.text(13, FontWeight.w700, tone.g2, height: 1.4, letterSpacing: 0.3)),
            ),
          ),
        ),
        Container(
          height: DS.s(6),
          margin: EdgeInsets.only(top: DS.s(14)),
          decoration: BoxDecoration(color: Ink3D.line, borderRadius: DS.circular(4)),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0, 1).toDouble(),
            child: DecoratedBox(
              decoration: BoxDecoration(color: tone.g1, borderRadius: DS.circular(4)),
              child: SizedBox(height: DS.s(6), width: double.infinity),
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
  final Widget? header;

  static const Key circleKey = ValueKey('guide_circle');
  static const double circleLeft = 20;
  static const double circleSize = 88;
  static const double circleArt = 62;
  static const double circleOnHeader = 44;
  // Sheet top below the page top: the half of the circle that sits on the page plus 12.
  static const double sheetTop = circleSize - circleOnHeader + 12;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF2F3F8), Colors.white]),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Positioned(left: 0, right: 0, bottom: 0, top: DS.s(sheetTop), child: _sheet(context, pad.bottom)),
          Positioned(left: DS.s(circleLeft), top: DS.s(-circleOnHeader), child: _circle()),
        ],
      ),
    );
  }

  Widget _circle() {
    return ExcludeSemantics(
      child: Container(
        key: circleKey,
        width: DS.s(circleSize),
        height: DS.s(circleSize),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.33), offset: DS.shadowOffset(const Offset(0, 6)), blurRadius: DS.shadowBlur(16))],
        ),
        child: Art3D(asset: art, size: circleArt, shadowBlur: 5, shadowOffset: const Offset(4, 6), shadowAlpha: 0.25),
      ),
    );
  }

  Widget _sheet(BuildContext context, double inset) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _kSheetTop,
        boxShadow: [BoxShadow(color: Color(0x4D9E9E9E), offset: DS.shadowOffset(const Offset(0, -2)), blurRadius: DS.shadowBlur(16))],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: ClipRect(
                    child: PageStorage(
                      bucket: PageStorageBucket(),
                      child: SingleChildScrollView(
                        key: ValueKey(scrollKey ?? title),
                        padding: EdgeInsets.fromLTRB(DS.s(20), DS.s(14), DS.s(20), DS.s(16)),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: _kContentMax),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                header ?? GuideStepHeader(tone: tone, label: stepLabel, progress: progress),
                                Padding(
                                  padding: EdgeInsets.only(top: DS.s(4)),
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
                                    padding: EdgeInsets.only(top: DS.s(6)),
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
                const _ScrollFade(),
                if (bottom != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(DS.s(20), DS.s(4), DS.s(20), DS.s(22) + inset),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: _kContentMax),
                        child: bottom,
                      ),
                    ),
                  )
                else
                  SizedBox(height: DS.s(22) + inset),
              ],
            ),
          ),
          Positioned(
            right: DS.s(20),
            top: DS.s(-30),
            child: ExcludeSemantics(
              child: Container(
                width: DS.s(60),
                height: DS.s(60),
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: DS.s(6)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: tone.gradient,
                  boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.5), offset: DS.shadowOffset(const Offset(3, 8)), blurRadius: DS.shadowBlur(14))],
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
        minHeight: DS.s(16),
        maxHeight: DS.s(16),
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00FFFFFF), Colors.white]),
            ),
            child: SizedBox(height: DS.s(16), width: double.infinity),
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

  static double get topRoom => DS.s(26);
  static BorderRadius get radius => DS.br(CardRadius.card);

  @override
  Widget build(BuildContext context) {
    final small = _narrow(context);
    final artSize = small ? 64.0 : 84.0;
    final off = state == OptionState.off;
    final on = state == OptionState.on;
    final check = Container(
      width: DS.s(28),
      height: DS.s(28),
      decoration: BoxDecoration(shape: BoxShape.circle, color: on ? Colors.white : Colors.white.withValues(alpha: 0.35)),
      child: on ? Icon(Icons.check_rounded, size: DS.s(17), color: tone.g2) : null,
    );
    final card = Opacity(
      opacity: off ? 0.78 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(top: topRoom),
            child: DecoratedBox(
              decoration: BoxDecoration(borderRadius: radius, gradient: tone.gradient, boxShadow: off ? const [] : tone.glow(blur: 8)),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: DS.s(80), minWidth: double.infinity),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(DS.s(small ? 74 : 98), DS.s(16), DS.s(14), DS.s(16)),
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
                      SizedBox(width: DS.s(10)),
                      trailing ?? check,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: DS.s(6),
            top: topRoom - DS.s(small ? 26 : 32),
            child: IgnorePointer(child: _halo(artSize + 8, Colors.white.withValues(alpha: 0.22))),
          ),
          Positioned(
            left: DS.s(10),
            top: topRoom - DS.s(small ? 22 : 28),
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

  static BorderRadius get primaryRadius => DS.br(const BorderRadius.all(Radius.circular(18)));

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
              width: wide ? null : DS.s(52),
              constraints: BoxConstraints(minHeight: DS.s(52)),
              decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(16), boxShadow: DS.shadows(Ink3D.softShadow)),
              child: wide
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(squareIcon, size: DS.s(22), color: Ink3D.hint),
                        SizedBox(width: DS.s(8)),
                        Flexible(
                          child: Text(squareSemantics, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w600, Ink3D.hint)),
                        ),
                      ],
                    )
                  : Icon(squareIcon, size: DS.s(26), color: Ink3D.hint),
            ),
          ),
        ),
      ),
    );
    final primary = label == null
        ? SizedBox(height: DS.s(52))
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
                    constraints: BoxConstraints(minHeight: DS.s(52)),
                    padding: EdgeInsets.symmetric(horizontal: DS.s(14), vertical: DS.s(8)),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: primaryRadius,
                      gradient: tone.gradient,
                      boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.5), offset: DS.shadowOffset(const Offset(1.1, 6)), blurRadius: DS.shadowBlur(14))],
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
              if (wide) Expanded(child: square) else ...[square, Gap.h(14), Expanded(child: primary)],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: DS.s(12)),
          child: SizedBox(
            height: DS.s(18) * _scale(context),
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

  static double get artRoom => DS.s(78);
  static BorderRadius get primaryRadius => DS.br(const BorderRadius.all(Radius.circular(20)));

  Widget _button(String label, VoidCallback? onTap, Key? key, {required bool primary}) {
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(primary ? 22 : 12)),
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
              constraints: BoxConstraints(minHeight: DS.s(primary ? 54 : 50), minWidth: double.infinity),
              padding: EdgeInsets.symmetric(horizontal: DS.s(14), vertical: DS.s(8)),
              alignment: Alignment.center,
              decoration: primary
                  ? BoxDecoration(
                      borderRadius: primaryRadius,
                      gradient: tone.gradient,
                      boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.5), offset: DS.shadowOffset(const Offset(1.1, 6)), blurRadius: DS.shadowBlur(14))],
                    )
                  : BoxDecoration(color: Colors.white, borderRadius: DS.circular(18), boxShadow: DS.shadows(Ink3D.softShadow)),
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
    final maxSheet = math.max(DS.s(260), screen - pad.top - artRoom - DS.s(12));
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Ink3D.text(26, FontWeight.w700, Ink3D.title, height: 1.4)),
        if (body.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: DS.s(6)),
            child: Text(body, maxLines: 6, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Ink3D.text(15, FontWeight.w400, Ink3D.copy, height: 1.45, letterSpacing: 0)),
          ),
        if (names.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: DS.s(16)),
            child: Wrap(
              spacing: DS.gh(8),
              runSpacing: DS.gv(8),
              alignment: WrapAlignment.center,
              children: [
                for (final n in names)
                  Container(
                    padding: EdgeInsets.fromLTRB(DS.s(6), DS.s(5), DS.s(14), DS.s(5)),
                    decoration: BoxDecoration(color: tone.tint, borderRadius: DS.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(n.art, width: DS.s(28), height: DS.s(28), fit: BoxFit.contain),
                        SizedBox(width: DS.s(6)),
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
                padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(16), DS.s(16), DS.s(4)),
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
          padding: EdgeInsets.only(top: artRoom),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: math.min(DS.s(430) + pad.bottom, maxSheet), maxHeight: maxSheet),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: _kSheetTop,
              boxShadow: [BoxShadow(color: Color(0x33000000), offset: DS.shadowOffset(const Offset(0, -4)), blurRadius: DS.shadowBlur(24))],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(DS.s(22), DS.s(84), DS.s(22), DS.s(22) + pad.bottom),
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
        Positioned(top: artRoom + DS.s(12), right: DS.s(12), child: SheetCloseButton()),
        Positioned(top: 0, child: IgnorePointer(child: _halo(144, tone.haloBase.withValues(alpha: 0.18)))),
        Positioned(
          top: DS.s(4),
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

  static double get topRoom => DS.s(38);

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
        boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: 0.55), offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(10))],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(DS.s(22), DS.s(22), DS.s(22), DS.s(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(left: DS.s(small ? 90 : 114)),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: DS.s(small ? 50 : 60)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (best != null && best.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: DS.s(6)),
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: white, borderRadius: DS.circular(12)),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: DS.s(10), vertical: DS.s(3)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, size: DS.s(14), color: tone.g2),
                                SizedBox(width: DS.s(3)),
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
                        padding: EdgeInsets.only(top: DS.s(2)),
                        child: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: sub),
                      ),
                    if (reason != null && reason.isNotEmpty) Text(reason, maxLines: 2, overflow: TextOverflow.ellipsis, style: sub),
                  ],
                ),
              ),
            ),
            if (rows.isNotEmpty)
              Container(
                margin: EdgeInsets.only(top: DS.s(14)),
                padding: EdgeInsets.symmetric(horizontal: DS.s(16), vertical: DS.s(12)),
                decoration: BoxDecoration(color: white.withValues(alpha: 0.2), borderRadius: DS.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final r in rows) _row(r)]),
              ),
            if (buttons.isNotEmpty) Padding(padding: EdgeInsets.only(top: DS.s(14)), child: _grid(context)),
            if (note != null && note!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: DS.s(8)),
                child: Text(note!, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w400, white.withValues(alpha: 0.9), height: 1.4, letterSpacing: 0)),
              ),
          ],
        ),
      ),
    );
    final stack = Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: EdgeInsets.fromLTRB(DS.s(18), topRoom, DS.s(18), 0), child: card),
        Positioned(
          left: DS.s(18 + 10),
          top: topRoom - DS.s(small ? 26 : 34),
          child: IgnorePointer(child: _halo(artSize + 4, white.withValues(alpha: 0.24))),
        ),
        Positioned(
          left: DS.s(18 + (small ? 12 : 8)),
          top: topRoom - DS.s(small ? 30 : 40),
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
        padding: EdgeInsets.symmetric(vertical: DS.s(3)),
        child: Row(
          children: [
            Container(
              width: DS.s(14),
              height: DS.s(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: r.filled ? white : null,
                border: Border.all(color: white, width: DS.s(3)),
              ),
            ),
            SizedBox(width: DS.s(10)),
            Expanded(
              child: Wrap(
                spacing: DS.s(10),
                runSpacing: DS.s(2),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(r.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w700, white, height: 1.5)),
                  if (r.tag != null)
                    DecoratedBox(
                      decoration: BoxDecoration(color: white, borderRadius: DS.circular(10)),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: DS.s(9), vertical: DS.s(2)),
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
      constraints: BoxConstraints(minHeight: DS.s(34)),
      margin: EdgeInsets.fromLTRB(DS.s(24), DS.s(2), 0, DS.s(2)),
      padding: EdgeInsets.only(left: DS.s(10)),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: white.withValues(alpha: 0.6), width: DS.s(3))),
      ),
      alignment: Alignment.centerLeft,
      child: LayoutBuilder(builder: (context, box) {
        final scaler = MediaQuery.textScalerOf(context);
        final textStyle = Ink3D.text(14, FontWeight.w500, white, height: 1.4);
        final rightStyle = Ink3D.text(15, FontWeight.w700, white);
        final right = r.right;
        final rightW = right == null ? 0.0 : KitText.widthOf(right, rightStyle, scaler) + DS.s(8);
        var longest = 0.0;
        for (final w in r.text.split(RegExp(r'\s+'))) {
          final x = KitText.widthOf(w, textStyle, scaler);
          if (x > longest) longest = x;
        }
        final stack = right != null && box.maxWidth - rightW < (longest > DS.s(110) ? longest : DS.s(110)) * 1.15;
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
              padding: EdgeInsets.only(left: DS.s(8)),
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
          padding: EdgeInsets.symmetric(horizontal: DS.s(8)),
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: DS.circular(22), color: b.primary ? Colors.white : Colors.white.withValues(alpha: 0.24), boxShadow: b.primary ? DS.shadows(Ink3D.whiteBtn) : const []),
          child: b.busy
              ? SizedBox(width: DS.s(18), height: DS.s(18), child: CircularProgressIndicator(strokeWidth: DS.s(2), valueColor: AlwaysStoppedAnimation(ink)))
              : Padding(
                  padding: EdgeInsets.symmetric(vertical: DS.s(4)),
                  child: Text(b.label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Ink3D.text(13.5, FontWeight.w700, ink, height: 1.25)),
                ),
        ),
      ),
    );
  }

  // Two columns; a full button, or one left without a partner, takes the whole row.
  Widget _grid(BuildContext context) {
    final double h = DS.s(44) * math.max<double>(1, _scale(context));
    final out = <Widget>[];
    var i = 0;
    while (i < buttons.length) {
      if (out.isNotEmpty) out.add(Gap.v(10));
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
                Gap.h(10),
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
