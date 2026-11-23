import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'intro_story_math.dart';
import 'intro_story_state.dart';
import 'paint_ground.dart';
import 'paint_sky.dart';

class IntroStoryScene extends StatelessWidget {
  const IntroStoryScene({super.key, required this.state, required this.progress, required this.panelTop});

  final IntroStoryState state;
  final ValueListenable<double> progress;
  final double panelTop;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(builder: (context, c) {
          final geo = IntroStoryGeo.of(c.biggest, panelTop);
          return Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(child: CustomPaint(painter: IntroSkyPainter(state, geo))),
              RepaintBoundary(child: CustomPaint(painter: IntroHillsPainter(state, geo))),
              _WorldSlide(
                progress: progress,
                geo: geo,
                child: RepaintBoundary(child: CustomPaint(painter: IntroGroundPainter(state, geo))),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _WorldSlide extends StatelessWidget {
  const _WorldSlide({required this.progress, required this.geo, required this.child});

  final ValueListenable<double> progress;
  final IntroStoryGeo geo;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: progress,
        child: child,
        builder: (context, p, child) => Transform.translate(offset: Offset((1 - smooth(clamp01(p))) * geo.slidePx, 0), child: child),
      );
}
