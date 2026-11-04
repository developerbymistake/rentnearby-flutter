import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../taxi_option_sets.dart';
import '../../ways/taxi_ways_strings.dart';
import '../journey_models.dart';

class JourneyStatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const JourneyStatusPill({super.key, required this.text, required this.color, required this.background});

  factory JourneyStatusPill.of(SavedJourney j) {
    final (fg, bg) = switch (j.status) {
      JourneyStatus.ready => (AppColors.successText, AppColors.successSurface),
      JourneyStatus.driverUnavailable => (AppColors.warningText, AppColors.warningSurface),
      JourneyStatus.notAsked => (AppColors.neutralChipText, AppColors.neutralChip),
      JourneyStatus.completed => (AppColors.neutralChipText, AppColors.neutralChip),
    };
    return JourneyStatusPill(text: JourneyFormat.statusText(j), color: fg, background: bg);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class JourneyOfflineBanner extends StatelessWidget {
  const JourneyOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: AppColors.warningSurface,
      child: const Row(children: [
        Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.warningText),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            TaxiWaysStrings.offlineSaved,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText),
          ),
        ),
      ]),
    );
  }
}

class JourneyStatusBanner extends StatelessWidget {
  final SavedJourney journey;
  final bool busy;
  final void Function(SavedJourneyLeg leg, JourneyContact backup) onReplace;
  final void Function(SavedJourneyLeg leg) onChange;

  const JourneyStatusBanner({
    super.key,
    required this.journey,
    required this.busy,
    required this.onReplace,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final leg = journey.firstUnavailable;
    if (leg == null) return const SizedBox.shrink();
    final backup = leg.readyBackup;
    final body = backup == null
        ? TaxiWaysStrings.pausedNoBackup(leg.driver.driverName)
        : TaxiWaysStrings.pausedBody(leg.driver.driverName, backup.driverName);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.warningText),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                TaxiWaysStrings.statusUnavailable(journey.unavailableCount),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.warningText),
              ),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.warningText)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: backup == null
              ? OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: AppColors.warningText,
                    side: const BorderSide(color: AppColors.warning),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: busy ? null : () => onChange(leg),
                  child: const Text(TaxiWaysStrings.changeDriver),
                )
              : FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: TaxiColors.accentDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: busy ? null : () => onReplace(leg, backup),
                  child: Text(
                    TaxiWaysStrings.replaceWith(backup.driverName),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
        ),
      ]),
    );
  }
}
