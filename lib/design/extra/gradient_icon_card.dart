import 'package:bakhli/design/tokens/design_scale.dart';
import 'package:bakhli/design/template/fitness_app_theme.dart';
import 'package:bakhli/design/tokens/alpha_tokens.dart';
import 'package:bakhli/design/tokens/card_tokens.dart';
import 'motion_kit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:bakhli/design/tokens/shadow_tokens.dart';
class GradientIconCard extends StatelessWidget {
  const GradientIconCard({
    Key? key,
    required this.title,
    required this.iconAsset,
    required this.startColor,
    required this.endColor,
    this.subtitleLines = const <String>[],
    this.value,
    this.unit,
    this.onTap,
    this.showPlus = false,
    this.onPlusTap,
    this.width = 130,
    this.height = 216,
    this.imageUrl,
    this.caption,
    this.tag,
  }) : super(key: key);

  final String title;
  final List<String> subtitleLines;
  final String? value;
  final String? unit;
  final String iconAsset;
  final Color startColor;
  final Color endColor;
  final VoidCallback? onTap;
  final bool showPlus;
  final VoidCallback? onPlusTap;
  final double width;
  final double height;
  final String? imageUrl;
  final String? caption;
  final String? tag;

  BorderRadius get _radius => DS.br(CardRadius.hero);

  @override
  Widget build(BuildContext context) {
    final bool hasValue = value != null && value!.isNotEmpty;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15)),
      child: PressScale(
      child: SizedBox(
      width: DS.s(width),
      height: DS.s(height),
      child: Stack(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(DS.s(8), DS.s(32), DS.s(8), DS.s(16)),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: <BoxShadow>[
                  ...DS.shadows(ShadowTokens.glow(endColor)),
                ],
                gradient: LinearGradient(
                  colors: <Color>[startColor, endColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: _radius,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: _radius,
                  onTap: onTap,
                  child: Padding(
                    padding: DS.insets(l: 16, t: 46, r: 16, b: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: FitnessAppTheme.fontName,
                            fontWeight: FontWeight.bold,
                            fontSize: DS.f(16),
                            letterSpacing: 0.2,
                            color: FitnessAppTheme.white,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: DS.s(4)),
                            child: Text(
                              subtitleLines.join('\n'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: FitnessAppTheme.fontName,
                                fontWeight: FontWeight.w500,
                                fontSize: DS.f(11),
                                letterSpacing: 0.2,
                                color: FitnessAppTheme.white,
                              ),
                            ),
                          ),
                        ),
                        if (caption != null && caption!.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(bottom: DS.s(2)),
                            child: Text(
                              caption!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: FitnessAppTheme.fontName,
                                fontWeight: FontWeight.w700,
                                fontSize: DS.f(11),
                                letterSpacing: 0.6,
                                color: FitnessAppTheme.white,
                              ),
                            ),
                          ),
                        if (hasValue)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  value!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: FitnessAppTheme.fontName,
                                    fontWeight: FontWeight.w500,
                                    fontSize: DS.f(24),
                                    letterSpacing: 0.2,
                                    color: FitnessAppTheme.white,
                                  ),
                                ),
                              ),
                              if (unit != null)
                                Padding(
                                  padding: EdgeInsets.only(left: DS.s(4), bottom: DS.s(3)),
                                  child: Text(
                                    unit!,
                                    style: TextStyle(
                                      fontFamily: FitnessAppTheme.fontName,
                                      fontWeight: FontWeight.w500,
                                      fontSize: DS.f(11),
                                      letterSpacing: 0.2,
                                      color: FitnessAppTheme.white,
                                    ),
                                  ),
                                ),
                            ],
                          )
                        else if (showPlus)
                          GestureDetector(
                            onTap: onPlusTap ?? onTap,
                            child: Container(
                              decoration: BoxDecoration(
                                color: FitnessAppTheme.nearlyWhite,
                                shape: BoxShape.circle,
                                boxShadow: DS.shadows(<BoxShadow>[
                                  ShadowTokens.tint(FitnessAppTheme.nearlyBlack, ShadowSpec.elev3Spec),
                                ]),
                              ),
                              child: Padding(
                                padding: DS.all(6),
                                child: Icon(
                                  Icons.add,
                                  color: endColor,
                                  size: DS.s(24),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: DS.s(84),
              height: DS.s(84),
              decoration: BoxDecoration(
                color: FitnessAppTheme.nearlyWhite.withValues(alpha: Alpha.soft),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: DS.s(8),
            child: SizedBox(
              width: DS.s(80),
              height: DS.s(80),
              child: imageUrl == null
                  ? Image.asset(iconAsset)
                  : ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Image.asset(iconAsset),
                        errorWidget: (_, _, _) => Image.asset(iconAsset),
                      ),
                    ),
            ),
          ),
          if (tag != null && tag!.isNotEmpty)
            Positioned(
              top: DS.s(40),
              right: DS.s(16),
              child: Container(
                padding: DS.sym(h: 7, v: 1),
                decoration: BoxDecoration(
                  color: FitnessAppTheme.nearlyWhite.withValues(alpha: Alpha.soft),
                  borderRadius: DS.circular(999),
                ),
                child: Text(
                  tag!,
                  style: TextStyle(
                    fontFamily: FitnessAppTheme.fontName,
                    fontWeight: FontWeight.w700,
                    fontSize: DS.f(11),
                    letterSpacing: 0.5,
                    color: FitnessAppTheme.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    ));
  }
}
