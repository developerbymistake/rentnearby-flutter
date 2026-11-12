import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../trip_strings.dart';
import '../trip_strings_a5.dart';
import '../trip_strings_v2_plan.dart';
import '../utils/trip_bar_rules.dart';
import '../utils/trip_clock.dart';
import 'trip_status.dart';

class TripProgressRing extends StatelessWidget {
  final int percent;
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Color textColor;
  final Color? fill;
  final Animation<double>? animation;

  const TripProgressRing({
    super.key,
    required this.percent,
    this.size = 48,
    this.stroke = 6,
    this.color = TripEntryStyle.accent,
    this.track = TripEntryStyle.surface,
    this.textColor = FitnessAppTheme.darkerText,
    this.fill,
    this.animation,
  });

  Widget _ring(int p, double progress) => TemplateMiniRing(
        percent: p,
        size: size - 4,
        stroke: stroke,
        track: track,
        progress: progress,
        colors: [color, TravelPalette.ringLight, TravelPalette.ringLight],
      );

  @override
  Widget build(BuildContext context) {
    final p = percent.clamp(0, 100).toInt();
    final a = animation;
    return Container(
      width: size,
      height: size,
      decoration: fill == null ? null : BoxDecoration(color: fill, shape: BoxShape.circle),
      child: Stack(
        alignment: Alignment.center,
        children: [
          a == null
              ? _ring(p, 1)
              : AnimatedBuilder(animation: a, builder: (_, __) => _ring(p, a.value)),
          Text(
            '$p%',
            textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15),
            style: TextStyle(
                fontFamily: FitnessAppTheme.fontName, fontSize: size * 0.21, fontWeight: FontWeight.w800, color: textColor),
          ),
        ],
      ),
    );
  }
}

class TripCard extends StatelessWidget {
  final TripSummaryModel trip;
  final bool past;
  final VoidCallback onOpen;
  final VoidCallback onAction;
  final VoidCallback? onShare;
  final VoidCallback onDelete;
  final VoidCallback? onMarkComplete;
  final Animation<double>? animation;

  const TripCard({
    super.key,
    required this.trip,
    this.past = false,
    required this.onOpen,
    required this.onAction,
    this.onShare,
    required this.onDelete,
    this.onMarkComplete,
    this.animation,
  });

  static TripBookingState stateOf(TripSummaryModel t) {
    if (t.isCompleted) return TripBookingState.completed;
    final s = t.state;
    return s == TripBookingState.planOnly ? TripBookingState.draft : s;
  }

  Widget _badge(String label, Color color, Color surface) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: surface, borderRadius: CardRadius.pill),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TypeTokens.style(11, FontWeight.w700, color: color),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final p = t.progress;
    final ready = !past && TripBarRules.isReady(t);
    final title = t.title.trim().isEmpty ? t.routeLine : t.title.trim();
    final showRoute = t.legCount > 1 && title != t.routeLine;
    final ringColor = ready || past ? TravelPalette.skyEnd : FitnessAppTheme.nearlyDarkBlue;
    final needs = TripBarRules.needCount(t);
    final showChips = !past && (p.inProgress > 0 || needs > 0);
    final label = TripBarRules.actionLabel(t, past: past);
    return PressScale(
      child: Container(
        decoration: const BoxDecoration(
          color: DesignColors.surface,
          borderRadius: CardRadius.tile,
          boxShadow: ShadowTokens.elev2,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: CardRadius.tile,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            borderRadius: CardRadius.tile,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 4, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TripProgressRing(percent: p.percent, size: 52, color: ringColor, animation: animation),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TypeTokens.style(15, FontWeight.w700, color: DesignColors.textStrong),
                            ),
                            if (showRoute)
                              Text(
                                t.routeLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TypeTokens.style(12, FontWeight.w400, color: TypeTokens.secondary),
                              ),
                            Text(
                              TripBarRules.datesLine(t, TripClock.today()),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TypeTokens.style(12, FontWeight.w400, color: TypeTokens.secondary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p.total == 0 ? TripStringsV2Plan.nothingToArrange : TripStringsV2Plan.myTripsArranged(p.done, p.total),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TypeTokens.style(12, FontWeight.w600, color: DesignColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        constraints: const BoxConstraints(minWidth: 140),
                        icon: const Icon(Icons.more_vert_rounded, size: 22, color: DesignColors.textGrey),
                        color: DesignColors.surface,
                        elevation: 8,
                        shape: const RoundedRectangleBorder(borderRadius: CardRadius.tile),
                        onSelected: (v) {
                          if (v == 'share') onShare?.call();
                          if (v == 'complete') onMarkComplete?.call();
                          if (v == 'delete') onDelete();
                        },
                        itemBuilder: (_) => [
                          if (onShare != null)
                            PopupMenuItem(
                              value: 'share',
                              height: 44,
                              child: Text(TripStringsA5.share, style: TypeTokens.style(14, FontWeight.w500)),
                            ),
                          if (onMarkComplete != null)
                            PopupMenuItem(
                              value: 'complete',
                              height: 44,
                              child: Text(TripStrings.markComplete, style: TypeTokens.style(14, FontWeight.w500)),
                            ),
                          PopupMenuItem(
                            value: 'delete',
                            height: 44,
                            child: Text(TripStrings.delete, style: TypeTokens.style(14, FontWeight.w500, color: DesignColors.error)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TripBookingStatePill(stateOf(t)),
                        if (showChips && needs > 0)
                          _badge(TripStringsV2Plan.needsYou(needs), TravelPalette.roseEnd, TripEntryStyle.roseTint),
                        if (showChips && p.inProgress > 0)
                          _badge(TripStringsV2Plan.waitingForReply(p.inProgress), DesignColors.textGreyDark, TripEntryStyle.sunriseTint),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ready || past
                        ? SecondaryButton(label: label, onPressed: onAction, tone: KitTone.trip)
                        : PrimaryButton(label: label, onPressed: onAction, tone: KitTone.trip),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
