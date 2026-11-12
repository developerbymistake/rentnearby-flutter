import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

class TripPageHeader extends StatelessWidget {
  const TripPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.trailing,
    this.bottom,
    this.bottomHeight = 0,
    this.gradient,
    this.tone = KitTone.trip,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Widget? trailing;
  final Widget? bottom;
  final double bottomHeight;
  final Gradient? gradient;
  final KitTone tone;

  @override
  Widget build(BuildContext context) => ModuleHeader(
        title: title,
        subtitle: subtitle,
        tone: tone,
        gradient: gradient,
        onBack: onBack,
        trailing: [?trailing],
        bottom: bottom,
        bottomHeight: bottom == null ? 0 : bottomHeight,
      );
}
