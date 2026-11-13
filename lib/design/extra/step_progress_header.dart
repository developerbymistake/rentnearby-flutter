import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'pill_buttons_3d.dart';

class StepProgressHeader extends StatelessWidget {
  const StepProgressHeader({
    super.key,
    required this.tone,
    required this.labels,
    required this.current,
    this.onStepTap,
    this.margin = const EdgeInsets.fromLTRB(18, 6, 18, 0),
    this.activeLabelColor,
  });

  final ListingTone tone;
  final List<String> labels;
  final int current;
  final ValueChanged<int>? onStepTap;
  final EdgeInsets margin;
  final Color? activeLabelColor;

  static const double dot = 38;

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
            ? [BoxShadow(color: Form3D.wash(tone, 0.18), spreadRadius: 4), BoxShadow(color: tone.shadow, offset: const Offset(2, 5), blurRadius: 8)]
            : null,
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 22, color: Colors.white)
          : Text('${i + 1}', textScaler: TextScaler.noScaling, style: Ink3D.text(15, FontWeight.w700, on ? Colors.white : Form3D.todoText, letterSpacing: 0)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(30), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
        boxShadow: Form3D.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final cell = math.max(dot + 2, math.min(62 * scale.clamp(1.0, 1.3), (box.maxWidth - 10 * (n - 1)) / n));
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < n; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.only(top: (dot - 3) / 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
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
                        const SizedBox(height: 6),
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
