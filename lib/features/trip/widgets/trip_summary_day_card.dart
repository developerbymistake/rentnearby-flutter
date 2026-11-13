import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_summary_model.dart';
import '../trip_strings_a5.dart';
import '../trip_strings_summary.dart';
import '../trip_strings_v2_easy.dart';
import '../utils/trip_day_timeline.dart';
import '../utils/trip_format.dart';
import '../utils/trip_summary_text.dart';
import 'trip_status.dart';

class TripDayChip {
  const TripDayChip(this.status, this.label, {this.taxi = false});

  final TripDisplayStatus status;
  final String label;
  final bool taxi;
}

class TripDayChips {
  static String _word(TripDisplayStatus s, {bool taxi = false}) =>
      s == TripDisplayStatus.none ? TripStringsV2Easy.pillTodo : TripStatusVisuals.label(s, taxi: taxi);

  static TripSummaryArrangement? _row(TripSummaryRecord r, TripEasyRowKind kind, [int? leg]) {
    for (final a in r.shownRows) {
      if (a.key.kind == kind && (leg == null || a.key.legIndex == leg)) return a;
    }
    return null;
  }

  static int _legOf(TripSummaryRecord r, int day) {
    for (final l in r.legs) {
      if (day >= l.startDay && day <= l.endDay) return l.index;
    }
    return 1;
  }

  static TripDayChip? stay(TripSummaryRecord r, TripSummaryDay d) {
    for (final n in r.allNights) {
      if (n.night == d.day) {
        final s = n.display;
        return TripDayChip(s, TripStringsSummary.stayState(_word(s)));
      }
    }
    final last = r.days.fold<int>(0, (m, e) => e.day > m ? e.day : m);
    if (d.day >= last) return null;
    final a = _row(r, TripEasyRowKind.stay, _legOf(r, d.day));
    if (a == null) return null;
    if (a.partial) return TripDayChip(TripDisplayStatus.none, TripStringsSummary.stayState(TripStringsV2Easy.pillTodo));
    return TripDayChip(TripSummaryText.pillStatus(a.state), TripStringsSummary.stayState(TripSummaryText.stateWord(a.state)));
  }

  static TripDayChip? taxi(TripSummaryRecord r, TripSummaryDay d) {
    final all = r.allTaxis;
    for (final t in all) {
      if (t.days.contains(d.day)) {
        final s = t.display;
        return TripDayChip(s, TripStringsSummary.taxiState(_word(s, taxi: true)), taxi: true);
      }
    }
    final anyDays = all.any((t) => t.days.isNotEmpty);
    if (all.isNotEmpty && anyDays) return null;
    final first = r.days.where((e) => e.spots.isNotEmpty).fold<int>(1 << 30, (m, e) => e.day < m ? e.day : m);
    if (d.day != first) return null;
    final a = _row(r, TripEasyRowKind.taxi);
    if (a == null) {
      if (all.isEmpty) return null;
      final t = all.first;
      final s = t.display;
      return TripDayChip(s, TripStringsSummary.taxiState(_word(s, taxi: true)), taxi: true);
    }
    return TripDayChip(TripSummaryText.pillStatus(a.state), TripStringsSummary.taxiState(TripSummaryText.stateWord(a.state)), taxi: true);
  }
}

class TripSummaryDayCard extends StatelessWidget {
  const TripSummaryDayCard({super.key, required this.day, this.stay, this.taxi});

  final TripSummaryDay day;
  final TripDayChip? stay;
  final TripDayChip? taxi;

  @override
  Widget build(BuildContext context) {
    final d = day;
    final date = d.date == null ? null : TripFormat.shortDate(d.date!);
    final chips = [?stay, ?taxi];
    final title = d.city == null ? TripStringsA5.dayHeading(d.day, date) : TripStringsV2Easy.dayInCity(d.day, d.city!);
    final spots = [
      for (var i = 0; i < d.spots.length; i++) d.hasTimes ? '${TripDayTimeline.clock(d.starts[i])} ${d.spots[i]}' : d.spots[i],
    ];
    final lines = [
      if (d.city != null && date != null) date,
      if (spots.isNotEmpty) spots.join(' › '),
      if (d.minutes > 0) TripStringsA5.aboutDuration(TripFormat.duration(d.minutes)),
    ];
    return WideCard(
      tone: ListingTone.indigo,
      art: d.day.isOdd ? ListingArt.sunrise : ListingArt.mountain,
      title: title,
      subtitle: lines.join('\n'),
      chips: [for (final c in chips) c.label],
      reserveChips: false,
      showPrice: false,
    );
  }
}
