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

  static const BorderRadius _radius = CardRadius.hero;

  @override
  Widget build(BuildContext context) {
    final bool hasValue = value != null && value!.isNotEmpty;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15)),
      child: PressScale(
      child: SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: <Widget>[
          Padding(
            padding:
                const EdgeInsets.only(top: 32, left: 8, right: 8, bottom: 16),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: <BoxShadow>[
                  ...ShadowTokens.glow(endColor),
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
                    padding: const EdgeInsets.only(
                        top: 46, left: 16, right: 16, bottom: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: FitnessAppTheme.fontName,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.2,
                            color: FitnessAppTheme.white,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 4),
                            child: Text(
                              subtitleLines.join('\n'),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: FitnessAppTheme.fontName,
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                                letterSpacing: 0.2,
                                color: FitnessAppTheme.white,
                              ),
                            ),
                          ),
                        ),
                        if (caption != null && caption!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              caption!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: FitnessAppTheme.fontName,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
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
                                  style: const TextStyle(
                                    fontFamily: FitnessAppTheme.fontName,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 24,
                                    letterSpacing: 0.2,
                                    color: FitnessAppTheme.white,
                                  ),
                                ),
                              ),
                              if (unit != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 4, bottom: 3),
                                  child: Text(
                                    unit!,
                                    style: const TextStyle(
                                      fontFamily: FitnessAppTheme.fontName,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 11,
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
                                boxShadow: <BoxShadow>[
                                  ShadowTokens.tint(FitnessAppTheme.nearlyBlack, ShadowSpec.elev3Spec),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Icon(
                                  Icons.add,
                                  color: endColor,
                                  size: 24,
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
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: FitnessAppTheme.nearlyWhite.withValues(alpha: Alpha.soft),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 8,
            child: SizedBox(
              width: 80,
              height: 80,
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
              top: 40,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: FitnessAppTheme.nearlyWhite.withValues(alpha: Alpha.soft),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tag!,
                  style: const TextStyle(
                    fontFamily: FitnessAppTheme.fontName,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
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
