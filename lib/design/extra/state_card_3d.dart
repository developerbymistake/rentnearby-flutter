import 'package:bakhli/design/tokens/design_scale.dart';
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

  static const BorderRadius wideRadius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(36), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));
  static const BorderRadius tallRadius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(36), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

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
        width: DS.s(122),
        constraints: BoxConstraints(minHeight: DS.s(41)),
        padding: DS.sym(h: 10, v: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: faint ? Colors.white.withValues(alpha: 0.26) : Colors.white,
          borderRadius: DS.circular(22),
          boxShadow: faint ? null : DS.shadows(const [BoxShadow(color: Color(0x33000000), offset: Offset(3, 5), blurRadius: 8)]),
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
    final left = DS.s(narrow ? 126.0 : 156.0);
    final stackAction = narrow || scale > 1.15;
    final slot = _hasAction || _hasSecondary || reserveAction;
    final buttons = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_hasAction) _smallPill(actionLabel!, onAction) else if (reserveAction) SizedBox(width: DS.s(122), height: DS.s(41)),
        if (_hasSecondary) Padding(padding: EdgeInsets.only(top: DS.gv(8)), child: _smallPill(secondaryLabel!, onSecondary, faint: true)),
      ],
    );
    final msg = Text(_msg, maxLines: 4, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w500, Colors.white.withValues(alpha: 0.96), height: 1.5));
    return Padding(
      padding: margin ?? DS.insets(l: 14, t: 60, r: 14, b: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(gradient: tone.gradient, borderRadius: DS.br(wideRadius), boxShadow: tone.glow()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: DS.s(narrow ? 84 : 110)),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(left, DS.s(24), DS.s(20), DS.s(6)),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: DS.s(44) * scale),
                      child: Semantics(
                        header: true,
                        child: Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(18, FontWeight.w700, Colors.white, height: 1.22)),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: DS.insets(l: 20, t: 6, r: 20, b: 18),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: DS.s(40)),
                    child: stackAction
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_msg.isNotEmpty) msg,
                              if (slot) Padding(padding: EdgeInsets.only(top: _msg.isEmpty ? 0 : DS.gv(12)), child: Align(alignment: Alignment.centerRight, child: buttons)),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: msg),
                              if (slot) ...[Gap.h(12), buttons],
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: DS.s(6),
            top: DS.s(narrow ? -40 : -52),
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
      constraints: BoxConstraints(minHeight: DS.s(minHeight ?? 0)),
      padding: DS.insets(l: 28, t: artIn ? 28 : artSize - 66, r: 28, b: 34),
      decoration: BoxDecoration(gradient: tone.gradient, borderRadius: DS.br(tallRadius), boxShadow: tone.glow()),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (artIn) ...[
            ExcludeSemantics(
              child: Art3D(asset: art, size: artSize, halo: artSize + 4, haloColor: const Color(0x38FFFFFF), haloDy: 2, shadowBlur: 8, shadowOffset: const Offset(6, 10), shadowAlpha: 0.28),
            ),
            SizedBox(height: DS.s(22)),
          ],
          Semantics(
            header: true,
            child: Text(title, textAlign: TextAlign.center, style: Ink3D.text(24, FontWeight.w700, Colors.white, height: 1.25)),
          ),
          SizedBox(height: DS.s(6)),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: DS.s(21)),
            child: Text(_msg, textAlign: TextAlign.center, style: Ink3D.text(14.5, FontWeight.w400, Colors.white.withValues(alpha: 0.94), height: 1.45)),
          ),
          if (inside) ...[SizedBox(height: DS.s(26)), WhitePillButton(tone: tone, label: actionLabel!, onTap: onAction, onGradient: true)],
          if (_hasSecondary && !actionBelow) ...[
            SizedBox(height: DS.s(12)),
            Tap3D(
              onTap: onSecondary,
              child: Padding(
                padding: DS.sym(h: 12, v: 8),
                child: Text(secondaryLabel!, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w700, Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
    return Padding(
      padding: margin ?? (artIn ? DS.insets(l: 18, t: 8, r: 18) : EdgeInsets.fromLTRB(DS.s(18), DS.s(_tallOverhang + 20), DS.s(18), 0)),
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
                top: DS.s(-_tallOverhang),
                child: ExcludeSemantics(
                  child: Art3D(asset: art, size: artSize, halo: artSize + 4, haloColor: const Color(0x38FFFFFF), haloDy: 2, shadowBlur: 8, shadowOffset: const Offset(6, 10), shadowAlpha: 0.28),
                ),
              ),
            ],
          ),
          if (actionBelow && _hasAction)
            Padding(
              padding: EdgeInsets.only(top: DS.gv(24)),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: DS.s(230)),
                child: GradientPillButton(tone: tone, label: actionLabel!, onTap: onAction, height: 52),
              ),
            ),
          if (actionBelow && _hasSecondary)
            Padding(
              padding: EdgeInsets.only(top: DS.gv(12)),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: DS.s(230)),
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
      padding: margin ?? DS.insets(l: 30, t: 26, r: 30, b: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Art3D(asset: art, size: 150, halo: 142, haloColor: tone.haloBase.withValues(alpha: 0.16), shadowBlur: 8, shadowOffset: const Offset(6, 10), shadowAlpha: 0.25),
          ),
          Gap.v(14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: both ? Ink3D.text(17, FontWeight.w700, Ink3D.title, height: 1.3) : Ink3D.text(15, FontWeight.w400, Ink3D.sub, height: 1.45),
          ),
          if (both) Padding(padding: EdgeInsets.only(top: DS.gv(6)), child: Text(_msg, textAlign: TextAlign.center, style: Ink3D.text(15, FontWeight.w400, Ink3D.sub, height: 1.45))),
          if (_hasAction)
            Padding(
              padding: EdgeInsets.only(top: DS.gv(16)),
              child: SizedBox(width: DS.s(200), child: GradientPillButton(tone: tone, label: actionLabel!, onTap: onAction, height: 52)),
            )
          else if (reserveAction)
            SizedBox(height: DS.s(68)),
          if (_hasSecondary)
            Padding(
              padding: EdgeInsets.only(top: DS.gv(12)),
              child: SizedBox(width: DS.s(200), child: WhitePillButton(tone: tone, label: secondaryLabel!, onTap: onSecondary, height: 52)),
            ),
        ],
      ),
    );
  }
}
