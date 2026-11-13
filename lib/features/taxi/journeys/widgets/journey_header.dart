import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';

class JourneyHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> chips;
  final Widget? bottom;

  const JourneyHeader({super.key, required this.title, this.subtitle, this.chips = const [], this.bottom});

  @override
  Widget build(BuildContext context) {
    return JourneyHeader3D(
      title: title,
      subtitle: subtitle,
      art: ListingArt.clipboard,
      bottom: bottom ??
          (chips.isEmpty
              ? null
              : Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: chips)),
    );
  }
}
