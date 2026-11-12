import 'package:flutter/material.dart';
import '../design/design.dart';

class HomeCardSurface extends StatelessWidget {
  const HomeCardSurface({
    super.key,
    required this.child,
    this.onTap,
    this.shadow = ShadowTokens.elev2,
    this.radius = CardRadius.tile,
    this.color = DesignColors.surface,
  });

  final Widget child;
  final VoidCallback? onTap;
  final List<BoxShadow> shadow;
  final BorderRadius radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: radius, boxShadow: shadow),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: DesignColors.splash,
          highlightColor: Colors.transparent,
          child: child,
        ),
      ),
    );
    return onTap == null ? card : PressScale(child: card);
  }
}
