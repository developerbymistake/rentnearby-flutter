import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../models/trip_model.dart';
import '../../trip_strings.dart';
import '../../trip_strings_a5.dart';
import '../../utils/trip_bar_rules.dart';
import '../../utils/trip_clock.dart';
import '../../utils/trip_format.dart';
import '../trip_card.dart';
import 'hub_tokens.dart';
import 'hub_trip_body.dart';

class HubTripCard extends StatelessWidget {
  final TripSummaryModel trip;
  final bool past;
  final VoidCallback onOpen;
  final VoidCallback onAction;
  final VoidCallback? onShare;
  final VoidCallback onDelete;
  final VoidCallback? onMarkComplete;

  const HubTripCard({
    super.key,
    required this.trip,
    this.past = false,
    required this.onOpen,
    required this.onAction,
    this.onShare,
    required this.onDelete,
    this.onMarkComplete,
  });

  static String titleOf(TripSummaryModel t) {
    final cities = t.legCities.where((c) => c.isNotEmpty).toList();
    if (t.title.trim().isNotEmpty) return t.title.trim();
    if (cities.length == 2 && t.legCount > 1) return '${cities.first} & ${cities.last}';
    return cities.length > 2 ? '${cities.first} to ${cities.last}' : TripCard.routeTitle(t);
  }

  static String _dm(DateTime d) {
    final s = TripFormat.dayMonth(d);
    return s.startsWith('0') ? s.substring(1) : s;
  }

  static String datesOf(TripSummaryModel t, DateTime today, {bool past = false}) {
    final s = t.startDate;
    final line = TripBarRules.datesLine(t, today);
    if (s == null) return line;
    final e = TripBarRules.endOf(t) ?? s;
    final range = e == s ? _dm(s) : '${_dm(s)} to ${_dm(e)}';
    final cut = line.indexOf(' · ');
    return past || cut < 0 ? range : '${line.substring(0, cut)} · $range';
  }

  Widget _menu() => PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 140),
        icon: const Icon(Icons.more_vert_rounded, size: 22, color: HubTokens.sub),
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
    final dates = datesOf(trip, TripClock.today(), past: past);
    final radius = HubTokens.cardRadius(68);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: radius, boxShadow: HubTokens.cardShadow),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: Colors.white,
            child: Stack(
              children: [
                InkWell(
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 50),
                          child: Text(
                            titleOf(trip),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Ink3D.text(16, FontWeight.w700, HubTokens.ink, height: 1.5, letterSpacing: 0),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 10),
                          child: Text(
                            dates,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Ink3D.text(12, FontWeight.w400, HubTokens.grey, height: 1.5, letterSpacing: 0),
                          ),
                        ),
                        HubTripBody(trip: trip, onNext: onAction, past: past),
                      ],
                    ),
                  ),
                ),
                Positioned(right: 10, top: 8, width: 34, height: 34, child: _menu()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
