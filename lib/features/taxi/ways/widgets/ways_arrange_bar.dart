import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ways_kit.dart';
import '../../../../config/app_insets.dart';

class WaysArrangeBar extends StatelessWidget {
  final String arrangeLabel;
  final String skipLabel;
  final VoidCallback onArrange;
  final VoidCallback onSkip;
  final double maxWidth;

  const WaysArrangeBar({
    super.key,
    required this.arrangeLabel,
    required this.skipLabel,
    required this.onArrange,
    required this.onSkip,
    this.maxWidth = 720,
  });

  Widget _action(String label, VoidCallback onTap, {int maxLines = 1, double minWidth = 64}) => InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth, minHeight: 48),
          child: Center(
            heightFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                maxLines: maxLines,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: FitnessAppTheme.title.copyWith(fontSize: 14, color: DesignColors.primary),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32)),
        boxShadow: WaysKit.topShadow,
      ),
      padding: EdgeInsets.fromLTRB(16, 6, 16, 6 + AppInsets.bottomViewPadding(context)),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Row(children: [
            Expanded(child: _action(arrangeLabel, onArrange, maxLines: 2, minWidth: 0)),
            _action(skipLabel, onSkip),
          ]),
        ),
      ),
    );
  }
}
