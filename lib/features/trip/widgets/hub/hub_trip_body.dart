import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../models/trip_model.dart';
import '../../trip_strings_hub_trips.dart';
import '../../trip_strings_v2_plan.dart';
import '../../utils/trip_bar_rules.dart';
import '../../utils/trip_card_bars.dart';
import '../../utils/trip_format.dart';
import 'hub_card_bars.dart';
import 'hub_ring.dart';
import 'hub_tokens.dart';

class HubTripBody extends StatelessWidget {
  final TripSummaryModel trip;
  final VoidCallback onNext;
  final bool past;
  final String stripLabel;

  const HubTripBody({
    super.key,
    required this.trip,
    required this.onNext,
    this.past = false,
    this.stripLabel = TripStringsHubTrips.nextStep,
  });

  static const _pastGreen = Color(0xFF2E7D32);
  static const _pastGrey = Color(0xFF6B7488);

  static String _pastDate(TripSummaryModel t) {
    final d = t.completedAt?.toLocal() ?? t.endDate;
    if (d == null) return '';
    final s = TripFormat.dayMonth(d);
    return s.startsWith('0') ? s.substring(1) : s;
  }

  @override
  Widget build(BuildContext context) {
    final p = trip.progress;
    final ready = !past && TripBarRules.isReady(trip);
    final needs = TripBarRules.needCount(trip);
    final percent = past ? 100 : p.percent.clamp(0, 100).toInt();
    final stripTitle = past
        ? TripStringsHubTrips.tripFinished
        : ready
            ? TripStringsHubTrips.viewSummary
            : (TripBarRules.nextTitle(trip) ?? TripBarRules.actionLabel(trip));
    final label = past
        ? TripStringsHubTrips.completed
        : ready
            ? TripStringsHubTrips.readyStrip
            : stripLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Stat(
                    icon: TravelIcon.note,
                    value: p.total == 0 ? '0' : TripStringsHubTrips.stepsOf(p.done, p.total),
                    label: p.total == 0 ? TripStringsV2Plan.nothingToArrange : TripStringsHubTrips.stepsDone,
                  ),
                  const SizedBox(height: 12),
                  if (past)
                    _Stat(icon: TravelIcon.calendar, value: TripStringsHubTrips.doneLabel, label: _pastDate(trip))
                  else
                    _Stat(icon: TravelIcon.bell, value: '$needs', label: TripStringsHubTrips.needsYou),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: HubRing(
                percent: percent,
                size: 104,
                thickness: 11,
                arc: past ? _pastGreen : HubTokens.accent,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: Ink3D.text(24, FontWeight.w700, HubTokens.ink, height: 1, letterSpacing: 0),
                    ),
                    Text(
                      past ? TripStringsHubTrips.done : TripStringsHubTrips.ready,
                      style: Ink3D.text(11, FontWeight.w400, HubTokens.grey, height: 21 / 11, letterSpacing: 0),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        HubCardBars(bars: TripCardBars.of(trip)),
        _Strip(label: label, title: stripTitle, past: past, color: past ? _pastGrey : HubTokens.accent, onTap: onNext),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  const _Stat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: HubTokens.chipBg, shape: BoxShape.circle),
          child: Image.asset(icon, width: 22, height: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Ink3D.text(20, FontWeight.w700, HubTokens.ink, height: 1.05, letterSpacing: 0)),
              if (label.isNotEmpty)
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(12, FontWeight.w400, HubTokens.grey, height: 1.75, letterSpacing: 0),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Strip extends StatelessWidget {
  final String label;
  final String title;
  final bool past;
  final Color color;
  final VoidCallback onTap;
  const _Strip({required this.label, required this.title, required this.past, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final from = past ? const Color(0xFF9AA3B8) : HubTokens.accentLight;
    final to = past ? const Color(0xFF6B7488) : HubTokens.accent;
    final shadow = past ? const Color(0x386B7488) : const Color(0x405C5EDD);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: HubTokens.cardRadius(30),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [from, to]),
          boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 6), blurRadius: 14)],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: HubTokens.cardRadius(30),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: Ink3D.text(12, FontWeight.w400, Colors.white.withValues(alpha: .92), height: 1.5, letterSpacing: 0),
                        ),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Ink3D.text(17, FontWeight.w700, Colors.white, letterSpacing: 0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFAFAFA),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Color(0x2E000000), offset: Offset(3, 5), blurRadius: 8)],
                    ),
                    alignment: Alignment.center,
                    child: Icon(past ? Icons.north_east_rounded : Icons.arrow_forward_rounded, size: 20, color: color),
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
