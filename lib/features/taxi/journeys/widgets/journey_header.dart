import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';

class JourneyHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> chips;

  const JourneyHeader({super.key, required this.title, this.subtitle, this.chips = const []});

  @override
  Widget build(BuildContext context) {
    return ModuleHeader(
      title: title,
      subtitle: subtitle,
      tone: KitTone.taxi,
      onBack: () => Navigator.of(context).maybePop(),
      leadingAsset: TravelIcon.taxi,
      autoHeight: true,
      bottom: chips.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: chips),
              ),
            ),
    );
  }
}
