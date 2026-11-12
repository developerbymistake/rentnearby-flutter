import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

class TripCityArt extends StatelessWidget {
  const TripCityArt({super.key, required this.seed, required this.name});

  final int seed;
  final String name;

  static const _tones = [KitTone.stay, KitTone.taxi, KitTone.jobs, KitTone.rose, KitTone.stayOwner, KitTone.taxiDriver];

  static KitTone toneOf(int seed) => _tones[seed.abs() % _tones.length];

  @override
  Widget build(BuildContext context) {
    final tone = toneOf(seed);
    final initial = name.trim().isEmpty ? '' : name.trim().characters.first.toUpperCase();
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: tone.gradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _HillsPainter(seed.abs() % 3)),
            Align(
              alignment: const Alignment(0, -0.35),
              child: Text(initial, style: TypeTokens.style(44, FontWeight.w800, color: DesignColors.whiteHigh)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HillsPainter extends CustomPainter {
  _HillsPainter(this.variant);

  final int variant;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawCircle(Offset(w * (0.2 + variant * 0.25), h * 0.2), w * 0.1, Paint()..color = DesignColors.whiteSoft);
    Path ridge(double base, List<double> peaks) {
      final p = Path()..moveTo(0, h);
      p.lineTo(0, h * base);
      final step = w / peaks.length;
      for (var i = 0; i < peaks.length; i++) {
        p.lineTo(step * (i + 0.5), h * peaks[i]);
        p.lineTo(step * (i + 1), h * base);
      }
      return p..lineTo(w, h)..close();
    }

    final far = variant == 0 ? [0.5, 0.58, 0.46] : variant == 1 ? [0.56, 0.44, 0.54] : [0.46, 0.52, 0.58];
    canvas.drawPath(ridge(0.7, far), Paint()..color = DesignColors.whiteSoft);
    canvas.drawPath(ridge(0.82, [0.7, 0.76, 0.68, 0.74]), Paint()..color = DesignColors.tint(DesignColors.overlayDark, Alpha.soft));
  }

  @override
  bool shouldRepaint(_HillsPainter old) => old.variant != variant;
}
