import 'package:flutter/material.dart';
import 'hub_tokens.dart';

class HubPageBackground extends StatelessWidget {
  const HubPageBackground({super.key, required this.child, this.minHeight = 0});

  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(gradient: HubTokens.pageGradient),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: child,
        ),
      );
}
