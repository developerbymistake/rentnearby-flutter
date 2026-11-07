import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';
import '../models/trip_model.dart';
import '../trip_colors.dart';
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

  const TripProgressRing({
    super.key,
    required this.percent,
    this.size = 48,
    this.stroke = 5,
    this.color = TripColors.accent,
    this.track = TripColors.surface,
    this.textColor = AppColors.textDark,
    this.fill,
  });

  @override
  Widget build(BuildContext context) {
    final p = percent.clamp(0, 100).toInt();
    return Container(
      width: size,
      height: size,
      decoration: fill == null ? null : BoxDecoration(color: fill, shape: BoxShape.circle),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size - 4,
            height: size - 4,
            child: CircularProgressIndicator(
              value: p / 100,
              strokeWidth: stroke,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: track,
            ),
          ),
          Text(
            '$p%',
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: size * 0.24, fontWeight: FontWeight.w800, color: textColor),
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

  const TripCard({
    super.key,
    required this.trip,
    this.past = false,
    required this.onOpen,
    required this.onAction,
    this.onShare,
    required this.onDelete,
    this.onMarkComplete,
  });

  static TripBookingState stateOf(TripSummaryModel t) {
    if (t.isCompleted) return TripBookingState.completed;
    final s = t.state;
    return s == TripBookingState.planOnly ? TripBookingState.draft : s;
  }

  Widget _badge(String label, Color color, Color surface) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(999)),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final p = t.progress;
    final ready = !past && TripBarRules.isReady(t);
    final title = t.title.trim().isEmpty ? t.routeLine : t.title.trim();
    final showRoute = t.legCount > 1 && title != t.routeLine;
    final ringColor = ready || past ? AppColors.success : TripColors.accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
          boxShadow: AppShadows.premium(TripColors.accent, alpha: 0.06, blur: 10, offset: const Offset(0, 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TripProgressRing(percent: p.percent, color: ringColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      ),
                      if (showRoute)
                        Text(
                          t.routeLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium),
                        ),
                      Text(
                        TripBarRules.datesLine(t, TripClock.today()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.total == 0 ? TripStringsV2Plan.nothingToArrange : TripStringsV2Plan.myTripsArranged(p.done, p.total),
                        maxLines: 1,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMedium),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: TripBookingStatePill(stateOf(t)),
                ),
                PopupMenuButton<String>(
                  constraints: const BoxConstraints(minWidth: 140),
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textLight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    if (v == 'share') onShare?.call();
                    if (v == 'complete') onMarkComplete?.call();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    if (onShare != null)
                      const PopupMenuItem(
                        value: 'share',
                        height: 44,
                        child: Text(TripStringsA5.share, style: TextStyle(fontFamily: 'Poppins')),
                      ),
                    if (onMarkComplete != null)
                      const PopupMenuItem(
                        value: 'complete',
                        height: 44,
                        child: Text(TripStrings.markComplete, style: TextStyle(fontFamily: 'Poppins')),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      height: 44,
                      child: Text(TripStrings.delete, style: TextStyle(fontFamily: 'Poppins', color: AppColors.error)),
                    ),
                  ],
                ),
              ],
            ),
            if (!past && (p.inProgress > 0 || TripBarRules.needCount(t) > 0)) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (TripBarRules.needCount(t) > 0)
                    _badge(TripStringsV2Plan.needsYou(TripBarRules.needCount(t)), TripStatusColors.failed,
                        TripStatusColors.failedSurface),
                  if (p.inProgress > 0)
                    _badge(TripStringsV2Plan.waitingForReply(p.inProgress), TripStatusColors.waiting,
                        TripStatusColors.waitingSurface),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _button(TripBarRules.actionLabel(t, past: past), ready || past),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(String label, bool quiet) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              gradient: quiet ? null : TripColors.gradient,
              color: quiet ? TripColors.surface : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: quiet ? TripColors.accentDark : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
