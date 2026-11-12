import 'package:flutter/material.dart';
import '../config/tour_registry.dart';
import '../design/design.dart';

class TourInfoDialog extends StatelessWidget {
  final TourDialogContent content;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;

  const TourInfoDialog({
    super.key,
    required this.content,
    required this.onPrimary,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final isIntro = content.phase == TourDialogPhase.intro;

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          color: GateKit.scrimDeep,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 42),
                padding: const EdgeInsets.fromLTRB(24, 54, 24, 20),
                decoration: GateKit.card(),
                child: TemplateStagger(
                  children: [
                    Text(
                      content.title,
                      textAlign: TextAlign.center,
                      style: FitnessAppTheme.title.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      content.body,
                      textAlign: TextAlign.center,
                      style: FitnessAppTheme.body2
                          .copyWith(fontSize: 12.5, height: 1.55, color: FitnessAppTheme.lightText),
                    ),
                    const SizedBox(height: 20),
                    GateButton(label: content.primaryLabel, height: 48, onPressed: onPrimary),
                    if (content.secondaryLabel != null) ...[
                      const SizedBox(height: 6),
                      GateTextButton(
                        label: content.secondaryLabel!,
                        onPressed: onSecondary,
                        color: FitnessAppTheme.deactivatedText,
                        fontSize: 12.5,
                        weight: FontWeight.w700,
                      ),
                    ],
                  ],
                ),
              ),
              GateBadge(
                asset: isIntro ? TravelIcon.route : TravelIcon.star,
                gradient: isIntro ? TripEntryStyle.gradient : PickKit.stayGradient,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
