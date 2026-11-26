import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'pill_buttons_3d.dart';
import 'package:bakhli/design/tokens/design_scale.dart';
import '../tokens/card_tokens.dart';

class StepProgressHeader extends StatelessWidget {
  const StepProgressHeader({
    super.key,
    required this.tone,
    required this.labels,
    required this.current,
    this.onStepTap,
    this.margin,
    this.activeLabelColor,
  });

  final ListingTone tone;
  final List<String> labels;
  final int current;
  final ValueChanged<int>? onStepTap;
  final EdgeInsets? margin;
  final Color? activeLabelColor;

  static double get dot => DS.s(38);

  String _state(int i) => i < current ? 'done' : (i == current ? 'current' : 'to do');

  Widget _dot(int i) {
    final done = i < current;
    final on = i == current;
    return Container(
      width: dot,
      height: dot,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done || on ? null : Form3D.todo,
        gradient: done || on ? tone.gradient : null,
        boxShadow: on
            ? [BoxShadow(color: Form3D.wash(tone, 0.18), spreadRadius: DS.s(4)), BoxShadow(color: tone.shadow, offset: DS.shadowOffset(const Offset(2, 5)), blurRadius: DS.shadowBlur(8))]
            : null,
      ),
      child: done
          ? Icon(Icons.check_rounded, size: DS.s(22), color: Colors.white)
          : Text('${i + 1}', textScaler: TextScaler.noScaling, style: Ink3D.text(15, FontWeight.w700, on ? Colors.white : Form3D.todoText, letterSpacing: 0)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
    return Container(
      margin: margin ?? DS.gapInsets(l: 18, t: 6, r: 18),
      padding: EdgeInsets.fromLTRB(DS.s(14), DS.s(14), DS.s(14), DS.s(10)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DS.br(CardRadius.card),
        boxShadow: DS.shadows(Form3D.cardShadow),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final cell = math.max(dot + DS.s(2), math.min(DS.s(62) * scale.clamp(1.0, 1.3), (box.maxWidth - DS.gh(10) * (n - 1)) / n));
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < n; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: DS.s(3),
                      margin: EdgeInsets.only(top: (dot - DS.s(3)) / 2),
                      decoration: BoxDecoration(
                        borderRadius: DS.circular(2),
                        color: i <= current ? null : Form3D.todo,
                        gradient: i <= current ? LinearGradient(colors: [tone.g1, tone.g2]) : null,
                      ),
                    ),
                  ),
                SizedBox(
                  width: cell,
                  child: Tap3D(
                    onTap: onStepTap == null ? null : () => onStepTap!(i),
                    label: 'Step ${i + 1} of $n, ${labels[i]}, ${_state(i)}',
                    exclude: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _dot(i),
                        SizedBox(height: DS.s(6)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            labels[i],
                            maxLines: 1,
                            softWrap: false,
                            style: Ink3D.text(11.5, FontWeight.w600, i <= current ? (activeLabelColor ?? tone.text) : Form3D.todoText, letterSpacing: 0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
