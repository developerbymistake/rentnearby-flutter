import 'package:bakhli/design/tokens/design_colors.dart';
import 'package:bakhli/design/tokens/alpha_tokens.dart';
import 'package:flutter/material.dart';
import 'card_kit.dart';
import 'kit_tone.dart';

class InfoRowCard extends StatelessWidget {
  const InfoRowCard({
    Key? key,
    required this.title,
    required this.iconAsset,
    required this.startColor,
    required this.endColor,
    this.subtitle,
    this.tag,
    this.value,
    this.unit,
    this.onTap,
  }) : super(key: key);

  final String title;
  final String? subtitle;
  final String? tag;
  final String? value;
  final String? unit;
  final String iconAsset;
  final Color startColor;
  final Color endColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = KitTone(
      accent: startColor,
      accentDark: endColor,
      tint: DesignColors.tint(endColor, Alpha.tint),
      gradient: LinearGradient(
        colors: <Color>[startColor, endColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glow: endColor,
    );
    return ListRow(
      title: title,
      subtitle: subtitle,
      tag: tag,
      priceValue: value,
      priceUnit: unit,
      iconAsset: iconAsset,
      tone: tone,
      onTap: onTap,
      margin: EdgeInsets.zero,
      leading: Container(
        width: ListRow.tileSize,
        height: ListRow.tileSize,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: tone.gradient,
          borderRadius: KitMetrics.tileSmall,
        ),
        child: Image.asset(iconAsset),
      ),
    );
  }
}
