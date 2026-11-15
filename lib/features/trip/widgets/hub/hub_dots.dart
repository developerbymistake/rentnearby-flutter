import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'hub_tokens.dart';

class HubDots extends StatelessWidget {
  const HubDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final duration = KitMotion.reduce(context) ? Duration.zero : templateTransitionDuration;
    return ExcludeSemantics(
      child: Row(
        key: const ValueKey('hub-dots'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: duration,
              curve: Curves.fastOutSlowIn,
              width: DS.s(i == index ? 20 : 7),
              height: DS.s(7),
              margin: EdgeInsets.symmetric(horizontal: DS.gh(3)),
              decoration: BoxDecoration(
                color: i == index ? HubTokens.accent : HubTokens.dotOff,
                borderRadius: DS.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
