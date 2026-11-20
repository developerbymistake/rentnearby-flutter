import 'package:flutter/material.dart';

import '../../../../design/design.dart';

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.padding});

  final String text;
  final String? trailing;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final t = trailing;
    return Padding(
      padding: padding ?? DS.insets(l: 22, t: 22, r: 22, b: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w700, Ink3D.grey, letterSpacing: 0.8)),
            ),
          ),
          if (t != null) Text(t, maxLines: 1, style: Ink3D.text(13, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
        ],
      ),
    );
  }
}
