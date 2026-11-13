import 'package:flutter/material.dart';
import '../config/module_palette.dart';
import '../design/design.dart';
import 'location_switch_sheet.dart';

class EmptyRadiusHint extends StatefulWidget {
  final String label;
  final double circleRadiusPx;
  final ModulePalette palette;
  const EmptyRadiusHint({
    super.key,
    required this.label,
    required this.circleRadiusPx,
    this.palette = templateModulePalette,
  });

  @override
  State<EmptyRadiusHint> createState() => _EmptyRadiusHintState();
}

class _EmptyRadiusHintState extends State<EmptyRadiusHint> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _entrance;
  late final Animation<double> _scale;
  late final ListingTone _tone = moduleToneFor(widget.palette);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _scale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (KitMotion.reduce(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = (widget.circleRadiusPx / 100).clamp(0.6, 1.0);
    return TemplateEntrance(
      animation: templateInterval(_entrance, 0, 1),
      animationController: _entrance,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(8 * scale, 6 * scale, 14 * scale, 6 * scale),
              decoration: BoxDecoration(
                color: DesignColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: _tone.shadow, offset: const Offset(1.1, 4), blurRadius: 10)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(child: Art3D(asset: ListingArt.worldMap, size: 26 * scale, shadowBlur: 2, shadowOffset: const Offset(2, 3), shadowAlpha: 0.25)),
                  SizedBox(width: 8 * scale),
                  Text(widget.label, style: Ink3D.text(12 * scale, FontWeight.w600, Ink3D.title)),
                ],
              ),
            ),
            Transform.translate(
              offset: Offset(0, -5 * scale),
              child: Transform.rotate(
                angle: 0.7854,
                child: Container(width: 9 * scale, height: 9 * scale, color: DesignColors.surface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
