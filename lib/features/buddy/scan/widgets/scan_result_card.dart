import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';

class ScanResultCard extends StatelessWidget {
  const ScanResultCard({
    super.key,
    required this.art,
    required this.title,
    required this.body,
    required this.typeLabel,
    required this.actionLabel,
    required this.onType,
    required this.onAction,
  });

  final String art;
  final String title;
  final String body;
  final String typeLabel;
  final String actionLabel;
  final VoidCallback onType;
  final VoidCallback onAction;

  static BorderRadius get _radius => DS.br(CardRadius.hero);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: DS.insets(l: 22, t: 50, r: 22, b: 22),
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: _radius,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: Alpha.scrim), offset: DS.shadowOffset(const Offset(0, -4)), blurRadius: DS.shadowBlur(24))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(title, textAlign: TextAlign.center, style: Ink3D.text(20, FontWeight.w700, Ink3D.title, height: 1.3, letterSpacing: 0)),
              ),
              Gap.v(8),
              Text(body, textAlign: TextAlign.center, style: Ink3D.text(13.5, FontWeight.w400, Ink3D.sub, height: 1.5, letterSpacing: 0)),
              Gap.v(20),
              Row(
                children: [
                  Expanded(child: ScanButton(label: typeLabel, onTap: onType)),
                  Gap.h(12),
                  Expanded(child: ScanButton(label: actionLabel, onTap: onAction, teal: true)),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: DS.s(-42),
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Center(child: Art3D(asset: art, size: 80, shadowBlur: 6, shadowOffset: const Offset(5, 8), shadowAlpha: Alpha.v30)),
            ),
          ),
        ),
      ],
    );
  }
}

class ScanButton extends StatelessWidget {
  const ScanButton({super.key, required this.label, required this.onTap, this.teal = false, this.shadow = false});

  final String label;
  final VoidCallback onTap;
  final bool teal;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Tap3D(
      onTap: onTap,
      label: label,
      exclude: true,
      child: Container(
        height: DS.s(50),
        alignment: Alignment.center,
        padding: DS.sym(h: 8),
        decoration: BoxDecoration(
          color: teal ? null : DesignColors.surface,
          gradient: teal ? BuddyLook.teal.gradient : null,
          borderRadius: DS.circular(25),
          boxShadow: shadow ? [BoxShadow(color: Colors.black.withValues(alpha: Alpha.v40), offset: DS.shadowOffset(const Offset(3, 5)), blurRadius: DS.shadowBlur(9))] : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1, softWrap: false, style: Ink3D.text(15, FontWeight.w700, teal ? DesignColors.onPrimary : BuddyLook.indigoText, letterSpacing: 0)),
        ),
      ),
    );
  }
}
