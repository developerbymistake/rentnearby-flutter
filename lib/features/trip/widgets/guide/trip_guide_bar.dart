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
        padding: EdgeInsets.fromLTRB(16, 8, 16, AppInsets.bottomViewPadding(context) + 8),
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
                      flex: 3,
                      child: TripButton(label: TripStringsGuide.previous, height: 44, outlined: true, onPressed: onPrevious),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: TripButton(label: TripStringsGuide.next, height: 44, onPressed: canNext ? onNext : null),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      flex: 3,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: TextLink(label: TripStringsGuide.overview, onTap: onOverview, tone: KitTone.trip),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
