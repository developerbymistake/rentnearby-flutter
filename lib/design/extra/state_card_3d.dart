import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'pill_buttons_3d.dart';

enum StateLayout { wide, tall, plain }

class StateCard3D extends StatelessWidget {
  const StateCard3D({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.layout = StateLayout.wide,
    this.actionBelow = false,
    this.reserveAction = false,
    this.minHeight,
    this.margin,
    this.artInside = false,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final StateLayout layout;
  final bool actionBelow;
  final bool reserveAction;
  final double? minHeight;
  final EdgeInsets? margin;
  final bool artInside;

  static const BorderRadius wideRadius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(54), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));
  static const BorderRadius tallRadius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(68), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

  static const double _tallOverhang = 80;

  bool get _hasAction => actionLabel != null && onAction != null;
  bool get _hasSecondary => secondaryLabel != null && onSecondary != null;
  String get _msg => message ?? '';

  @override
  Widget build(BuildContext context) => switch (layout) {
    StateLayout.wide => _wide(context),
    StateLayout.tall => _tall(context),
    StateLayout.plain => _plain(context),
  };

  Widget _smallPill(String label, VoidCallback? onTap, {bool faint = false}) {
    return Tap3D(
      onTap: onTap,
      child: Container(
        width: 122,
        constraints: const BoxConstraints(minHeight: 41),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: faint ? Colors.white.withValues(alpha: 0.26) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: faint ? null : const [BoxShadow(color: Color(0x33000000), offset: Offset(3, 5), blurRadius: 8)],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1, softWrap: false, style: Ink3D.text(14, FontWeight.w700, faint ? Colors.white : tone.button)),
        ),
      ),
    );
  }

  Widget _wide(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final narrow = w < 340;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final artSize = narrow ? 112.0 : 144.0;
    final left = narrow ? 126.0 : 156.0;
    final stackAction = narrow || scale > 1.15;
    final slot = _hasAction || _hasSecondary || reserveAction;
    final buttons = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_hasAction) _smallPill(actionLabel!, onAction) else if (reserveAction) const SizedBox(width: 122, height: 41),
        if (_hasSecondary) Padding(padding: const EdgeInsets.only(top: 8), child: _smallPill(secondaryLabel!, onSecondary, faint: true)),
      ],
    );
    final msg = Text(_msg, maxLines: 4, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w500, Colors.white.withValues(alpha: 0.96), height: 1.5));
    return Padding(
      padding: margin ?? const EdgeInsets.fromLTRB(14, 60, 14, 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(gradient: tone.gradient, borderRadius: wideRadius, boxShadow: tone.glow()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: narrow ? 84 : 110),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(left, 24, 20, 6),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: 44 * scale),
                      child: Semantics(
                        header: true,
                        child: Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(18, FontWeight.w700, Colors.white, height: 1.22)),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40),
                    child: stackAction
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_msg.isNotEmpty) msg,
                              if (slot) Padding(padding: EdgeInsets.only(top: _msg.isEmpty ? 0 : 12), child: Align(alignment: Alignment.centerRight, child: buttons)),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: msg),
                              if (slot) ...[const SizedBox(width: 12), buttons],
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 6,
            top: narrow ? -40 : -52,
            child: ExcludeSemantics(
              child: Art3D(asset: art, size: artSize, halo: artSize + 4, haloColor: const Color(0x3DFAFAFA), haloDy: 4, shadowAlpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tall(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final artSize = narrow ? 150.0 : 186.0;
    final inside = _hasAction && !actionBelow;
    final artIn = artInside;
    final card = Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      padding: EdgeInsets.fromLTRB(28, artIn ? 28 : artSize - 66, 28, 34),
      decoration: BoxDecoration(gradient: tone.gradient, borderRadius: tallRadius, boxShadow: tone.glow()),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (artIn) ...[
            ExcludeSemantics(
              child: Art3D(asset: art, size: artSize, halo: artSize + 4, haloColor: const Color(0x38FFFFFF), haloDy: 2, shadowBlur: 8, shadowOffset: const Offset(6, 10), shadowAlpha: 0.28),
            ),
            const SizedBox(height: 22),
          ],
          Semantics(
            header: true,
            child: Text(title, textAlign: TextAlign.center, style: Ink3D.text(24, FontWeight.w700, Colors.white, height: 1.25)),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 21),
            child: Text(_msg, textAlign: TextAlign.center, style: Ink3D.text(14.5, FontWeight.w400, Colors.white.withValues(alpha: 0.94), height: 1.45)),
          ),
          if (inside) ...[const SizedBox(height: 26), WhitePillButton(tone: tone, label: actionLabel!, onTap: onAction, onGradient: true)],
          if (_hasSecondary && !actionBelow) ...[
            const SizedBox(height: 12),
            Tap3D(
              onTap: onSecondary,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Text(secondaryLabel!, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w700, Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
    return Padding(
      padding: margin ?? (artIn ? const EdgeInsets.fromLTRB(18, 8, 18, 0) : const EdgeInsets.fromLTRB(18, _tallOverhang + 20, 18, 0)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              card,
              if (!artIn)
              Positioned(
                top: -_tallOverhang,
                child: ExcludeSemantics(
                  child: Art3D(asset: art, size: artSize, halo: artSize + 4, haloColor: const Color(0x38FFFFFF), haloDy: 2, shadowBlur: 8, shadowOffset: const Offset(6, 10), shadowAlpha: 0.28),
                ),
              ),
            ],
          ),
          if (actionBelow && _hasAction)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 230),
                child: GradientPillButton(tone: tone, label: actionLabel!, onTap: onAction, height: 52),
              ),
            ),
          if (actionBelow && _hasSecondary)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 230),
                child: WhitePillButton(tone: tone, label: secondaryLabel!, onTap: onSecondary, height: 52),
              ),
            ),
        ],
      ),
    );
  }

  Widget _plain(BuildContext context) {
    final both = _msg.isNotEmpty;
    return Padding(
      padding: margin ?? const EdgeInsets.fromLTRB(30, 26, 30, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Art3D(asset: art, size: 150, halo: 142, haloColor: tone.haloBase.withValues(alpha: 0.16), shadowBlur: 8, shadowOffset: const Offset(6, 10), shadowAlpha: 0.25),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: both ? Ink3D.text(17, FontWeight.w700, Ink3D.title, height: 1.3) : Ink3D.text(15, FontWeight.w400, Ink3D.sub, height: 1.45),
          ),
          if (both) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_msg, textAlign: TextAlign.center, style: Ink3D.text(15, FontWeight.w400, Ink3D.sub, height: 1.45))),
          if (_hasAction)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(width: 200, child: GradientPillButton(tone: tone, label: actionLabel!, onTap: onAction, height: 52)),
            )
          else if (reserveAction)
            const SizedBox(height: 68),
          if (_hasSecondary)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(width: 200, child: WhitePillButton(tone: tone, label: secondaryLabel!, onTap: onSecondary, height: 52)),
            ),
        ],
      ),
    );
  }
}
