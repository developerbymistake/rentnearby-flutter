import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../trip_ui.dart';

class TripGuideFrame extends StatelessWidget {
  const TripGuideFrame({super.key, required this.title, required this.body, required this.asset, required this.child});

  static int builds = 0;

  final String title;
  final String body;
  final String asset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    builds++;
    return TripSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      shadow: ShadowTokens.elev3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: TravelIcon(asset, size: 44)),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: TypeTokens.style(18, FontWeight.w800, height: 1.2)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: TypeTokens.style(14, FontWeight.w500, color: TypeTokens.secondary, height: 1.35)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
