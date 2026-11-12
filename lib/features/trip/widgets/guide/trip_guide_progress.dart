import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../trip_strings_guide.dart';

class TripGuideProgress extends StatelessWidget {
  const TripGuideProgress({super.key, required this.percent, required this.name, required this.index, required this.total});

  final int percent;
  final String name;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final shown = total <= 0 ? 0 : (index + 1).clamp(1, total);
    final p = percent.clamp(0, 100);
    final reduce = KitMotion.reduce(context);
    return Semantics(
      label: '${TripStringsGuide.percent(p)}. ${TripStringsGuide.stepOf(shown, total)}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.style(15, FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text(TripStringsGuide.percent(p), style: TypeTokens.style(13, FontWeight.w700, color: KitTone.trip.accentDark)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: KitMetrics.buttonRadius,
            child: SizedBox(
              height: 8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: DesignColors.divider),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: p / 100),
                    duration: reduce ? Duration.zero : const Duration(milliseconds: 400),
                    curve: Curves.fastOutSlowIn,
                    builder: (_, v, _) => Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: v.clamp(0.0, 1.0),
                        heightFactor: 1,
                        child: const DecoratedBox(decoration: BoxDecoration(gradient: DesignGradients.lunch)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(TripStringsGuide.stepOf(shown, total), style: TypeTokens.caption),
        ],
      ),
    );
  }
}
