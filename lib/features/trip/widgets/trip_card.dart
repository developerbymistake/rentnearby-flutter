import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../trip_strings.dart';
import '../trip_strings_a5.dart';
import '../trip_strings_tab.dart';
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
              : AnimatedBuilder(animation: a, builder: (_, _) => _ring(p, a.value)),
          Text(
            '$p%',
            textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15),
            style: TextStyle(
                fontFamily: FitnessAppTheme.fontName, fontSize: size * 0.21, fontWeight: FontWeight.w700, color: textColor),
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

  static String lineBreakDates(String line) => line.replaceAll(' · ', '\n');

  static String routeTitle(TripSummaryModel t) =>
      t.legCount > 1 ? t.legCities.where((c) => c.isNotEmpty).join(' to ') : t.routeLine;

  static TripBookingState stateOf(TripSummaryModel t) {
    if (t.isCompleted) return TripBookingState.completed;
    final s = t.state;
    return s == TripBookingState.planOnly ? TripBookingState.draft : s;
  }

  Widget _menu() => PopupMenuButton<String>(
        constraints: const BoxConstraints(minWidth: 140),
        icon: const Icon(Icons.more_vert_rounded, size: 22, color: DesignColors.onPrimary),
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
      );

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final p = t.progress;
    final ready = !past && TripBarRules.isReady(t);
    final route = routeTitle(t);
    final cities = t.legCities.where((c) => c.isNotEmpty).toList();
    final title = t.title.trim().isNotEmpty
        ? t.title.trim()
        : (cities.length > 2 ? '${cities.first} to ${cities.last}' : route);
    final via = t.title.trim().isEmpty && cities.length > 2;
    final routeText = via ? 'Via ${cities.sublist(1, cities.length - 1).join(', ')}' : route;
    final showRoute = t.legCount > 1 && (via || title != route);
    final needs = TripBarRules.needCount(t);
    final showChips = !past && (p.inProgress > 0 || needs > 0);
    final dates = lineBreakDates(TripBarRules.datesLine(t, TripClock.today()));
    final tone = past ? ListingTone.cD : (ready ? ListingTone.cE : ListingTone.cB);
    return WideCard(
      tone: tone,
      art: past ? ListingArt.camera : ListingArt.luggage,
      tag: TripBookingStateVisuals.label(stateOf(t)),
      title: title,
      subtitle: showRoute ? '$routeText\n$dates' : dates,
      chips: [
        p.total == 0 ? TripStringsV2Plan.nothingToArrange : TripStringsTab.doneShort(p.done, p.total),
        if (showChips && needs > 0) TripStringsV2Plan.needsYou(needs),
        if (showChips && p.inProgress > 0) TripStringsTab.waitingShort(p.inProgress),
      ],
      showPrice: false,
      progress: p.percent / 100,
      trailing: _menu(),
      trailingWidth: 30,
      actions: [
        WideAction(
          icon: ready || past ? Icons.receipt_long_rounded : Icons.arrow_forward_rounded,
          label: TripBarRules.actionLabel(t, past: past),
          onTap: onAction,
        ),
      ],
      onTap: onOpen,
    );
  }
}
