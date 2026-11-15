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
          padding: DS.sym(h: 28),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                margin: EdgeInsets.only(top: DS.s(42)),
                padding: DS.insets(l: 24, t: 54, r: 24, b: 20),
                decoration: GateKit.card(),
                child: TemplateStagger(
                  children: [
                    Text(
                      content.title,
                      textAlign: TextAlign.center,
                      style: FitnessAppTheme.title.copyWith(fontSize: DS.f(18)),
                    ),
                    SizedBox(height: DS.s(8)),
                    Text(
                      content.body,
                      textAlign: TextAlign.center,
                      style: FitnessAppTheme.body2
                          .copyWith(fontSize: DS.f(12.5), height: 1.55, color: FitnessAppTheme.lightText),
                    ),
                    SizedBox(height: DS.s(20)),
                    GateButton(label: content.primaryLabel, height: 48, onPressed: onPrimary),
                    if (content.secondaryLabel != null) ...[
                      SizedBox(height: DS.s(6)),
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
