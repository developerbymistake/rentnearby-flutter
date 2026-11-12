import 'package:flutter/material.dart';
import '../template/fitness_app_theme.dart';

import 'package:bakhli/design/tokens/shadow_tokens.dart';
class TemplateTopBar extends StatelessWidget {
  const TemplateTopBar({
    super.key,
    required this.title,
    required this.opacity,
    required this.onBack,
    required this.animation,
    required this.animationController,
    this.subtitle,
    this.trailing,
    this.gradient,
  });

  final Gradient? gradient;

  static double opacityFor(double offset, {double threshold = 24}) =>
      offset <= 0 ? 0.0 : (offset >= threshold ? 1.0 : offset / threshold);

  final String title;
  final double opacity;
  final VoidCallback onBack;
  final Animation<double> animation;
  final AnimationController animationController;
  final Widget? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (BuildContext context, Widget? child) {
        return FadeTransition(
          opacity: animation,
          child: Transform(
            transform: Matrix4.translationValues(0.0, 30 * (1.0 - animation.value), 0.0),
            child: Container(
              decoration: BoxDecoration(
                color: gradient == null ? FitnessAppTheme.white.withValues(alpha: opacity) : null,
                gradient: gradient,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32.0)),
                boxShadow: <BoxShadow>[
                  ShadowTokens.tint(FitnessAppTheme.grey, ShadowSpec.strong.scaled(opacity)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(height: MediaQuery.of(context).padding.top),
                  Padding(
                    padding: EdgeInsets.only(
                        left: 8, right: 16, top: 16 - 8.0 * opacity, bottom: 12 - 8.0 * opacity),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 38,
                          height: 38,
                          child: InkWell(
                            highlightColor: Colors.transparent,
                            borderRadius: const BorderRadius.all(Radius.circular(32.0)),
                            onTap: onBack,
                            child: const Center(
                              child: Icon(Icons.keyboard_arrow_left, color: FitnessAppTheme.grey, size: 28),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: FitnessAppTheme.fontName,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 22 + 6 - 6 * opacity,
                                  letterSpacing: 1.2,
                                  color: FitnessAppTheme.darkerText,
                                ),
                              ),
                              if (subtitle != null) subtitle!,
                            ],
                          ),
                        ),
                        if (trailing != null) trailing!,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
