import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_guide_args.dart';
import '../trip_strings_guide.dart';

ListingTone tripListTone(KitTone tone) => identical(tone, KitTone.taxi) ? ListingTone.coral : ListingTone.forest;

class TripGuideStepInfo {
  const TripGuideStepInfo(this.name, this.chip);

  final String name;
  final String chip;

  static TripGuideStepInfo? of(GuideArgs? guide) {
    if (guide == null || !Get.isRegistered<TripPlanController>() || Get.isPrepared<TripPlanController>()) return null;
    final g = Get.find<TripPlanController>().guideState;
    final i = g.steps.indexWhere((s) => s.key == guide.stepKey);
    final total = g.total.value > 0 ? g.total.value : g.steps.length;
    if (i < 0 || total <= 0) return null;
    return TripGuideStepInfo(g.steps[i].name, TripStringsGuide.stepCount(i + 1, total));
  }
}

class TripListTopBar extends StatelessWidget {
  const TripListTopBar({
    super.key,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.guide,
    this.skipLabel,
    this.onSkip,
  });

  final ListingTone tone;
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final GuideArgs? guide;
  final String? skipLabel;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final step = TripGuideStepInfo.of(guide);
    final skip = skipLabel;
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top, bottom: 6),
      child: TopBar3D(
        tone: tone,
        title: title,
        subtitle: subtitle,
        stepChip: step?.chip,
        onBack: onBack,
        trailing: skip == null ? null : TripSkipPill(label: skip, onTap: onSkip, tone: tone),
      ),
    );
  }
}

class TripSkipPill extends StatelessWidget {
  const TripSkipPill({super.key, required this.label, required this.onTap, required this.tone});

  final String label;
  final VoidCallback? onTap;
  final ListingTone tone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: PressScale(
        enabled: onTap != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 46, minWidth: 46),
            child: Center(
              widthFactor: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: DesignColors.surface,borderRadius: BorderRadius.circular(22), boxShadow: Ink3D.softShadow),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, tone.text, letterSpacing: 0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
