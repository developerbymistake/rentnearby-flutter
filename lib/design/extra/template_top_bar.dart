import 'package:flutter/material.dart';
import '../template/fitness_app_theme.dart';

import 'package:bakhli/design/tokens/shadow_tokens.dart';
import 'package:bakhli/design/tokens/design_scale.dart';
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
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(DS.radius(32.0))),
                boxShadow: DS.shadows(<BoxShadow>[
                  ShadowTokens.tint(FitnessAppTheme.grey, ShadowSpec.strong.scaled(opacity)),
                ]),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(height: MediaQuery.of(context).padding.top),
                  Padding(
                    padding: EdgeInsets.only(
                        left: DS.s(8), right: DS.s(16), top: DS.s(16 - 8.0 * opacity), bottom: DS.s(12 - 8.0 * opacity)),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: DS.s(38),
                          height: DS.s(38),
                          child: InkWell(
                            highlightColor: Colors.transparent,
                            borderRadius: BorderRadius.all(Radius.circular(DS.radius(32.0))),
                            onTap: onBack,
                            child: Center(
                              child: Icon(Icons.keyboard_arrow_left, color: FitnessAppTheme.grey, size: DS.s(28)),
                            ),
                          ),
                        ),
                        SizedBox(width: DS.s(4)),
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
                                  fontSize: DS.f(22 + 6 - 6 * opacity),
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
