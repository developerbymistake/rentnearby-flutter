import 'package:bakhli/design/tokens/design_scale.dart';
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

  BorderRadius get _radius => DS.br(CardRadius.hero);

  @override
  Widget build(BuildContext context) {
    final double p = progress.clamp(0.0, 1.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(24), DS.gv(16), DS.s(24), DS.gv(18)),
      child: Container(
        decoration: BoxDecoration(
          color: FitnessAppTheme.white,
          borderRadius: _radius,
          boxShadow: <BoxShadow>[
            DS.shadows([ShadowTokens.tint(FitnessAppTheme.grey, ShadowSpec.soft)]).first,
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: _radius,
            onTap: onTap,
            child: Padding(
              padding: DS.all(24),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: FitnessAppTheme.fontName,
                            fontWeight: FontWeight.w500,
                            fontSize: DS.f(16),
                            letterSpacing: -0.1,
                            color: FitnessAppTheme.grey,
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: EdgeInsets.only(top: DS.s(6)),
                            child: Text(
                              subtitle!,
                              style: TextStyle(
                                fontFamily: FitnessAppTheme.fontName,
                                fontWeight: FontWeight.w500,
                                fontSize: DS.f(12),
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
                        width: DS.s(100),
                        height: DS.s(100),
                        decoration: BoxDecoration(
                          color: FitnessAppTheme.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: DS.s(4),
                            color: FitnessAppTheme.nearlyDarkBlue
                                .withValues(alpha: Alpha.soft),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              value,
                              style: TextStyle(
                                fontFamily: FitnessAppTheme.fontName,
                                fontWeight: FontWeight.normal,
                                fontSize: DS.f(24),
                                letterSpacing: 0.0,
                                color: FitnessAppTheme.nearlyDarkBlue,
                              ),
                            ),
                            Text(
                              label,
                              style: TextStyle(
                                fontFamily: FitnessAppTheme.fontName,
                                fontWeight: FontWeight.bold,
                                fontSize: DS.f(12),
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
                        child: SizedBox(width: DS.s(108), height: DS.s(108)),
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
