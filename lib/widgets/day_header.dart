import 'package:flutter/material.dart';
import '../design/design.dart';

class DayHeader extends StatelessWidget {
  final String label;
  final Animation<double>? animation;
  final AnimationController? animationController;
  const DayHeader(this.label, {super.key, this.animation, this.animationController});

  @override
  Widget build(BuildContext context) {
    final text = Padding(
      padding: EdgeInsets.fromLTRB(DS.s(2), DS.gv(4), DS.s(2), DS.gv(8)),
      child: Text(
        label.toUpperCase(),
        style: FitnessAppTheme.body2.copyWith(
          fontSize: DS.f(14),
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: FitnessAppTheme.lightText,
        ),
      ),
    );
    if (animation == null || animationController == null) return text;
    return TemplateEntrance(animation: animation!, animationController: animationController!, child: text);
  }
}
