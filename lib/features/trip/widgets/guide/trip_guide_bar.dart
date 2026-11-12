import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../../../config/app_insets.dart';
import '../../trip_strings_guide.dart';
import '../trip_ui.dart';

class TripGuideBar extends StatelessWidget {
  const TripGuideBar({
    super.key,
    required this.canNext,
    required this.onPrevious,
    required this.onNext,
    required this.onOverview,
  });

  final bool canNext;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onOverview;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: DesignColors.surface, borderRadius: CardRadius.tile, boxShadow: ShadowTokens.elev3),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, AppInsets.bottomViewPadding(context) + 10),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!canNext)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(TripStringsGuide.chooseHint, textAlign: TextAlign.center, style: TypeTokens.caption),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TripButton(label: TripStringsGuide.previous, height: 52, outlined: true, onPressed: onPrevious),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TripButton(label: TripStringsGuide.next, height: 52, onPressed: canNext ? onNext : null),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Center(child: TextLink(label: TripStringsGuide.overview, onTap: onOverview, tone: KitTone.trip)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
