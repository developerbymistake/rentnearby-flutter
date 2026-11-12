import '../tokens/alpha_tokens.dart';
import '../tokens/card_tokens.dart';
import 'package:bakhli/design/template/fitness_app_theme.dart';
import 'travel_palette.dart';
import 'package:bakhli/design/template/ui_view/mediterranean_diet_view.dart';
import 'package:flutter/material.dart';

import 'package:bakhli/design/tokens/shadow_tokens.dart';
class RingProgressCard extends StatelessWidget {
  const RingProgressCard({
    Key? key,
    required this.title,
    required this.value,
    required this.label,
    required this.progress,
    this.subtitle,
    this.onTap,
  }) : super(key: key);

  final String title;
  final String value;
  final String label;
  final double progress;
  final String? subtitle;
  final VoidCallback? onTap;

  static const BorderRadius _radius = CardRadius.hero;

  @override
  Widget build(BuildContext context) {
    final double p = progress.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 18),
      child: Container(
        decoration: BoxDecoration(
          color: FitnessAppTheme.white,
          borderRadius: _radius,
          boxShadow: <BoxShadow>[
            ShadowTokens.tint(FitnessAppTheme.grey, ShadowSpec.soft),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: _radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: FitnessAppTheme.fontName,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            letterSpacing: -0.1,
                            color: FitnessAppTheme.grey,
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              subtitle!,
                              style: TextStyle(
                                fontFamily: FitnessAppTheme.fontName,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                color: FitnessAppTheme.grey.withValues(alpha: Alpha.half),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: FitnessAppTheme.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: 4,
                            color: FitnessAppTheme.nearlyDarkBlue
                                .withValues(alpha: Alpha.soft),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              value,
                              style: const TextStyle(
                                fontFamily: FitnessAppTheme.fontName,
                                fontWeight: FontWeight.normal,
                                fontSize: 24,
                                letterSpacing: 0.0,
                                color: FitnessAppTheme.nearlyDarkBlue,
                              ),
                            ),
                            Text(
                              label,
                              style: TextStyle(
                                fontFamily: FitnessAppTheme.fontName,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.0,
                                color: FitnessAppTheme.grey.withValues(alpha: Alpha.half),
                              ),
                            ),
                          ],
                        ),
                      ),
                      CustomPaint(
                        painter: CurvePainter(
                          colors: const <Color>[
                            FitnessAppTheme.nearlyDarkBlue,
                            TravelPalette.ringLight,
                            TravelPalette.ringLight,
                          ],
                          angle: 5 + 360 * p,
                        ),
                        child: const SizedBox(width: 108, height: 108),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
