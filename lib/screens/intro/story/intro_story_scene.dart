import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'intro_story_math.dart';
import 'intro_story_state.dart';
import 'paint_cast.dart';
import 'paint_ground.dart';
import 'paint_sky.dart';
import 'paint_table.dart';
import 'paint_world.dart';
import 'paint_world_fx.dart';

class IntroStoryScene extends StatelessWidget {
  const IntroStoryScene({super.key, required this.state, required this.progress, required this.panelTop});

  final IntroStoryState state;
  final ValueListenable<double> progress;
  final double panelTop;

  static Widget _layer(CustomPainter painter) => RepaintBoundary(child: CustomPaint(painter: painter));

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(builder: (context, c) {
          final geo = IntroStoryGeo.of(c.biggest, panelTop);
          return Stack(
            fit: StackFit.expand,
            children: [
              _layer(IntroSkyPainter(state, geo)),
              _layer(IntroHillsPainter(state, geo)),
              _WorldSlide(
                progress: progress,
                geo: geo,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _layer(IntroGroundPainter(state, geo, IntroGroundPart.trees)),
                    _layer(IntroWorldPainter(state, geo)),
                    _layer(IntroWorldFxPainter(state, geo)),
                    _layer(IntroGroundPainter(state, geo, IntroGroundPart.road)),
                    _layer(IntroActorsPainter(state, geo)),
                  ],
                ),
              ),
              _TableSlide(progress: progress, geo: geo, child: _layer(IntroTablePainter(state, geo))),
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
        builder: (context, p, child) => Offstage(
          offstage: p <= 0,
          child: Transform.translate(offset: Offset((1 - smooth(clamp01(p))) * geo.slidePx, 0), child: child),
        ),
      );
}

class _TableSlide extends StatelessWidget {
  const _TableSlide({required this.progress, required this.geo, required this.child});

  final ValueListenable<double> progress;
  final IntroStoryGeo geo;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: progress,
        child: child,
        builder: (context, p, child) => p >= 1
            ? const SizedBox.shrink()
            : Transform.translate(offset: Offset(-smooth(clamp01(p)) * geo.slidePx, 0), child: child),
      );
}
